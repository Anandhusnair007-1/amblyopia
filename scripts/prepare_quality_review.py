import os
import pandas as pd

# Config
DATA_DIR = 'ambyo_dataset_clean'
LABELS_CSV = os.path.join(DATA_DIR, 'labels.csv')
REVIEW_CSV = os.path.join(DATA_DIR, 'quality_review.csv')

def prepare_review():
    if not os.path.exists(LABELS_CSV):
        print(f"Error: {LABELS_CSV} not found. Run scavenge_dataset.py first.")
        return

    df = pd.read_csv(LABELS_CSV)
    
    # Define verification columns for quality
    review_cols = {
        'image_id': df['image_id'],
        'image_path': df['image_path'],
        'current_quality': df.get('image_quality', 'unknown'),
        'doctor_verified_quality': 'unknown',
        'review_status': 'pending',
        'review_comments': ''
    }
    
    review_df = pd.DataFrame(review_cols)
    
    # Only keep records that have an image_path
    review_df = review_df[review_df['image_path'].notna() & (review_df['image_path'] != "")]
    
    review_df.to_csv(REVIEW_CSV, index=False)
    print(f"Created quality review list at {REVIEW_CSV}")
    print(f"Total images for review: {len(review_df)}")
    print("\nNext step: Open this CSV and fill 'doctor_verified_quality' (good, blurred, dark, bad_crop, reflection_issue, unknown) and set 'review_status' to 'verified'.")

if __name__ == "__main__":
    prepare_review()
