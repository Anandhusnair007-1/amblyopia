
import pytest
import numpy as np
import cv2
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from integrations.yolo_integration import YOLOIntegration

MODEL_PATH = "models/yolo/yolov8n.pt"
SAMPLE_IMAGE = "test_assets/sample_eye_image.jpg"

@pytest.fixture
def yolo():
    if not os.path.exists(MODEL_PATH):
        pytest.skip(f"Model not found: {MODEL_PATH}")
    return YOLOIntegration(MODEL_PATH)

def test_yolo_loads(yolo):
    assert yolo is not None
    print("PASS — YOLOv8 loads")

def test_yolo_runs_inference(yolo):
    """
    Test that YOLO runs inference without crashing.
    YOLOv8n is a general detector — it must run without error even if 0 eyes are found.
    """
    if not os.path.exists(SAMPLE_IMAGE):
        pytest.skip("Sample image not found")
    
    img = cv2.imread(SAMPLE_IMAGE)
    assert img is not None
    
    try:
        result = yolo.detect_eyes(img)
        assert isinstance(result, list)
        print(f"PASS — YOLO ran, found {len(result)} objects")
    except Exception as e:
        pytest.fail(f"YOLO inference crashed: {e}")

def test_yolo_returns_correct_format(yolo):
    """Test strabismus result has correct structure"""
    if not os.path.exists(SAMPLE_IMAGE):
        pytest.skip("Sample image not found")
    
    img = cv2.imread(SAMPLE_IMAGE)
    result = yolo.detect_strabismus_signals(img)
    
    required_keys = [
        "left_eye_bbox",
        "right_eye_bbox",
        "misalignment_angle",
        "strabismus_flag",
        "confidence"
    ]
    
    for key in required_keys:
        assert key in result, f"Missing key: {key} in result"
    
    assert isinstance(result["misalignment_angle"], (float, int))
    assert isinstance(result["strabismus_flag"], bool)
    assert 0.0 <= result["confidence"] <= 1.0
    
    print("PASS — Strabismus result format correct")

def test_yolo_saves_output(yolo):
    """Test that detection output image is saved"""
    if not os.path.exists(SAMPLE_IMAGE):
        pytest.skip("Sample image not found")
    
    result = yolo.test_with_sample()
    output_path = "test_assets/yolo_output.jpg"
    assert os.path.exists(output_path), "Output image was not saved"
    print("PASS — Output image saved")
