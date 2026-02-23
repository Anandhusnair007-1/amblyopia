"""
Amblyopia Care System — Image Enhancement Service
==================================================
Full preprocessing pipeline for eye images.

GitHub repos wired in:
  ✅ xinntao/Real-ESRGAN    → 4x iris super-resolution
  ✅ Thehunk1206/Zero-DCE  → low-light enhancement
  ✅ KAIR-IBD/DeblurGANv2  → motion/focus deblurring
  ✅ ultralytics/ultralytics → eye/strabismus detection (YOLO)

Loading strategy: LAZY — each model is loaded only on first use
and cached for the process lifetime.  If weights are not yet
downloaded the service falls back to classical OpenCV operations
so the pipeline always returns a result.

PRIVACY: raw image bytes are never persisted — only processed bytes
are returned to the caller.
"""
from __future__ import annotations

import logging
import os

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# ── Model weight paths (relative to project root) ──────────────────────────
_ESRGAN_PATH   = "models/real_esrgan/RealESRGAN_x4plus.pth"
_ZERODCE_PATH  = "models/zero_dce/zero_dce_weights.pth"
_DEBLUR_PATH   = "models/deblurgan/fpn_inception.h5"
_YOLO_PATH     = "models/yolo/yolov8n.pt"

# ── Quality thresholds ──────────────────────────────────────────────────────
BLUR_THRESHOLD  = 100.0   # Laplacian variance below → needs deblur
BRIGHTNESS_MIN  = 50      # mean pixel value below → too dark
BRIGHTNESS_MAX  = 220     # mean pixel value above → overexposed

# ── Lazy-loaded singletons ──────────────────────────────────────────────────
_esrgan_instance  = None
_zerodce_instance = None
_deblur_instance  = None
_yolo_instance    = None


# ══════════════════════════════════════════════════════════════════════════
# Lazy loaders — load each model once, cache, return None on failure
# ══════════════════════════════════════════════════════════════════════════

def _get_esrgan():
    """Load Real-ESRGAN (xinntao/Real-ESRGAN pretrained weights)."""
    global _esrgan_instance
    if _esrgan_instance is not None:
        return _esrgan_instance
    if not os.path.isfile(_ESRGAN_PATH):
        logger.debug("Real-ESRGAN weights not found — using classical sharpening fallback")
        return None
    try:
        from integrations.real_esrgan_integration import RealESRGANIntegration
        _esrgan_instance = RealESRGANIntegration(_ESRGAN_PATH, scale=4)
        logger.info("Real-ESRGAN loaded ✓")
        return _esrgan_instance
    except Exception as exc:
        logger.warning("Real-ESRGAN load failed (%s) — using fallback", exc)
        return None


def _get_zerodce():
    """Load Zero-DCE (Thehunk1206/Zero-DCE pretrained weights)."""
    global _zerodce_instance
    if _zerodce_instance is not None:
        return _zerodce_instance
    if not os.path.isfile(_ZERODCE_PATH):
        logger.debug("Zero-DCE weights not found — using CLAHE fallback")
        return None
    try:
        from integrations.zero_dce_integration import ZeroDCEIntegration
        _zerodce_instance = ZeroDCEIntegration(_ZERODCE_PATH)
        logger.info("Zero-DCE loaded ✓")
        return _zerodce_instance
    except Exception as exc:
        logger.warning("Zero-DCE load failed (%s) — using fallback", exc)
        return None


def _get_deblurgan():
    """Load DeblurGAN-v2 (KAIR-IBD/DeblurGANv2 pretrained weights)."""
    global _deblur_instance
    if _deblur_instance is not None:
        return _deblur_instance
    # DeblurGAN falls back to unsharp-mask even when h5 is missing
    try:
        from integrations.deblurgan_integration import DeblurGANIntegration
        _deblur_instance = DeblurGANIntegration(_DEBLUR_PATH)
        logger.info("DeblurGAN loaded ✓ (fallback=%s)", _deblur_instance._use_fallback)
        return _deblur_instance
    except Exception as exc:
        logger.warning("DeblurGAN load failed (%s) — using unsharp-mask fallback", exc)
        return None


def _get_yolo():
    """Load YOLOv8-nano (ultralytics/ultralytics pretrained weights)."""
    global _yolo_instance
    if _yolo_instance is not None:
        return _yolo_instance
    if not os.path.isfile(_YOLO_PATH):
        logger.debug("YOLOv8 weights not found — eye detection via Haar cascade only")
        return None
    try:
        from integrations.yolo_integration import YOLOIntegration
        _yolo_instance = YOLOIntegration(_YOLO_PATH)
        logger.info("YOLOv8 loaded ✓")
        return _yolo_instance
    except Exception as exc:
        logger.warning("YOLOv8 load failed (%s) — Haar cascade only", exc)
        return None


# ══════════════════════════════════════════════════════════════════════════
# Classical fallbacks (no external weights required)
# ══════════════════════════════════════════════════════════════════════════

def _classical_lighting(image: np.ndarray) -> np.ndarray:
    """CLAHE-based brightness correction (fallback for Zero-DCE)."""
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l_ch, a_ch, b_ch = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return cv2.cvtColor(cv2.merge([clahe.apply(l_ch), a_ch, b_ch]), cv2.COLOR_LAB2BGR)


def _classical_sharpen(image: np.ndarray) -> np.ndarray:
    """Unsharp-mask sharpening (fallback for Real-ESRGAN)."""
    blurred = cv2.GaussianBlur(image, (0, 0), 3)
    return cv2.addWeighted(image, 1.5, blurred, -0.5, 0)


def _classical_deblur(image: np.ndarray) -> np.ndarray:
    """Laplacian + unsharp-mask deblur (fallback for DeblurGAN)."""
    blurred  = cv2.GaussianBlur(image, (0, 0), 3)
    sharpened = cv2.addWeighted(image, 1.5, blurred, -0.5, 0)
    kernel   = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]], dtype=np.float32)
    return np.clip(cv2.filter2D(sharpened, -1, kernel), 0, 255).astype(np.uint8)


# ══════════════════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════════════════

def quality_gate(image_bytes: bytes) -> dict:
    """
    Check whether the image is suitable for ML inference.

    Returns:
        {
          pass: bool,
          reason: str,
          blur_score: float,
          brightness: float,
          has_face: bool,
        }
    """
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img   = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"pass": False, "reason": "Image decode failed",
                    "blur_score": 0.0, "brightness": 0.0, "has_face": False}

        gray       = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        brightness = float(np.mean(gray))

        # Try YOLO-based face/eye detection first; fall back to Haar
        yolo = _get_yolo()
        face_confidence = 0.0
        if yolo is not None:
            try:
                detections = yolo.detect_eyes(img)
                has_face = len(detections) > 0
                if has_face and detections:
                    # Use max confidence from detections if available
                    confs = [d.get("confidence", 0.8) for d in detections if isinstance(d, dict)]
                    face_confidence = float(max(confs)) if confs else 0.8
                elif has_face:
                    face_confidence = 0.8
            except Exception:
                has_face = _haar_face_check(gray)
                face_confidence = 0.7 if has_face else 0.0
        else:
            has_face = _haar_face_check(gray)
            face_confidence = 0.7 if has_face else 0.0

        if blur_score < BLUR_THRESHOLD:
            return {"pass": False, "reason": "Image too blurry",
                    "blur_score": blur_score, "brightness": brightness,
                    "has_face": has_face, "face_confidence": face_confidence}
        if brightness < BRIGHTNESS_MIN:
            return {"pass": False, "reason": "Image too dark",
                    "blur_score": blur_score, "brightness": brightness,
                    "has_face": has_face, "face_confidence": face_confidence}
        if brightness > BRIGHTNESS_MAX:
            return {"pass": False, "reason": "Image overexposed",
                    "blur_score": blur_score, "brightness": brightness,
                    "has_face": has_face, "face_confidence": face_confidence}

        return {"pass": True, "reason": "OK",
                "blur_score": blur_score, "brightness": brightness,
                "has_face": has_face, "face_confidence": face_confidence}

    except Exception as exc:
        logger.error("Quality gate error: %s", exc)
        return {"pass": False, "reason": str(exc),
                "blur_score": 0.0, "brightness": 0.0, "has_face": False, "face_confidence": 0.0}


def _haar_face_check(gray: np.ndarray) -> bool:
    cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    return len(cascade.detectMultiScale(gray, 1.1, 4)) > 0


def enhance_lighting(image: np.ndarray) -> np.ndarray:
    """
    Low-light enhancement.

    Primary:  Zero-DCE (Thehunk1206/Zero-DCE) — neural curve adjustment
    Fallback: CLAHE on LAB L-channel
    """
    brightness = float(image.mean())
    if brightness >= BRIGHTNESS_MIN * 1.5:
        return image  # Already bright enough — skip

    zerodce = _get_zerodce()
    if zerodce is not None:
        try:
            if zerodce.check_needs_enhancement(image):
                return zerodce.enhance_lighting(image)
            return image
        except Exception as exc:
            logger.warning("Zero-DCE inference failed (%s) — using CLAHE", exc)

    return _classical_lighting(image)


def remove_blur(image: np.ndarray, blur_score: float) -> np.ndarray:
    """
    Motion/focus deblurring.

    Primary:  DeblurGAN-v2 (KAIR-IBD/DeblurGANv2) — smart deblur gate
    Fallback: Unsharp-mask via classical pipeline
    """
    deblur = _get_deblurgan()
    if deblur is not None:
        try:
            result, was_processed = deblur.smart_deblur(image)
            return result
        except Exception as exc:
            logger.warning("DeblurGAN inference failed (%s) — using classical", exc)

    # Classical fallback
    if blur_score < BLUR_THRESHOLD:
        return _classical_deblur(image)
    return image


def sharpen_iris(image: np.ndarray) -> np.ndarray:
    """
    Iris super-resolution / sharpening.

    Primary:  Real-ESRGAN (xinntao/Real-ESRGAN) — enhance_eye_region_only()
              → only the detected eye bounding box is upscaled then pasted back
              → output is same spatial size as input
    Fallback: Laplacian kernel sharpening on Haar-detected eye regions
    """
    esrgan = _get_esrgan()
    if esrgan is not None:
        try:
            return esrgan.enhance_eye_region_only(image)
        except Exception as exc:
            logger.warning("Real-ESRGAN iris enhance failed (%s) — using classical", exc)

    # Classical fallback: kernel sharpen on Haar eye ROIs
    gray   = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    ec     = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_eye.xml")
    eyes   = ec.detectMultiScale(gray, 1.1, 5)
    result = image.copy()
    kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
    if len(eyes) > 0:
        for (ex, ey, ew, eh) in eyes:
            result[ey:ey+eh, ex:ex+ew] = cv2.filter2D(image[ey:ey+eh, ex:ex+ew], -1, kernel)
    else:
        result = cv2.filter2D(image, -1, kernel)
    return result


def enhance_contrast(image: np.ndarray) -> np.ndarray:
    """CLAHE contrast enhancement on LAB L-channel."""
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l_ch, a_ch, b_ch = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return cv2.cvtColor(cv2.merge([clahe.apply(l_ch), a_ch, b_ch]), cv2.COLOR_LAB2BGR)


def detect_strabismus(image: np.ndarray) -> dict:
    """
    Run YOLO strabismus signal detection (ultralytics/ultralytics).
    Returns empty dict if YOLO not available.
    """
    yolo = _get_yolo()
    if yolo is None:
        return {}
    try:
        return yolo.detect_strabismus_signals(image)
    except Exception as exc:
        logger.warning("Strabismus detection failed: %s", exc)
        return {}


def full_pipeline(image_bytes: bytes) -> dict:
    """
    Complete image preprocessing pipeline:

      quality_gate()         ← YOLO + Haar checks
        ↓ pass
      enhance_lighting()     ← Zero-DCE  (or CLAHE fallback)
        ↓
      remove_blur()          ← DeblurGAN (or unsharp-mask fallback)
        ↓
      sharpen_iris()         ← Real-ESRGAN eye region (or kernel fallback)
        ↓
      enhance_contrast()     ← CLAHE always applied

    Raw face image is processed and immediately discarded.
    Only enhanced bytes are returned to the caller.

    Returns:
        {
          passed: bool,
          quality_report: dict,
          enhanced_bytes: bytes | None,
          strabismus: dict,          # from YOLOv8 if available
          pipeline_steps: list[str], # log of which path was taken
        }
    """
    steps: list = []

    quality = quality_gate(image_bytes)
    steps.append(f"quality_gate: {'PASS' if quality['pass'] else 'FAIL (' + quality['reason'] + ')'}")

    if not quality["pass"]:
        return {
            "passed": False,
            "quality_report": quality,
            "enhanced_bytes": None,
            "strabismus": {},
            "pipeline_steps": steps,
        }

    nparr = np.frombuffer(image_bytes, np.uint8)
    img   = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # Step 1 — lighting
    img = enhance_lighting(img)
    steps.append(f"enhance_lighting: Zero-DCE={'loaded' if _zerodce_instance else 'fallback'}")

    # Step 2 — deblur
    img = remove_blur(img, quality.get("blur_score", BLUR_THRESHOLD))
    steps.append(f"remove_blur: DeblurGAN={'loaded' if _deblur_instance else 'fallback'}")

    # Step 3 — iris super-resolution
    img = sharpen_iris(img)
    steps.append(f"sharpen_iris: ESRGAN={'loaded' if _esrgan_instance else 'fallback'}")

    # Step 4 — contrast
    img = enhance_contrast(img)
    steps.append("enhance_contrast: CLAHE")

    # Optional — strabismus signals (non-blocking)
    strabismus = detect_strabismus(img)
    steps.append(f"strabismus: YOLO={'loaded' if _yolo_instance else 'unavailable'}")

    # Encode to PNG bytes
    success, buf = cv2.imencode(".png", img)
    if not success:
        return {"passed": False, "quality_report": quality,
                "enhanced_bytes": None, "strabismus": {}, "pipeline_steps": steps}

    return {
        "passed": True,
        "quality_report": quality,
        "enhanced_bytes": buf.tobytes(),
        "strabismus": strabismus,
        "pipeline_steps": steps,
    }
