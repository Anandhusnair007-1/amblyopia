import pandas as pd
import os

# Config
DATA_DIR = 'ambyo_dataset_clean'
LABELS_CSV = os.path.join(DATA_DIR, 'labels.csv')
AUDIT_CSV = os.path.join(DATA_DIR, 'doctor_audit_labels.csv')
SAMPLE_CSV = os.path.join(DATA_DIR, 'doctor_audit_sample.csv')

def prepare_audit():
    if not os.path.exists(LABELS_CSV):
        print(f"Error: {LABELS_CSV} not found. Run scavenge_dataset.py first.")
        return

    df = pd.read_csv(LABELS_CSV)
    
    # Define verification columns
    audit_cols = [
        'doctor_verified_label',
        'doctor_verified_deviation_type',
        'doctor_verified_quality',
        'doctor_comments',
        'audit_status'
    ]
    
    for col in audit_cols:
        if col not in df.columns:
            if col == 'audit_status':
                df[col] = 'pending'
            elif col == 'doctor_comments':
                df[col] = ''
            else:
                df[col] = 'unknown'

    # Export full audit file
    df.to_csv(AUDIT_CSV, index=False)
    print(f"Exported full audit list to {AUDIT_CSV}")

    # Export 50 random samples for first review
    # We only sample from usable records
    usable_df = df[df['usable_for_training'] == True]
    if len(usable_df) > 50:
        sample_df = usable_df.sample(50, random_state=42)
    else:
        sample_df = usable_df
        
    sample_df.to_csv(SAMPLE_CSV, index=False)
    print(f"Exported 50-case audit sample to {SAMPLE_CSV}")

if __name__ == "__main__":
    prepare_audit()
