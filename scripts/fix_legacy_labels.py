import pandas as pd
import os

# Config
AUDIT_CSV = 'ambyo_dataset_clean/doctor_audit_labels.csv'

def fix_existing_labels():
    if not os.path.exists(AUDIT_CSV):
        print("Audit CSV not found.")
        return

    df = pd.read_csv(AUDIT_CSV)
    
    # For all rows where audit_status is 'verified' but doctor_verified_deviation_type is 'unknown'
    # Copy the scavenged deviation_type over.
    mask = (df['audit_status'] == 'verified') & (df['doctor_verified_deviation_type'] == 'unknown')
    
    # Map scavenged types to valid training types
    def map_type(t):
        t = str(t).upper()
        if 'XT' in t: return 'XT'
        if 'ET' in t: return 'ET'
        if 'ORTHO' in t: return 'ortho'
        return 'unknown'

    df.loc[mask, 'doctor_verified_deviation_type'] = df.loc[mask, 'deviation_type'].apply(map_type)
    
    # Also ensure quality is marked
    df.loc[mask, 'doctor_verified_quality'] = 'good'
    
    df.to_csv(AUDIT_CSV, index=False)
    print(f"Fixed {mask.sum()} existing verified rows to be usable for training.")

if __name__ == "__main__":
    fix_existing_labels()
