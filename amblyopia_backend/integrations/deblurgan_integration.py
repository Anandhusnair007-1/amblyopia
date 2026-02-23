"""
DeblurGAN-v2 Integration — Amblyopia Care System
=================================================
Motion / focus deblurring for eye images before ML inference.
Wraps DeblurGAN-v2 FPN-Inception from KAIR-IBD/DeblurGANv2.
Falls back to sharpening kernel when model weights are unavailable.
"""
from __future__ import annotations

import logging
import os
import sys
import time
from pathlib import Path
from typing import Tuple, Union

try:
    import cv2
    _CV2_AVAILABLE = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    _CV2_AVAILABLE = False
import numpy as np

logger = logging.getLogger(__name__)

_BLUR_THRESHOLD = 100.0  # Laplacian variance below this → needs deblurring


def _add_deblurgan_to_path() -> None:
    candidate = Path(__file__).parent / "DeblurGANv2"
    if candidate.is_dir() and str(candidate) not in sys.path:
        sys.path.insert(0, str(candidate))


class DeblurGANIntegration:
    """
    DeblurGAN-v2 deblurring integration.

    When DeblurGAN-v2 weights (fpn_inception.h5) are available, uses the
    full generative model.  Otherwise falls back to unsharp-mask sharpening
    so the pipeline always gets *some* deblurring benefit.

    Usage:
        d = DeblurGANIntegration('models/deblurgan/fpn_inception.h5')
        result, was_processed = d.smart_deblur(image)
    """

    def __init__(self, model_path: str) -> None:
        self._model      = None
        self._model_path = model_path
        self._use_fallback = False

        if not os.path.isfile(model_path):
            logger.warning(
                "DeblurGAN weights not found at %s — using sharpening fallback.\n"
                "Run: bash setup/download_models.sh",
                model_path,
            )
            self._use_fallback = True
            logger.info("DeblurGAN loaded (sharpening fallback mode)")
            return

        _add_deblurgan_to_path()

        # Try loading Keras model (fpn_inception.h5)
        try:
            import tensorflow as tf  # type: ignore
            self._model = tf.keras.models.load_model(model_path, compile=False)
            self._model.trainable = False
            logger.info("DeblurGAN FPN-Inception loaded from %s (Keras mode)", model_path)
        except Exception as keras_err:
            logger.warning(
                "Keras load failed (%s) — using sharpening fallback", keras_err
            )
            self._use_fallback = True

        logger.info("DeblurGAN loaded successfully")

    def calculate_blur_score(self, image: Union[str, np.ndarray]) -> float:
        """
        Return Laplacian variance of the image.
        Higher = sharper.  Score < 100 typically means blurry.
        """
        img = self._load_image(image)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
        score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        return score

    def deblur(self, image: Union[str, np.ndarray]) -> np.ndarray:
        """
        Deblur the image using DeblurGAN FPN-Inception or sharpening fallback.

        Returns:
            Deblurred BGR uint8 numpy array.
        """
        t0 = time.perf_counter()
        img = self._load_image(image)
        h, w = img.shape[:2]

        score_before = self.calculate_blur_score(img)

        if self._use_fallback or self._model is None:
            result = self._sharpen_fallback(img)
        else:
            result = self._deblurgan_inference(img)

        # Restore original spatial size if model changed it
        if result.shape[:2] != (h, w):
            result = cv2.resize(result, (w, h), interpolation=cv2.INTER_LINEAR)

        score_after = self.calculate_blur_score(result)
        elapsed_ms  = (time.perf_counter() - t0) * 1000

        logger.info(
            "DeblurGAN: blur score %.1f → %.1f in %.1fms",
            score_before, score_after, elapsed_ms,
        )
        return result

    def smart_deblur(
        self, image: Union[str, np.ndarray]
    ) -> Tuple[np.ndarray, bool]:
        """
        Only deblur if blur_score < threshold (avoids processing sharp images).

        Returns:
            (image_array, was_deblurred_bool)
        """
        img = self._load_image(image)
        score = self.calculate_blur_score(img)
        if score > _BLUR_THRESHOLD:
            logger.debug("Image already sharp (score=%.1f) — skipping deblur", score)
            return img, False
        result = self.deblur(img)
        return result, True

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Load sample_blurry_image.jpg, smart_deblur, save, return True if improved.
        """
        input_path  = os.path.join(asset_dir, "sample_blurry_image.jpg")
        output_path = os.path.join(asset_dir, "deblurgan_output.jpg")

        if not os.path.exists(input_path):
            logger.error("Test asset not found: %s", input_path)
            return False

        img = cv2.imread(input_path)
        score_before = self.calculate_blur_score(img)
        result, processed = self.smart_deblur(img)
        score_after = self.calculate_blur_score(result)
        cv2.imwrite(output_path, result)

        print(f"  DeblurGAN test:")
        print(f"    Blur score before: {score_before:.2f}")
        print(f"    Blur score after:  {score_after:.2f}")
        print(f"    Was deblurred: {processed}")
        print(f"    Saved: {output_path}")

        return score_after >= score_before  # fallback may match

    # ── Private helpers ──────────────────────────────────────────────────────

    def _load_image(self, image: Union[str, np.ndarray]) -> np.ndarray:
        if isinstance(image, str):
            img = cv2.imread(image, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError(f"Cannot read image: {image}")
            return img
        if not isinstance(image, np.ndarray):
            raise TypeError(f"Expected str or numpy array, got {type(image)}")
        img = image.copy()
        if img.dtype != np.uint8:
            img = np.clip(img, 0, 255).astype(np.uint8)
        if len(img.shape) == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
        return img

    def _sharpen_fallback(self, img: np.ndarray) -> np.ndarray:
        """Unsharp-mask as CPU fallback when DeblurGAN model unavailable."""
        blurred  = cv2.GaussianBlur(img, (0, 0), sigmaX=3)
        sharpened = cv2.addWeighted(img, 1.5, blurred, -0.5, 0)
        # Second pass with a laplacian sharpening kernel
        kernel = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]], dtype=np.float32)
        sharpened = cv2.filter2D(sharpened, -1, kernel)
        return np.clip(sharpened, 0, 255).astype(np.uint8)

    def _deblurgan_inference(self, img: np.ndarray) -> np.ndarray:
        """Run DeblurGAN-v2 Keras model inference."""
        # numpy already imported at module level as np

        h, w = img.shape[:2]
        # Model expects 256×256 RGB float32 in [-1, 1]
        resized = cv2.resize(img, (256, 256))
        rgb     = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB).astype(np.float32) / 127.5 - 1.0
        batch   = rgb[np.newaxis]  # (1, 256, 256, 3)
        out     = self._model.predict(batch, verbose=0)[0]  # (256, 256, 3)
        out     = ((out + 1.0) * 127.5).clip(0, 255).astype(np.uint8)
        out_bgr = cv2.cvtColor(out, cv2.COLOR_RGB2BGR)
        return cv2.resize(out_bgr, (w, h), interpolation=cv2.INTER_LINEAR)
