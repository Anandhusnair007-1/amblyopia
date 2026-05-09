import os
import re
import json
import pandas as pd
import xml.etree.ElementTree as ET
from PIL import Image as PILImage
import shutil

# Constants
EXTRACTED_DIR = 'extracted_xlsx'
OUTPUT_DIR = 'ambyo_dataset_clean'
IMAGE_DIR = os.path.join(OUTPUT_DIR, 'images')
LABELS_CSV = os.path.join(OUTPUT_DIR, 'labels.csv')
REPORT_JSON = os.path.join(OUTPUT_DIR, 'data_quality_report.json')
README_MD = os.path.join(OUTPUT_DIR, 'README_dataset.md')

os.makedirs(IMAGE_DIR, exist_ok=True)

def parse_shared_strings():
    ss_path = os.path.join(EXTRACTED_DIR, 'xl/sharedStrings.xml')
    if not os.path.exists(ss_path):
        return []
    
    tree = ET.parse(ss_path)
    root = tree.getroot()
    # Namespace handling
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    
    strings = []
    for si in root.findall('ns:si', ns):
        # Can be <t> or <r><t>
        t_text = ""
        for t in si.findall('.//ns:t', ns):
            if t.text:
                t_text += t.text
        strings.append(t_text)
    return strings

def parse_drawing_rels():
    rels_path = os.path.join(EXTRACTED_DIR, 'xl/drawings/_rels/drawing1.xml.rels')
    if not os.path.exists(rels_path):
        return {}
    
    tree = ET.parse(rels_path)
    root = tree.getroot()
    ns = {'ns': 'http://schemas.openxmlformats.org/package/2006/relationships'}
    
    rel_map = {} # rId -> target
    for rel in root.findall('ns:Relationship', ns):
        rId = rel.get('Id')
        target = rel.get('Target')
        # Target is like ../media/image1.jpg
        rel_map[rId] = os.path.basename(target)
    return rel_map

def parse_drawing_anchors():
    draw_path = os.path.join(EXTRACTED_DIR, 'xl/drawings/drawing1.xml')
    if not os.path.exists(draw_path):
        return []
    
    tree = ET.parse(draw_path)
    root = tree.getroot()
    ns = {'xdr': 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing',
          'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
          'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
    
    anchors = []
    for anchor in root.findall('.//xdr:oneCellAnchor', ns):
        row = int(anchor.find('.//xdr:from/xdr:row', ns).text) + 1 # 1-indexed
        
        # Try to get filename directly from cNvPr
        nv_pr = anchor.find('.//xdr:nvPicPr/xdr:cNvPr', ns)
        img_name = None
        if nv_pr is not None:
            img_name = nv_pr.get('name')
        
        blip = anchor.find('.//a:blip', ns)
        rId = None
        if blip is not None:
            rId = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
            
        anchors.append({'row': row, 'rId': rId, 'img_name': img_name})
    return anchors

def clean_text(text):
    if not text: return ""
    # Remove PHI
    text = re.sub(r'\b\d{10}\b', '[PHONE]', str(text))
    text = re.sub(r'\b[A-Z0-9]{6,}\b', '[ID]', text)
    return text.strip()

def detect_phi(text):
    if not text: return False
    if re.search(r'\b\d{10}\b', str(text)): return True
    return False

def scavenge():
    print("--- Starting XML Scavenger ---")
    
    strings = parse_shared_strings()
    rel_map = parse_drawing_rels()
    anchors = parse_drawing_anchors()
    
    print(f"Strings: {len(strings)}, Rels: {len(rel_map)}, Anchors: {len(anchors)}")
    
    # Map row to image filename
    row_to_image = {}
    for a in anchors:
        img_name = rel_map.get(a['rId']) if a['rId'] else None
        if not img_name:
            img_name = a['img_name']
        if img_name:
            row_to_image[a['row']] = img_name

    # Group strings into rows
    # Logic: "Original File" strings usually start with PHOTO- and contain eye_N.jpg
    # Or just find the headers and split.
    
    # Headers are likely strings 0-7
    # 0: Original File, 1: Cropped Eye Image, 2: Text in Image, 3: EYE, 4: AGE, 5: SEX, 6: CR, 7: PCT
    
    rows = []
    current_row = None
    
    # We skip headers (0-7)
    for s in strings[8:]:
        # Pattern for start of row: PHOTO-YYYY...
        if re.match(r'PHOTO-\d{4}-\d{2}-\d{2}', s):
            if current_row:
                rows.append(current_row)
            current_row = {'original_file': s, 'other': []}
        else:
            if current_row:
                current_row['other'].append(s)
    if current_row:
        rows.append(current_row)
    
    print(f"Reconstructed {len(rows)} data rows from strings.")

    data = []
    for idx, r in enumerate(rows, start=1):
        # We don't have exact row mapping anymore because sheet1.xml is missing.
        # However, in many cases, rows are consecutive.
        # But wait, the drawings had row numbers! 1, 7, 13... (6 rows apart)
        # Let's see if we can align them.
        # If the first row is row 1 (0-indexed) in drawing, then it's Row 2 in Excel.
        # Next is row 7 (Excel Row 8).
        # This implies each patient/row takes 6 Excel rows? Or just spaced out.
        
        # Let's assume the order of rows in `rows` matches the order of `anchors`.
        # Anchors are usually sorted by row.
        sorted_anchors = sorted(anchors, key=lambda x: x['row'])
        
        # Mapping by index
        row_image = None
        if idx-1 < len(sorted_anchors):
            a = sorted_anchors[idx-1]
            row_image = rel_map.get(a['rId']) if a['rId'] else None
            if not row_image:
                row_image = a['img_name']
        
        # Extract fields from 'other'
        # other[0] is usually the note
        # other[1] is usually Eye
        # other[2] is usually Sex
        others = r['other']
        note = others[0] if len(others) > 0 else ""
        eye = others[1] if len(others) > 1 else "unknown"
        sex = others[2] if len(others) > 2 else "unknown"
        
        image_id = f"eye_{idx:06d}"
        image_rel_path = ""
        usable = False
        
        if row_image:
            src_img = os.path.join(EXTRACTED_DIR, 'xl/media', row_image)
            if os.path.exists(src_img):
                image_rel_path = f"images/{image_id}.jpg"
                dest_img = os.path.join(OUTPUT_DIR, image_rel_path)
                try:
                    # Convert to JPG for consistency
                    with PILImage.open(src_img) as img:
                        img.convert('RGB').save(dest_img, "JPEG")
                    usable = True
                except:
                    usable = False

        # Parse age from note if missing
        age = None
        age_match = re.search(r'(\d+)\s*(?:yrs|yr|y/o|/M|/F)', note, re.I)
        if age_match:
            age = int(age_match.group(1))

        phi_flag = detect_phi(note) or detect_phi(r['original_file'])

        rec = {
            'image_id': image_id,
            'image_path': image_rel_path,
            'original_file': clean_text(r['original_file']),
            'eye': eye.upper(),
            'age': age,
            'sex': sex[0].upper() if sex else "U",
            'cr_degree': None, # hard to parse robustly without regex for each
            'pct_mkt_pd': None,
            'deviation_type': 'unknown',
            'horizontal_direction': 'unknown',
            'vertical_component': 'unknown',
            'doctor_label': 'unknown',
            'label_source': 'scavenged_xml',
            'image_quality': 'good' if usable else 'unknown',
            'notes_cleaned': clean_text(note),
            'contains_phi_flag': phi_flag,
            'usable_for_training': usable and not phi_flag,
            # Doctor Verification Columns (to be filled manually)
            'doctor_verified_label': 'unknown',
            'doctor_verified_deviation_type': 'unknown',
            'doctor_verified_quality': 'unknown',
            'doctor_comments': '',
            'audit_status': 'pending'
        }
        
        # Inference
        n = rec['notes_cleaned'].upper()
        if 'XT' in n: rec['deviation_type'] = 'XT'
        elif 'ET' in n: rec['deviation_type'] = 'ET'
        elif 'ORTHO' in n: rec['deviation_type'] = 'ortho'
        
        data.append(rec)

    df = pd.DataFrame(data)
    df.to_csv(LABELS_CSV, index=False)
    
    report = {
        "total_rows_found": len(rows),
        "total_images_extracted": int(df['image_path'].ne("").sum()),
        "usable_for_training_count": int(df['usable_for_training'].sum()),
        "count_by_eye": df['eye'].value_counts().to_dict(),
        "count_by_deviation_type": df['deviation_type'].value_counts().to_dict(),
    }
    with open(REPORT_JSON, 'w') as f:
        json.dump(report, f, indent=2)
        
    with open(README_MD, 'w') as f:
        f.write("# AmbyoAI Scavenged Dataset\n\n")
        f.write("Extracted from a truncated XLSX file using XML scavenging.\n\n")
        f.write("## Medical Safety Disclaimer\n")
        f.write("This dataset is for research only. Not for diagnosis.\n")

    print(f"Scavenge complete. Records: {len(data)}")

if __name__ == "__main__":
    scavenge()
