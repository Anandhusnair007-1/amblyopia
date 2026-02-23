"""
Real-ESRGAN Integration — Amblyopia Care System
================================================
Super-resolution for eye images before ML inference.
Wraps the Real-ESRGAN library from xinntao/Real-ESRGAN.
"""
from __future__ import annotations

import logging
import os
import sys
import time
from pathlib import Path
from typing import Optional, Tuple, Union

try:
    import cv2
    _CV2_AVAILABLE = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    _CV2_AVAILABLE = False
import numpy as np

logger = logging.getLogger(__name__)


def _add_realesrgan_to_path() -> None:
    """Add cloned Real-ESRGAN repo to sys.path if not already installed."""
    candidate = Path(__file__).parent / "Real-ESRGAN"
    if candidate.is_dir() and str(candidate) not in sys.path:
        sys.path.insert(0, str(candidate))


class RealESRGANIntegration:
    """
    Wraps Real-ESRGAN for 4x super-resolution of eye images.

    Usage:
        r = RealESRGANIntegration('models/real_esrgan/RealESRGAN_x4plus.pth')
        enhanced = r.enhance('path/to/eye.jpg')
    """

    def __init__(
        self,
        model_path: str,
        scale: int = 4,
        tile: int = 0,
        tile_pad: int = 10,
        pre_pad: int = 0,
    ) -> None:
        if not os.path.isfile(model_path):
            raise FileNotFoundError(
                f"Real-ESRGAN model not found: {model_path}\n"
                f"Run: bash setup/download_models.sh"
            )

        _add_realesrgan_to_path()

        # Monkey-patch torchvision for basicsr compatibility (removed in torchvision 0.17+)
        try:
            import torchvision.transforms.functional as F
            import sys
            sys.modules['torchvision.transforms.functional_tensor'] = F
        except ImportError:
            pass

        try:
            from realesrgan import RealESRGANer
            from basicsr.archs.rrdbnet_arch import RRDBNet
        except ImportError as e:
            raise ImportError(
                f"Real-ESRGAN not installed: {e}\n"
                f"Run: pip install realesrgan basicsr"
            ) from e

        model = RRDBNet(
            num_in_ch=3, num_out_ch=3,
            num_feat=64, num_block=23, num_grow_ch=32, scale=scale
        )

        self.upsampler = RealESRGANer(
            scale=scale,
            model_path=model_path,
            model=model,
            tile=tile,
            tile_pad=tile_pad,
            pre_pad=pre_pad,
            half=False,   # CPU mode — no half precision
        )
        self.scale = scale
        logger.info("Real-ESRGAN loaded successfully from %s", model_path)

    def _load_image(self, image: Union[str, np.ndarray]) -> np.ndarray:
        """Accept file path or numpy array; always return BGR uint8."""
        if isinstance(image, str):
            img = cv2.imread(image, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError(f"Cannot read image: {image}")
            return img
        if not isinstance(image, np.ndarray):
            raise TypeError(f"Expected str or numpy array, got {type(image)}")
        if image.dtype != np.uint8:
            image = np.clip(image, 0, 255).astype(np.uint8)
        if len(image.shape) == 2:
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
        return image

    def enhance(self, image: Union[str, np.ndarray]) -> np.ndarray:
        """
        Run Real-ESRGAN super-resolution on the full image.

        Returns:
            Enhanced numpy array (BGR uint8) at self.scale × resolution.
        """
        t0 = time.perf_counter()
        img_bgr = self._load_image(image)

        # RealESRGANer expects BGR uint8
        output, _ = self.upsampler.enhance(img_bgr, outscale=self.scale)

        elapsed_ms = (time.perf_counter() - t0) * 1000
        logger.info(
            "Real-ESRGAN enhance: %dx%d → %dx%d in %.1fms",
            img_bgr.shape[1], img_bgr.shape[0],
            output.shape[1], output.shape[0],
            elapsed_ms,
        )
        return output

    def enhance_eye_region_only(self, image: Union[str, np.ndarray]) -> np.ndarray:
        """
        Detect eye regions with OpenCV, enhance only those, paste back.
        More efficient than full-image upscaling when eyes are small.

        Returns:
            Original image (same resolution) with eye regions enhanced.
        """
        img = self._load_image(image)
        result = img.copy()

        # Detect faces/eyes via Haar cascades (bundled with OpenCV)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        eye_cascade_path = cv2.data.haarcascades + "haarcascade_eye.xml"
        eye_cascade = cv2.CascadeClassifier(eye_cascade_path)
        eyes = eye_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(20, 20))

        if len(eyes) == 0:
            logger.warning("No eyes detected; enhancing full image instead")
            enhanced_full = self.enhance(img)
            return cv2.resize(enhanced_full, (img.shape[1], img.shape[0]),
                              interpolation=cv2.INTER_AREA)

        for (x, y, w, h) in eyes:
            # Add padding around the eye region
            pad = max(5, w // 5)
            x1 = max(0, x - pad)
            y1 = max(0, y - pad)
            x2 = min(img.shape[1], x + w + pad)
            y2 = min(img.shape[0], y + h + pad)

            eye_crop = img[y1:y2, x1:x2]
            enhanced_crop = self.enhance(eye_crop)
            # Resize enhanced back to original eye bbox size for paste-in
            resized = cv2.resize(
                enhanced_crop, (x2 - x1, y2 - y1),
                interpolation=cv2.INTER_AREA
            )
            result[y1:y2, x1:x2] = resized
            logger.debug("Enhanced eye region at (%d,%d,%d,%d)", x1, y1, x2, y2)

        return result

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Load sample_eye_image.jpg, enhance it, save output.

        Returns:
            True if esrgan_output.jpg was successfully created.
        """
        input_path  = os.path.join(asset_dir, "sample_eye_image.jpg")
        output_path = os.path.join(asset_dir, "esrgan_output.jpg")

        if not os.path.exists(input_path):
            logger.error("Test asset not found: %s", input_path)
            return False

        img = cv2.imread(input_path)
        h_in, w_in = img.shape[:2]

        # Quality metric before: Laplacian variance
        gray_in   = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        score_in  = cv2.Laplacian(gray_in, cv2.CV_64F).var()

        enhanced = self.enhance(img)
        cv2.imwrite(output_path, enhanced)

        gray_out  = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)
        score_out = cv2.Laplacian(gray_out, cv2.CV_64F).var()

        print(f"  Real-ESRGAN test:")
        print(f"    Input:  {w_in}×{h_in}  sharpness={score_in:.1f}")
        print(f"    Output: {enhanced.shape[1]}×{enhanced.shape[0]}  sharpness={score_out:.1f}")
        print(f"    Saved: {output_path}")

        return os.path.isfile(output_path)
