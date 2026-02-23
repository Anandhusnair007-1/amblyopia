"""
Tests for Real-ESRGAN integration.
Skips gracefully if model weights or realesrgan package are unavailable.
"""
from __future__ import annotations

import os
import sys
import numpy as np
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

MODEL_PATH = "models/real_esrgan/RealESRGAN_x4plus.pth"
ASSET_DIR  = "test_assets"


def _can_import_realesrgan() -> bool:
    try:
        import realesrgan  # noqa
        return True
    except ImportError:
        return False


def _model_exists() -> bool:
    return os.path.isfile(MODEL_PATH)


skip_no_model = pytest.mark.skipif(
    not _model_exists(),
    reason=f"Model not found: {MODEL_PATH} — run: bash setup/download_models.sh",
)
skip_no_package = pytest.mark.skipif(
    not _can_import_realesrgan(),
    reason="realesrgan package not installed — run: pip install realesrgan basicsr",
)


@skip_no_package
@skip_no_model
def test_real_esrgan_loads():
    """Real-ESRGAN should initialise without exception."""
    from integrations.real_esrgan_integration import RealESRGANIntegration
    r = RealESRGANIntegration(MODEL_PATH)
    assert r is not None
    assert r.upsampler is not None
    print("\nPASS — Real-ESRGAN loaded")


@skip_no_package
@skip_no_model
def test_real_esrgan_enhances_image():
    """4× upscaling: 100×100 → 400×400, dtype=uint8."""
    from integrations.real_esrgan_integration import RealESRGANIntegration
    r = RealESRGANIntegration(MODEL_PATH)

    # Create a simple synthetic 100×100 BGR image
    img = np.random.randint(50, 200, (100, 100, 3), dtype=np.uint8)
    output = r.enhance(img)

    assert output is not None, "enhance() returned None"
    assert output.shape == (400, 400, 3), \
        f"Expected (400,400,3) got {output.shape}"
    assert output.dtype == np.uint8, \
        f"Expected uint8 got {output.dtype}"
    print("\nPASS — Enhancement working (100×100 → 400×400)")


@skip_no_package
@skip_no_model
def test_real_esrgan_eye_region_only():
    """Eye-region-only mode: output same size as input, content differs."""
    import cv2
    from integrations.real_esrgan_integration import RealESRGANIntegration

    input_path = os.path.join(ASSET_DIR, "sample_eye_image.jpg")
    if not os.path.exists(input_path):
        pytest.skip(f"Test asset missing: {input_path}")

    r   = RealESRGANIntegration(MODEL_PATH)
    img = cv2.imread(input_path)
    out = r.enhance_eye_region_only(img)

    assert out.shape[:2] == img.shape[:2], \
        f"Output size changed: {img.shape[:2]} vs {out.shape[:2]}"
    assert not np.array_equal(img, out), \
        "Output is identical to input — enhancement had no effect"
    print("\nPASS — Eye-region-only enhancement working")


@skip_no_package
@skip_no_model
def test_real_esrgan_sample():
    """test_with_sample() writes output file and returns True."""
    from integrations.real_esrgan_integration import RealESRGANIntegration

    if not os.path.exists(os.path.join(ASSET_DIR, "sample_eye_image.jpg")):
        pytest.skip("Test assets not generated — run: bash setup/test_all_integrations.sh")

    r = RealESRGANIntegration(MODEL_PATH)
    result = r.test_with_sample(ASSET_DIR)

    assert result is True
    assert os.path.isfile(os.path.join(ASSET_DIR, "esrgan_output.jpg"))
    print("\nPASS — Sample test passed, output file created")
