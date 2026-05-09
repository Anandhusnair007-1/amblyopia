import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
import shutil

# Config
SRC_DIR = 'ambyo_dataset_clean'
DEST_DIR = 'ambyo_dataset_model'
LABELS_CSV = os.path.join(SRC_DIR, 'labels.csv')
SPLIT_LABELS_CSV = os.path.join(DEST_DIR, 'labels_split.csv')

def prepare_split():
    if not os.path.exists(LABELS_CSV):
        print(f"Error: {LABELS_CSV} not found.")
        return

    df = pd.read_csv(LABELS_CSV)
    
    # We only split records that are usable and verified (or pending for now if we want to see the structure)
    # But usually, we only split what we intend to use.
    # For now, let's include all 'usable_for_training' records to show the split logic.
    df = df[df['usable_for_training'] == True]

    if df.empty:
        print("No usable records found to split.")
        return

    # Group by 'original_file' to prevent data leakage (same patient/session in multiple splits)
    unique_files = df['original_file'].unique()
    
    # Split: 70% train, 30% temp
    train_files, temp_files = train_test_split(unique_files, test_size=0.30, random_state=42)
    
    # Split temp: 50% val (15% total), 50% test (15% total)
    val_files, test_files = train_test_split(temp_files, test_size=0.50, random_state=42)
    
    print(f"Split Summary (by Original File):")
    print(f"Train: {len(train_files)}, Val: {len(val_files)}, Test: {len(test_files)}")

    # Assign split label
    df['split'] = 'unknown'
    df.loc[df['original_file'].isin(train_files), 'split'] = 'train'
    df.loc[df['original_file'].isin(val_files), 'split'] = 'val'
    df.loc[df['original_file'].isin(test_files), 'split'] = 'test'

    # Create directories
    for s in ['train', 'val', 'test']:
        os.makedirs(os.path.join(DEST_DIR, s), exist_ok=True)

    # Copy files and update labels
    new_records = []
    for idx, row in df.iterrows():
        split = row['split']
        src_path = os.path.join(SRC_DIR, row['image_path'])
        
        if not os.path.exists(src_path):
            continue
            
        filename = f"{row['image_id']}.jpg"
        dest_path = os.path.join(DEST_DIR, split, filename)
        
        # Copy image
        shutil.copy2(src_path, dest_path)
        
        # Record new path
        row['model_image_path'] = os.path.join(split, filename)
        new_records.append(row)

    # Save split labels
    split_df = pd.DataFrame(new_records)
    split_df.to_csv(SPLIT_LABELS_CSV, index=False)
    
    print(f"Dataset split complete. Saved to {DEST_DIR}")
    print(split_df['split'].value_counts())

if __name__ == "__main__":
    prepare_split()
