import os
import sys
import asyncio

# Add root to path so we can import backend
sys.path.append(os.getcwd())
from backend.ai_engine import ai_engine

async def test_inference():
    print("--- AI Engine Testing ---")
    
    # 1. Initialize Engine
    ai_engine.load_models()
    
    # 2. Pick a sample image
    image_dir = 'ambyo_dataset_clean/images'
    if not os.path.exists(image_dir):
        print(f"Error: {image_dir} not found.")
        return
        
    sample_images = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    if not sample_images:
        print("No images found in dataset.")
        return
        
    test_img_path = os.path.join(image_dir, sample_images[0])
    print(f"Testing with: {test_img_path}")
    
    # 3. Simulate FastAPI UploadFile
    with open(test_img_path, "rb") as f:
        img_bytes = f.read()
        
    # Mock UploadFile
    class MockFile:
        def __init__(self, data):
            self.data = data
            self.filename = "test.jpg"
        async def read(self):
            return self.data
            
    mock_file = MockFile(img_bytes)
    
    # 4. Screen Eye
    try:
        result = await ai_engine.screen_eye(mock_file)
        
        print("\n--- AI Result Summary ---")
        print(f"Model Version: {result['model_version']}")
        print(f"Quality:       {result['quality']['label']} ({(result['quality']['confidence']*100):.1f}%)")
        print(f"Usable:        {result['quality']['is_usable']}")
        
        if result['deviation']:
            print(f"Possible Dev:  {result['deviation']['possible_type']} ({(result['deviation']['confidence']*100):.1f}%)")
            print(f"Audit Status:  {result['deviation']['status']}")
        else:
            print("Deviation:     Skipped (Quality too low or model missing)")
            
        print(f"Disclaimer:    {result['disclaimer']}")
        
    except Exception as e:
        print(f"Prediction failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_inference())
