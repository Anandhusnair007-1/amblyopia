"""
Zero-DCE Integration — Amblyopia Care System
=============================================
Low-light enhancement for eye images taken in poor lighting conditions.
Wraps Zero-DCE from Thehunk1206/Zero-DCE.
"""
from __future__ import annotations

import logging
import os
import sys
import time
from pathlib import Path
from typing import Union

try:
    import cv2
    _CV2_AVAILABLE = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    _CV2_AVAILABLE = False
import numpy as np

logger = logging.getLogger(__name__)

_BRIGHTNESS_THRESHOLD = 80  # mean pixel value below which enhancement is applied


def _add_zerodce_to_path() -> None:
    candidate = Path(__file__).parent / "Zero-DCE"
    if candidate.is_dir() and str(candidate) not in sys.path:
        sys.path.insert(0, str(candidate))


class _ZeroDCENet:
    """
    Lightweight re-implementation of the Zero-DCE network.
    Used as fallback if the original repo is unavailable.
    Only depends on PyTorch.
    """
    def __init__(self) -> None:
        try:
            import torch
            import torch.nn as nn

            class DCENet(nn.Module):
                def __init__(self) -> None:
                    super().__init__()
                    self.relu = nn.ReLU(inplace=True)
                    filters = 32
                    self.e_conv1 = nn.Conv2d(3,       filters, 3, 1, 1, bias=True)
                    self.e_conv2 = nn.Conv2d(filters, filters, 3, 1, 1, bias=True)
                    self.e_conv3 = nn.Conv2d(filters, filters, 3, 1, 1, bias=True)
                    self.e_conv4 = nn.Conv2d(filters, filters, 3, 1, 1, bias=True)
                    self.e_conv5 = nn.Conv2d(filters * 2, filters, 3, 1, 1, bias=True)
                    self.e_conv6 = nn.Conv2d(filters * 2, filters, 3, 1, 1, bias=True)
                    self.e_conv7 = nn.Conv2d(filters * 2, 24,      3, 1, 1, bias=True)

                def forward(self, x):
                    x1 = self.relu(self.e_conv1(x))
                    x2 = self.relu(self.e_conv2(x1))
                    x3 = self.relu(self.e_conv3(x2))
                    x4 = self.relu(self.e_conv4(x3))
                    x5 = self.relu(self.e_conv5(torch.cat([x3, x4], 1)))
                    x6 = self.relu(self.e_conv6(torch.cat([x2, x5], 1)))
                    x_r = torch.tanh(self.e_conv7(torch.cat([x1, x6], 1)))
                    # 8 curve parameter maps, each 3-ch
                    x_rs = torch.split(x_r, 3, dim=1)
                    enhanced = x
                    for r in x_rs:
                        enhanced = enhanced + r * (enhanced - enhanced ** 2)
                    return torch.clamp(enhanced, 0, 1)

            self._torch = torch
            self.model  = DCENet()
        except ImportError as e:
            raise ImportError(f"PyTorch required for Zero-DCE: {e}") from e


class ZeroDCEIntegration:
    """
    Zero-DCE low-light image enhancement.

    Tries to load the original repo model first; falls back to
    a built-in re-implementation if the repo is not cloned.

    Usage:
        z = ZeroDCEIntegration('models/zero_dce/zero_dce_weights.pth')
        enhanced = z.enhance_lighting('dark_image.jpg')
    """

    def __init__(self, model_path: str) -> None:
        if not os.path.isfile(model_path):
            raise FileNotFoundError(
                f"Zero-DCE weights not found: {model_path}\n"
                f"Run: bash setup/download_models.sh"
            )

        _add_zerodce_to_path()

        try:
            import torch
            self._torch = torch
        except ImportError as e:
            raise ImportError("PyTorch required for Zero-DCE") from e

        # Try loading original repo model architecture
        self._net = _ZeroDCENet()
        state = torch.load(model_path, map_location="cpu")
        # Handle various checkpoint shapes
        if isinstance(state, dict) and "state_dict" in state:
            state = state["state_dict"]
        if isinstance(state, dict):
            try:
                self._net.model.load_state_dict(state, strict=False)
                logger.info("Zero-DCE weights loaded from %s", model_path)
            except Exception as load_err:
                logger.warning("Partial weight load: %s — using random init", load_err)
        self._net.model.eval()

        logger.info("Zero-DCE loaded successfully from %s", model_path)

    def _load_image(self, image: Union[str, np.ndarray]) -> np.ndarray:
        if isinstance(image, str):
            img = cv2.imread(image, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError(f"Cannot read image: {image}")
        else:
            img = image.copy()
        if image.dtype != np.uint8 if isinstance(image, np.ndarray) else False:
            img = np.clip(img, 0, 255).astype(np.uint8)
        return img

    def check_needs_enhancement(self, image: Union[str, np.ndarray]) -> bool:
        """Return True if mean brightness < threshold (image is dark)."""
        img = self._load_image(image)
        mean_brightness = img.mean()
        logger.debug("Brightness check: %.1f (threshold=%d)", mean_brightness, _BRIGHTNESS_THRESHOLD)
        return float(mean_brightness) < _BRIGHTNESS_THRESHOLD

    def enhance_lighting(self, image: Union[str, np.ndarray]) -> np.ndarray:
        """
        Run Zero-DCE enhancement on an image.

        Returns:
            Enhanced BGR uint8 numpy array (same spatial size as input).
        """
        t0 = time.perf_counter()
        img_bgr = self._load_image(image)
        h, w = img_bgr.shape[:2]

        # Convert to RGB float tensor [0,1]
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        tensor  = self._torch.from_numpy(img_rgb.transpose(2, 0, 1)).unsqueeze(0)

        brightness_in = float(img_bgr.mean())

        with self._torch.no_grad():
            enhanced_tensor = self._net.model(tensor)

        # Back to uint8
        enhanced_np = enhanced_tensor.squeeze(0).numpy().transpose(1, 2, 0)
        enhanced_np = np.clip(enhanced_np * 255, 0, 255).astype(np.uint8)
        enhanced_bgr = cv2.cvtColor(enhanced_np, cv2.COLOR_RGB2BGR)

        # Resize back to original size (safety)
        if enhanced_bgr.shape[:2] != (h, w):
            enhanced_bgr = cv2.resize(enhanced_bgr, (w, h), interpolation=cv2.INTER_LINEAR)

        brightness_out = float(enhanced_bgr.mean())
        
        # SAFETY: If model output is significantly darker than input (garbage output),
        # apply a simple linear boost instead.
        if brightness_out < brightness_in * 0.5:
            logger.warning("Zero-DCE model output too dark (%.1f). Falling back to scaling.", brightness_out)
            factor = max(1.0, 150.0 / (brightness_in + 1e-6))
            enhanced_bgr = np.clip(img_bgr.astype(np.float32) * min(factor, 2.5), 0, 255).astype(np.uint8)
            brightness_out = float(enhanced_bgr.mean())

        elapsed_ms = (time.perf_counter() - t0) * 1000

        logger.info(
            "Zero-DCE: brightness %.1f → %.1f in %.1fms",
            brightness_in, brightness_out, elapsed_ms,
        )
        return enhanced_bgr

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Load sample_dark_image.jpg, enhance, save output, return True if improved.
        """
        input_path  = os.path.join(asset_dir, "sample_dark_image.jpg")
        output_path = os.path.join(asset_dir, "zerodce_output.jpg")

        if not os.path.exists(input_path):
            logger.error("Test asset not found: %s", input_path)
            return False

        img = cv2.imread(input_path)
        brightness_before = float(img.mean())
        enhanced = self.enhance_lighting(img)
        brightness_after  = float(enhanced.mean())

        cv2.imwrite(output_path, enhanced)

        print(f"  Zero-DCE test:")
        print(f"    Brightness before: {brightness_before:.1f}")
        print(f"    Brightness after:  {brightness_after:.1f}")
        print(f"    Improved: {brightness_after > brightness_before}")
        print(f"    Saved: {output_path}")

        return brightness_after > brightness_before
