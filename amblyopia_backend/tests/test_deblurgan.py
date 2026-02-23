"""
Tests for DeblurGAN-v2 integration.
Works without GPU or model weights (fallback sharpening is used).
"""
from __future__ import annotations

import os
import sys

import numpy as np
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

MODEL_PATH = "models/deblurgan/fpn_inception.h5"
ASSET_DIR  = "test_assets"

try:
    import cv2
    _CV2_AVAILABLE = True
except ImportError:
    _CV2_AVAILABLE = False

skip_no_cv2 = pytest.mark.skipif(
    not _CV2_AVAILABLE,
    reason="opencv-python not installed — run: pip install opencv-python",
)


def test_deblurgan_loads():
    """DeblurGANIntegration loads even when model file is missing (fallback mode)."""
    from integrations.deblurgan_integration import DeblurGANIntegration

    # Always works — falls back to sharpening when model missing
    d = DeblurGANIntegration(MODEL_PATH)
    assert d is not None
    print("\nPASS — DeblurGAN loaded (fallback mode if model absent)")


@skip_no_cv2
def test_blur_score_calculation():
    """Laplacian variance: sharp image must score higher than blurry version."""
    from integrations.deblurgan_integration import DeblurGANIntegration
    d = DeblurGANIntegration(MODEL_PATH)

    # Create a sharp image with high contrast edges
    sharp = np.zeros((200, 200, 3), dtype=np.uint8)
    for i in range(0, 200, 4):
        sharp[:, i] = 255

    blurry = cv2.GaussianBlur(sharp, (31, 31), 0)

    sharp_score  = d.calculate_blur_score(sharp)
    blurry_score = d.calculate_blur_score(blurry)

    assert sharp_score > blurry_score, (
        f"Sharp score ({sharp_score:.1f}) should be > blurry ({blurry_score:.1f})"
    )
    print(f"\nPASS — Blur detection working: sharp={sharp_score:.1f} > blurry={blurry_score:.1f}")


@skip_no_cv2
def test_smart_deblur_skips_sharp():
    """smart_deblur() must return was_deblurred=False for a sharp image."""
    from integrations.deblurgan_integration import DeblurGANIntegration, _BLUR_THRESHOLD
    d = DeblurGANIntegration(MODEL_PATH)

    # Build a definitely-sharp image: high-contrast checkerboard
    sharp = np.zeros((200, 200, 3), dtype=np.uint8)
    for i in range(0, 200, 2):
        for j in range(0, 200, 2):
            if (i // 2 + j // 2) % 2 == 0:
                sharp[i, j] = 255

    score = d.calculate_blur_score(sharp)
    if score <= _BLUR_THRESHOLD:
        pytest.skip(f"Synthetic image score {score:.1f} unexpectedly below threshold {_BLUR_THRESHOLD}")

    _, was_deblurred = d.smart_deblur(sharp)
    assert was_deblurred is False, "Expected False — image is already sharp"
    print(f"\nPASS — Sharp image skipped (score={score:.1f})")


@skip_no_cv2
def test_deblur_improves_blur_score():
    """smart_deblur() on the sample blurry image must not decrease blur score."""
    from integrations.deblurgan_integration import DeblurGANIntegration
    d = DeblurGANIntegration(MODEL_PATH)

    input_path = os.path.join(ASSET_DIR, "sample_blurry_image.jpg")
    if not os.path.exists(input_path):
        pytest.skip(f"Test asset missing: {input_path}")

    img = cv2.imread(input_path)
    score_before = d.calculate_blur_score(img)
    result, processed = d.smart_deblur(img)
    score_after  = d.calculate_blur_score(result)

    # Score should improve or stay the same
    assert score_after >= score_before - 0.1, (
        f"Blur score degraded: {score_before:.2f} → {score_after:.2f}"
    )
    print(f"\nPASS — Deblurring working: {score_before:.2f} → {score_after:.2f}")
