import os
import pandas as pd
import datetime
import argparse

# Config
AUDIT_CSV = 'ambyo_dataset_clean/doctor_audit_labels.csv'

def import_review(input_csv, force=False):
    print(f"--- Importing Clinical Review: {input_csv} ---")
    
    if not os.path.exists(input_csv):
        print(f"Error: {input_csv} not found.")
        return
    if not os.path.exists(AUDIT_CSV):
        print(f"Error: {AUDIT_CSV} not found.")
        return

    # 1. Backup
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = f"ambyo_dataset_clean/doctor_audit_labels_backup_{ts}.csv"
    pd.read_csv(AUDIT_CSV).to_csv(backup_path, index=False)
    print(f"Backup created at {backup_path}")

    # 2. Load Data
    audit_df = pd.read_csv(AUDIT_CSV)
    review_df = pd.read_csv(input_csv)

    # 3. Update Logic
    updated_count = 0
    stats = {"new_verified_ET": 0, "new_verified_XT": 0, "rejected": 0, "uncertain": 0, "bad_quality": 0}

    for idx, row in review_df.iterrows():
        img_id = row['image_id']
        
        # Find matching row in audit
        mask = audit_df['image_id'] == img_id
        if not mask.any(): continue
        
        existing_status = audit_df.loc[mask, 'audit_status'].values[0]
        
        if existing_status == 'verified' and not force:
            print(f"Skipping {img_id}: Already verified. Use --force to overwrite.")
            continue
            
        # Update columns
        audit_df.loc[mask, 'doctor_verified_deviation_type'] = row['doctor_verified_deviation_type']
        audit_df.loc[mask, 'doctor_verified_quality'] = row['doctor_verified_quality']
        audit_df.loc[mask, 'audit_status'] = row['audit_status']
        audit_df.loc[mask, 'doctor_comments'] = row.get('doctor_comments', '')
        
        # Stats
        if row['audit_status'] == 'verified':
            if row['doctor_verified_deviation_type'] == 'ET': stats['new_verified_ET'] += 1
            elif row['doctor_verified_deviation_type'] == 'XT': stats['new_verified_XT'] += 1
            
            if row['doctor_verified_quality'] != 'good': stats['bad_quality'] += 1
        elif row['audit_status'] == 'rejected':
            stats['rejected'] += 1
        elif row['audit_status'] == 'uncertain':
            stats['uncertain'] += 1
            
        updated_count += 1

    # 4. Save
    audit_df.to_csv(AUDIT_CSV, index=False)
    
    print("\nImport Summary:")
    print(f"Total Updated:     {updated_count}")
    print(f"New Verified ET:   {stats['new_verified_ET']}")
    print(f"New Verified XT:   {stats['new_verified_XT']}")
    print(f"Rejected:          {stats['rejected']}")
    print(f"Uncertain:         {stats['uncertain']}")
    print(f"Bad Quality:       {stats['bad_quality']}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    
    import_review(args.input, args.force)
