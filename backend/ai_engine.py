# Model files go in backend/models/
# Quality model:     eye_quality_v1.keras  (env: AMBYO_QUALITY_MODEL)
# Deviation model:   (env: AMBYO_DEVIATION_MODEL)
# Strabismus model:  strabismus_model.keras (env: AMBYO_STRABISMUS_MODEL)
# Download/train models separately — not committed to git

import os
import io
from pathlib import Path

import numpy as np
from PIL import Image
from fastapi import UploadFile, HTTPException

_BACKEND_ROOT = Path(__file__).resolve().parent
_DEFAULT_QUALITY = str(_BACKEND_ROOT / "models" / "eye_quality_v1.keras")
_DEFAULT_DEVIATION = str(_BACKEND_ROOT / "models" / "deviation_v0_2_debug" / "model.keras")
_DEFAULT_STRABISMUS = str(_BACKEND_ROOT / "models" / "strabismus_model.keras")

# Configurable model paths (env overrides; defaults match Docker layout: backend copied to /app/)
QUALITY_MODEL_PATH = os.environ.get("AMBYO_QUALITY_MODEL", _DEFAULT_QUALITY)
DEVIATION_MODEL_PATH = os.environ.get("AMBYO_DEVIATION_MODEL", _DEFAULT_DEVIATION)
STRABISMUS_MODEL_PATH = os.environ.get("AMBYO_STRABISMUS_MODEL", _DEFAULT_STRABISMUS)
QUALITY_MODEL_VERSION = os.environ.get("AMBYO_QUALITY_MODEL_VERSION", "eye_quality_v1")
DEVIATION_MODEL_VERSION = os.environ.get("AMBYO_DEVIATION_MODEL_VERSION", "deviation_classifier_v0_2_balanced")
STRABISMUS_MODEL_VERSION = "strabismus_v1.0.0"
STRABISMUS_CLASSES = ["Normal", "XT", "ET", "HT"]
HEURISTIC_QUALITY_VERSION = f"{QUALITY_MODEL_VERSION}_heuristic"

# Lazy TensorFlow: `ai_engine` imports without TF; TF loads only when loading .keras weights.
_TF_FAILED = object()
_tf_lazy = None


def _get_tf():
    global _tf_lazy
    if _tf_lazy is _TF_FAILED:
        return None
    if _tf_lazy is not None:
        return _tf_lazy
    try:
        import tensorflow as tf  # noqa: PLC0415

        _tf_lazy = tf
        return _tf_lazy
    except (ImportError, OSError):
        _tf_lazy = _TF_FAILED
        return None


def _heuristic_quality(img: Image.Image) -> dict:
    """
    Lightweight quality hints when .keras weights are absent (demo / dev).
    Same response shape as the TF classifier; not a clinical substitute.
    """
    arr = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    gray = arr.mean(axis=2)
    brightness = float(gray.mean())
    contrast = float(gray.std())
    gx = np.abs(np.diff(gray, axis=1))
    gy = np.abs(np.diff(gray, axis=0))
    sharp = float(np.mean(gx) + np.mean(gy))

    label = "good"
    conf = 0.82
    if brightness < 0.14:
        label, conf, is_usable = "dark", 0.86, False
    elif brightness > 0.90 and contrast < 0.06:
        label, conf, is_usable = "reflection_issue", 0.80, False
    elif sharp < 0.012 and contrast < 0.045:
        label, conf, is_usable = "blurred", 0.84, False
    elif contrast < 0.035:
        label, conf, is_usable = "blurred", 0.78, False
    else:
        is_usable = label == "good" and conf >= 0.80

    return {
        "quality": {"label": label, "confidence": conf, "is_usable": is_usable},
        "deviation": None,
        "doctor_review_required": True,
        "model_version": DEVIATION_MODEL_VERSION,
        "quality_model_version": HEURISTIC_QUALITY_VERSION,
        "deviation_model_version": DEVIATION_MODEL_VERSION,
        "disclaimer": (
            "AI-assisted screening only. Final diagnosis must be confirmed by an ophthalmologist. "
            "Camera check uses basic image checks because the trained quality model is not loaded."
        ),
        "heuristic_fallback": True,
    }


def _heuristic_strabismus_fallback() -> dict:
    return {
        "condition": "Normal",
        "confidence": 0.0,
        "risk": "normal",
        "all_scores": {"Normal": 1.0, "XT": 0.0, "ET": 0.0, "HT": 0.0},
        "model_version": STRABISMUS_MODEL_VERSION,
        "heuristic_fallback": True,
    }


def _risk_from_strabismus(condition: str, confidence: float) -> str:
    """Map 4-class label + confidence to clinical-style risk bucket."""
    if condition == "Normal":
        return "normal"
    if condition in ("XT", "ET"):
        if confidence >= 0.80:
            return "urgent"
        if confidence >= 0.60:
            return "moderate"
        return "mild"
    if condition == "HT":
        if confidence >= 0.70:
            return "moderate"
        return "mild"
    return "normal"


class AmbyoAIEngine:
    def __init__(self):
        self.quality_model = None
        self.deviation_model = None
        self.strabismus_model = None
        self.quality_model_path = QUALITY_MODEL_PATH
        self.deviation_model_path = DEVIATION_MODEL_PATH
        self.strabismus_model_path = STRABISMUS_MODEL_PATH
        self.quality_classes = ['good', 'blurred', 'dark', 'bad_crop', 'reflection_issue', 'unknown']
        self.version = DEVIATION_MODEL_VERSION
        self.quality_version = QUALITY_MODEL_VERSION
        self._load_strabismus_model()

    def _load_strabismus_model(self) -> None:
        """Load MobileNetV2 4-class weights only (separate from quality/deviation in load_models)."""
        tf = _get_tf()
        if tf is None:
            return
        if not os.path.exists(STRABISMUS_MODEL_PATH):
            return
        try:
            self.strabismus_model = tf.keras.models.load_model(STRABISMUS_MODEL_PATH, compile=False)
            print(f"Loaded Strabismus Model from {STRABISMUS_MODEL_PATH}")
        except Exception as e:
            print(f"Error loading Strabismus Model: {e}")
            self.strabismus_model = None

    def load_models(self):
        tf = _get_tf()
        if tf is None:
            return
        if os.path.exists(QUALITY_MODEL_PATH):
            try:
                self.quality_model = tf.keras.models.load_model(QUALITY_MODEL_PATH, compile=False)
            except Exception as e:
                print(f"Error loading Quality Model: {e}")

        if os.path.exists(DEVIATION_MODEL_PATH):
            try:
                self.deviation_model = tf.keras.models.load_model(DEVIATION_MODEL_PATH, compile=False)
                print(f"Loaded Deviation Model from {DEVIATION_MODEL_PATH}")
            except Exception as e:
                print(f"Error loading Deviation Model: {e}")

    async def screen_eye(self, file: UploadFile):
        contents = await file.read()
        img = Image.open(io.BytesIO(contents)).convert("RGB").resize((224, 224))

        if not self.quality_model:
            self.load_models()

        if not self.quality_model:
            return _heuristic_quality(img)

        try:
            # Preprocessing for Quality (Rescale 1/255)
            q_img = np.array(img) / 255.0
            q_img = np.expand_dims(q_img, axis=0)
            
            # 1. Quality Check
            q_preds = self.quality_model.predict(q_img)
            q_idx = np.argmax(q_preds[0])
            q_conf = float(q_preds[0][q_idx])
            q_label = self.quality_classes[q_idx]
            
            is_usable = (q_label == 'good' and q_conf >= 0.80)
            
            result = {
                "quality": {
                    "label": q_label,
                    "confidence": q_conf,
                    "is_usable": is_usable,
                },
                "deviation": None,
                "doctor_review_required": True,
                "model_version": self.version,
                "quality_model_version": self.quality_version,
                "deviation_model_version": self.version,
                "disclaimer": "AI-assisted screening only. Final diagnosis must be confirmed by an ophthalmologist."
            }

            # 2. Deviation Check (Safety: only if quality is usable)
            if is_usable and self.deviation_model:
                # Preprocessing for Deviation ([-1, 1] range as per debug script)
                d_img = (np.array(img) / 127.5) - 1.0
                d_img = np.expand_dims(d_img, axis=0)
                
                score = float(self.deviation_model.predict(d_img)[0][0])
                
                # Binary logic: 0.5 threshold
                # Confidence is distance from 0.5
                conf = abs(score - 0.5) * 2.0
                
                if conf < 0.75: # Safety threshold
                    d_label = "uncertain"
                else:
                    d_label = "ET" if score >= 0.5 else "XT"
                
                result["deviation"] = {
                    "possible_type": d_label,
                    "confidence": conf,
                    "score": score,
                    "status": "review required"
                }

            return result

        except Exception as e:
            raise HTTPException(400, f"Screening failed: {str(e)}")

    async def classify_strabismus(self, file: UploadFile):
        contents = await file.read()
        img = Image.open(io.BytesIO(contents)).convert("RGB").resize((224, 224))

        if not self.strabismus_model:
            self._load_strabismus_model()

        if not self.strabismus_model:
            return _heuristic_strabismus_fallback()

        try:
            img_arr = np.asarray(img, dtype=np.float32) / 255.0
            img_arr = np.expand_dims(img_arr, axis=0)

            preds = self.strabismus_model.predict(img_arr, verbose=0)
            raw = np.asarray(preds[0], dtype=np.float32).flatten()
            if raw.size != len(STRABISMUS_CLASSES):
                raise ValueError(f"Expected {len(STRABISMUS_CLASSES)} outputs, got {raw.size}")
            total = float(np.sum(raw))
            looks_like_probs = (
                np.all(raw >= -1e-6)
                and np.all(raw <= 1.0 + 1e-6)
                and 0.98 <= total <= 1.02
            )
            if looks_like_probs:
                probs = raw / total
            else:
                exp = np.exp(raw - np.max(raw))
                probs = exp / np.sum(exp)
            idx = int(np.argmax(probs))
            condition = STRABISMUS_CLASSES[idx]
            confidence = round(float(probs[idx]), 3)
            all_scores = {
                STRABISMUS_CLASSES[i]: round(float(probs[i]), 6) for i in range(len(STRABISMUS_CLASSES))
            }
            risk = _risk_from_strabismus(condition, confidence)

            return {
                "condition": condition,
                "confidence": confidence,
                "risk": risk,
                "all_scores": all_scores,
                "model_version": STRABISMUS_MODEL_VERSION,
            }
        except Exception as e:
            raise HTTPException(400, f"Strabismus classification failed: {str(e)}")

ai_engine = AmbyoAIEngine()
