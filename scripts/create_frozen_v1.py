import os
import pandas as pd
import shutil
import json

# Config
SRC_DIR = 'ambyo_dataset_clean'
AUDIT_CSV = os.path.join(SRC_DIR, 'doctor_audit_labels.csv')
FROZEN_DIR = 'ambyo_dataset_v1'
VERIFIED_LABELS = os.path.join(FROZEN_DIR, 'verified_training_labels.csv')

def freeze_v1():
    print("--- Freezing Dataset v1 ---")
    if not os.path.exists(AUDIT_CSV):
        print(f"Error: {AUDIT_CSV} not found.")
        return

    df = pd.read_csv(AUDIT_CSV)
    
    # 1. Validation
    required_cols = ['audit_status', 'usable_for_training', 'doctor_verified_quality']
    missing = [c for c in required_cols if c not in df.columns]
    if missing:
        print(f"Missing columns: {missing}")
        return

    # 2. Filter
    v_df = df[(df['audit_status'] == 'verified') & 
              (df['usable_for_training'] == True) & 
              (df['doctor_verified_quality'].notna()) & 
              (df['doctor_verified_quality'] != 'unknown')]
    
    if v_df.empty:
        print("No verified/usable rows found. Stop.")
        return

    print(f"Verified rows: {len(v_df)}")

    # 3. Create structure
    img_dest = os.path.join(FROZEN_DIR, 'images')
    os.makedirs(img_dest, exist_ok=True)

    # 4. Copy images
    copied_count = 0
    for idx, row in v_df.iterrows():
        src = os.path.join(SRC_DIR, row['image_path'])
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(img_dest, os.path.basename(src)))
            copied_count += 1
    
    # 5. Export labels
    v_df.to_csv(VERIFIED_LABELS, index=False)
    
    # 6. Dataset Card
    with open(os.path.join(FROZEN_DIR, 'dataset_card.md'), 'w') as f:
        f.write("# AmbyoAI Dataset v1 (Frozen)\n\n")
        f.write(f"Total Images: {copied_count}\n")
        f.write("Status: Verified by Doctor\n")
        f.write("Task: AI-assisted image quality screening\n")

    # 7. Quality Report
    report = {
        "version": "v1.0.0",
        "total_verified": len(v_df),
        "class_distribution": v_df['doctor_verified_quality'].value_counts().to_dict()
    }
    with open(os.path.join(FROZEN_DIR, 'data_quality_report_v1.json'), 'w') as f:
        json.dump(report, f, indent=2)

    print(f"Frozen dataset v1 created in {FROZEN_DIR}")

if __name__ == "__main__":
    freeze_v1()
