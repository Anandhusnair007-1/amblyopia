import os
import pandas as pd

# Config
DATA_DIR = 'ambyo_dataset_clean'
AUDIT_CSV = os.path.join(DATA_DIR, 'doctor_audit_labels.csv')
BATCH_OUT = 'et_review_batch.csv'

def select_et_batch():
    if not os.path.exists(AUDIT_CSV):
        print(f"Error: {AUDIT_CSV} not found.")
        return

    df = pd.read_csv(AUDIT_CSV)
    
    # Logic: Find unverified records that might be ET
    # 1. Scavenged label contains 'ET'
    # 2. Or clinical notes contain 'ET' or 'ESOTROPIA'
    
    def matches_et(row):
        notes = str(row.get('notes_cleaned', '')).upper()
        scavenged = str(row.get('deviation_type', '')).upper()
        return 'ET' in scavenged or 'ET' in notes or 'ESOTROPIA' in notes

    pending_df = df[df['audit_status'] == 'pending'].copy()
    et_mask = pending_df.apply(matches_et, axis=1)
    et_batch = pending_df[et_mask]
    
    if et_batch.empty:
        print("No unverified ET cases found.")
        return

    # Select relevant columns
    out_cols = ['image_path', 'original_file', 'deviation_type', 'doctor_verified_deviation_type', 'audit_status', 'notes_cleaned']
    # Ensure columns exist
    out_cols = [c for c in out_cols if c in et_batch.columns]
    
    et_batch[out_cols].to_csv(BATCH_OUT, index=False)
    
    print(f"Created ET review batch with {len(et_batch)} cases at {BATCH_OUT}")
    print("Goal: Verify at least 100 more ET images to balance the dataset.")

if __name__ == "__main__":
    select_et_batch()
