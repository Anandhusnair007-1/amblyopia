import os
import pandas as pd

# Config
SRC_CSV = 'ambyo_dataset_clean/doctor_audit_labels.csv'
OUT_CSV = 'ambyo_dataset_clean/verified_training_labels.csv'

def filter_dataset():
    print("--- Filtering Verified Dataset for Training ---")
    if not os.path.exists(SRC_CSV):
        print(f"Error: {SRC_CSV} not found.")
        return

    df = pd.read_csv(SRC_CSV)
    
    # Strict Criteria
    # 1. audit_status == verified
    # 2. doctor_verified_quality == good
    # 3. doctor_verified_deviation_type in [ET, XT, ortho]
    # 4. usable_for_training == True (initial PHI/CRC check)
    
    mask = (
        (df['audit_status'] == 'verified') &
        (df['doctor_verified_quality'] == 'good') &
        (df['doctor_verified_deviation_type'].isin(['ET', 'XT', 'ortho'])) &
        (df['usable_for_training'] == True)
    )
    
    verified_df = df[mask]
    
    print(f"Total verified & usable samples: {len(verified_df)}")
    print(verified_df['doctor_verified_deviation_type'].value_counts())
    
    verified_df.to_csv(OUT_CSV, index=False)
    print(f"Exported to {OUT_CSV}")

if __name__ == "__main__":
    filter_dataset()
