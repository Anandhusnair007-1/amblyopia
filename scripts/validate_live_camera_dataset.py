import os
import sys
import pandas as pd
import asyncio
from PIL import Image

# Add root to path
sys.path.append(os.getcwd())
from backend.ai_engine import ai_engine

async def validate_live_folder(folder_path):
    print(f"--- Validating Live Camera Dataset: {folder_path} ---")
    
    if not os.path.exists(folder_path):
        print(f"Error: {folder_path} not found.")
        return

    # Load models
    ai_engine.load_models()
    
    images = [f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    results = []

    # Mock UploadFile helper
    class MockFile:
        def __init__(self, path):
            self.path = path
            self.filename = os.path.basename(path)
        async def read(self):
            with open(self.path, 'rb') as f: return f.read()

    for img_name in images:
        path = os.path.join(folder_path, img_name)
        try:
            mock_file = MockFile(path)
            res = await ai_engine.screen_eye(mock_file)
            
            row = {
                "image_name": img_name,
                "quality_label": res['quality']['label'],
                "quality_confidence": res['quality']['confidence'],
                "deviation_type": res['deviation']['possible_type'] if res['deviation'] else "N/A",
                "deviation_confidence": res['deviation']['confidence'] if res['deviation'] else 0.0,
                "model_version": res['model_version']
            }
            results.append(row)
            print(f"Processed {img_name}: {row['quality_label']} | {row['deviation_type']}")
        except Exception as e:
            print(f"Failed {img_name}: {e}")

    if results:
        out_df = pd.DataFrame(results)
        out_df.to_csv('live_validation_results.csv', index=False)
        print("\nValidation Complete. Results saved to live_validation_results.csv")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--folder", default="ambyo_dataset_clean/images") # Defaulting to existing for test
    args = parser.parse_args()
    
    asyncio.run(validate_live_folder(args.folder))
