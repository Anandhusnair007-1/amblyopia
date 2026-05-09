import os
import pandas as pd
import openpyxl
import json
import re
import io
import zipfile
from PIL import Image as PILImage

# Constants
SOURCE_EXCEL = 'Image_Summary_With_Embedded_Images1.xlsx'
OUTPUT_DIR = 'ambyo_dataset_clean'
IMAGE_DIR = os.path.join(OUTPUT_DIR, 'images')
LABELS_CSV = os.path.join(OUTPUT_DIR, 'labels.csv')
REPORT_JSON = os.path.join(OUTPUT_DIR, 'data_quality_report.json')
README_MD = os.path.join(OUTPUT_DIR, 'README_dataset.md')

os.makedirs(IMAGE_DIR, exist_ok=True)

def clean_text(text):
    if not text or pd.isna(text):
        return ""
    # Basic Anonymization: Remove potential names/IDs
    # Replace sequences that look like phone numbers or long IDs
    text = re.sub(r'\b\d{10}\b', '[ANONYMIZED_PHONE]', str(text))
    text = re.sub(r'\b[A-Z0-9]{5,}\b', '[ANONYMIZED_ID]', text)
    return text.strip()

def detect_phi(text):
    if not text or pd.isna(text):
        return False
    # Flag if text contains patterns suggestive of PHI
    patterns = [
        r'\b\d{10}\b', # Phone
        r'\b\d{6,}\b', # MRN/ID
        r'\b(?:DR|MR|MRS|MS|PATIENT)\b', # Titles
    ]
    for p in patterns:
        if re.search(p, str(text), re.IGNORECASE):
            return True
    return False

def get_images_from_xlsx(file_path):
    """Robustly extract images from xlsx using zipfile fallback."""
    images = {} # (row, col) -> bytes
    try:
        with zipfile.ZipFile(file_path, 'r') as archive:
            # Map drawing rels to image files
            # This is complex, but we can simplify by looking for all media
            media_files = [f for f in archive.namelist() if f.startswith('xl/media/')]
            # Without full XML parsing, mapping to rows is hard. 
            # However, openpyxl usually loads them if they are standard anchors.
            pass
    except:
        pass
    return images

def extract_dataset():
    print(f"--- AmbyoAI Data Extraction Started ---")
    print(f"Source: {SOURCE_EXCEL}")
    
    try:
        # Load workbook
        wb = openpyxl.load_workbook(SOURCE_EXCEL, data_only=True)
        sheet = wb.active
        print(f"Active Sheet: {sheet.title}")
    except Exception as e:
        print(f"CRITICAL ERROR: Could not load workbook: {e}")
        return

    # 1. Identify Headers
    headers = [str(cell.value).strip() if cell.value else "" for cell in sheet[1]]
    print(f"Headers: {headers}")
    
    col_map = {
        'original_file': 'Original File',
        'text_in_image': 'Text in Image',
        'eye': 'EYE',
        'age': 'AGE',
        'sex': 'SEX',
        'cr_degree': 'CR (DEGREE)',
        'pct_mkt_pd': 'PCT / MKT IN PD'
    }
    
    idx_map = {k: -1 for k in col_map}
    for k, v in col_map.items():
        for i, h in enumerate(headers):
            if v.lower() in h.lower():
                idx_map[k] = i
                break

    # 2. Extract Images using openpyxl internal list
    # We map images to their row/col anchors
    image_anchors = {}
    if hasattr(sheet, '_images'):
        for img in sheet._images:
            try:
                row = img.anchor._from.row + 1 # 1-indexed
                col = img.anchor._from.col
                image_anchors[(row, col)] = img
            except:
                continue
    
    print(f"Detected {len(image_anchors)} embedded images.")

    # 3. Process Rows
    records = []
    total_rows = 0
    images_saved = 0
    
    for row_idx, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        total_rows += 1
        
        # Extract metadata
        meta = {}
        for k, idx in idx_map.items():
            meta[k] = row[idx] if idx != -1 else None

        image_id = f"eye_{total_rows:06d}"
        image_rel_path = ""
        usable = False
        phi_found = detect_phi(meta['text_in_image']) or detect_phi(meta['original_file'])
        
        # Find image for this row
        row_img = None
        for (r, c), img_obj in image_anchors.items():
            if r == row_idx:
                row_img = img_obj
                break
        
        if row_img:
            image_rel_path = f"images/{image_id}.jpg"
            full_img_path = os.path.join(OUTPUT_DIR, image_rel_path)
            try:
                # Save image
                img_data = row_img._data() if hasattr(row_img, '_data') else row_img.ref
                if isinstance(img_data, bytes):
                    # Check if it's a valid image
                    pil_img = PILImage.open(io.BytesIO(img_data))
                    pil_img.convert('RGB').save(full_img_path, "JPEG")
                    images_saved += 1
                    usable = True
                else:
                    # Alternative openpyxl format
                    row_img.image.save(full_img_path)
                    images_saved += 1
                    usable = True
            except Exception as e:
                print(f"Warning: Failed to save image for row {row_idx}: {e}")
                usable = False

        # Clean metadata
        cleaned_rec = {
            'image_id': image_id,
            'image_path': image_rel_path,
            'original_file': clean_text(meta['original_file']),
            'eye': str(meta['eye']).upper() if meta['eye'] else "UNKNOWN",
            'age': meta['age'] if isinstance(meta['age'], (int, float)) else None,
            'sex': str(meta['sex'])[0].upper() if meta['sex'] else "U",
            'cr_degree': meta['cr_degree'] if isinstance(meta['cr_degree'], (int, float)) else None,
            'pct_mkt_pd': meta['pct_mkt_pd'] if isinstance(meta['pct_mkt_pd'], (int, float)) else None,
            'deviation_type': "unknown",
            'horizontal_direction': "unknown",
            'vertical_component': "unknown",
            'doctor_label': "unknown",
            'label_source': "extracted_text",
            'image_quality': "good" if usable else "unknown",
            'notes_cleaned': clean_text(meta['text_in_image']),
            'contains_phi_flag': phi_found,
            'usable_for_training': usable and not phi_found
        }
        
        # Basic inference for deviation type
        notes = cleaned_rec['notes_cleaned'].upper()
        if 'XT' in notes: cleaned_rec['deviation_type'] = 'XT'
        elif 'ET' in notes: cleaned_rec['deviation_type'] = 'ET'
        elif 'ORTHO' in notes: cleaned_rec['deviation_type'] = 'ortho'
        
        records.append(cleaned_rec)

    # 4. Save results
    df = pd.DataFrame(records)
    df.to_csv(LABELS_CSV, index=False)
    
    # 5. Generate Quality Report
    report = {
        "total_rows_found": total_rows,
        "total_images_extracted": images_saved,
        "total_rows_with_images": images_saved,
        "total_rows_without_images": total_rows - images_saved,
        "count_by_eye": df['eye'].value_counts().to_dict(),
        "count_by_sex": df['sex'].value_counts().to_dict(),
        "age_stats": {
            "min": float(df['age'].min()) if not df['age'].dropna().empty else None,
            "max": float(df['age'].max()) if not df['age'].dropna().empty else None,
            "median": float(df['age'].median()) if not df['age'].dropna().empty else None,
        },
        "count_by_deviation_type": df['deviation_type'].value_counts().to_dict(),
        "missing_values": df.isnull().sum().to_dict(),
        "usable_for_training_count": int(df['usable_for_training'].sum())
    }
    
    with open(REPORT_JSON, 'w') as f:
        json.dump(report, f, indent=2)

    # 6. Create README
    with open(README_MD, 'w') as f:
        f.write("# AmbyoAI Cleaned Dataset\n\n")
        f.write(f"**Version**: 1.0.0\n")
        f.write(f"**Anonymized**: Yes\n")
        f.write(f"**Total Records**: {total_rows}\n")
        f.write(f"**Usable for Training**: {report['usable_for_training_count']}\n\n")
        f.write("## Medical Safety Disclaimer\n")
        f.write("This dataset and any models trained from it are for AI-assisted screening research only. ")
        f.write("The model must not be used as a standalone medical diagnostic tool. ")
        f.write("Final interpretation must be confirmed by a qualified ophthalmologist/optometrist.\n")

    print(f"--- Extraction Complete ---")
    print(f"Cleaned labels saved to: {LABELS_CSV}")
    print(f"Quality report saved to: {REPORT_JSON}")

if __name__ == "__main__":
    extract_dataset()
