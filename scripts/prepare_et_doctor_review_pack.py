import os
import pandas as pd
import shutil

# Config
BATCH_CSV = 'et_review_batch.csv'
IMG_SRC = 'ambyo_dataset_clean/images'
OUT_DIR = 'et_doctor_review_pack'
OUT_IMG_DIR = os.path.join(OUT_DIR, 'images')
OUT_CSV = os.path.join(OUT_DIR, 'et_review_for_doctor.csv')
README_PATH = os.path.join(OUT_DIR, 'README_REVIEW_INSTRUCTIONS.md')

def prepare_review_pack():
    print("--- Preparing ET Doctor Review Pack ---")
    if not os.path.exists(BATCH_CSV):
        print(f"Error: {BATCH_CSV} not found. Run select_et_review_batch.py first.")
        return

    df = pd.read_csv(BATCH_CSV)
    
    # 1. Create Structure
    os.makedirs(OUT_IMG_DIR, exist_ok=True)

    # 2. Add Review Columns
    df = df.dropna(subset=['image_path']) # Drop rows with missing paths
    df['image_id'] = df['image_path'].apply(lambda x: os.path.basename(str(x)).split('.')[0])
    df['doctor_verified_deviation_type'] = 'unknown' # Default for doctor to fill
    df['doctor_verified_quality'] = 'good'           # Default for doctor to fill
    df['audit_status'] = 'pending'                   # Default for doctor to fill
    df['doctor_comments'] = ''

    # 3. Copy Images
    copied = 0
    for idx, row in df.iterrows():
        src = os.path.join('ambyo_dataset_clean', row['image_path'])
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(OUT_IMG_DIR, os.path.basename(src)))
            copied += 1
    
    # 4. Save CSV
    # Select columns specifically requested
    cols = ['image_id', 'image_path', 'deviation_type', 'original_file', 
            'doctor_verified_deviation_type', 'doctor_verified_quality', 
            'audit_status', 'doctor_comments']
    # Add any missing
    for c in cols:
        if c not in df.columns: df[c] = ""
        
    df[cols].to_csv(OUT_CSV, index=False)

    # 5. Create README
    instructions = """# AmbyoAI: Clinical Review Instructions (ET Balance)

This pack contains images that are suspected to be **ET (Esotropia)**. 
Please review each image in the `images/` folder and update `et_review_for_doctor.csv`.

### Instructions:
For each row, fill in the following columns:

1. **doctor_verified_deviation_type**:
   - `ET`: Esotropia (confirmed)
   - `XT`: Exotropia
   - `ortho`: Normal alignment
   - `vertical`: Vertical deviation
   - `uncertain`: Hard to tell
   - `reject`: Do not use (corrupted)

2. **doctor_verified_quality**:
   - `good`: Clear, usable image
   - `blurred`: Out of focus
   - `dark`: Poor lighting
   - `bad_crop`: Eye not centered
   - `reflection_issue`: Glare on iris

3. **audit_status**:
   - Set to `verified` once review is complete.
   - Set to `rejected` if image is unusable.

### Training Requirements:
Only images marked as **verified**, **good** quality, and having a deviation type of **ET, XT, or ortho** will be used to improve the AI model.

**Goal**: We need at least 100 verified ET images to balance the AI classifier.
"""
    with open(README_PATH, 'w') as f:
        f.write(instructions)

    print(f"Pack created in {OUT_DIR}")
    print(f"Images copied: {copied}")
    print(f"Review CSV: {OUT_CSV}")

if __name__ == "__main__":
    prepare_review_pack()
