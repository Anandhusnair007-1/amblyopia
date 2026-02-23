"""
Amblyopia Care System — ML Wrapper Service
==========================================
Pluggable TFLite model inference. Reads from local ./models/ folder
when MINIO_DISABLED=true (local mode) or from MinIO in production.

GitHub repos wired in:
  ✅ mlflow/mlflow  — log every prediction (file:./mlruns in local mode)
  ✅ minio/minio    — production model storage (skipped when MINIO_DISABLED)
  ✅ tumuyan/ESRGAN-Android-TFLite-Demo — TFLite input spec reference
"""
from __future__ import annotations

import logging
import os
import random
from typing import Optional

from app.config import settings

logger = logging.getLogger(__name__)

# ── In-process model cache ───────────────────────────────────────────────────
_active_model           = None
_active_model_version: Optional[str] = None

# Local path where TFLite model can live without MinIO
_LOCAL_TFLITE_DIR = "models/tflite"


def _hash_image(image_bytes: bytes) -> str:
    import hashlib
    return hashlib.sha256(image_bytes).hexdigest()[:16]


def _log_to_mlflow(
    input_hash: str,
    output: float,
    confidence: float,
    model_version: str,
    tags: dict = None,
) -> None:
    """
    Log prediction to MLflow.
    LOCAL mode  → writes to ./mlruns/  (file store, no server needed)
    PRODUCTION  → writes to MLFLOW_TRACKING_URI HTTP server
    """
    try:
        import mlflow
        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        mlflow.set_experiment(settings.mlflow_experiment_name)

        with mlflow.start_run(run_name=f"predict_{input_hash[:8]}"):
            mlflow.log_param("input_hash",    input_hash)
            mlflow.log_param("model_version", model_version)
            mlflow.log_metric("prediction_score", output)
            mlflow.log_metric("confidence",       confidence)
            if tags:
                mlflow.set_tags(tags)
    except Exception as exc:
        logger.debug("MLflow logging skipped: %s", exc)


def _find_local_tflite() -> Optional[str]:
    """Look for the newest .tflite file in the local models/tflite/ directory."""
    if not os.path.isdir(_LOCAL_TFLITE_DIR):
        return None
    candidates = [
        f for f in os.listdir(_LOCAL_TFLITE_DIR) if f.endswith(".tflite")
    ]
    if not candidates:
        return None
    candidates.sort()                  # newest by name convention
    return os.path.join(_LOCAL_TFLITE_DIR, candidates[-1])


async def _load_from_minio():
    """Download latest TFLite model from MinIO (production only)."""
    try:
        from minio import Minio
        client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )
        objects  = list(client.list_objects(settings.minio_bucket, prefix="models/", recursive=True))
        tflites  = [o for o in objects if o.object_name.endswith(".tflite")]
        if not tflites:
            return None, None

        latest  = sorted(tflites, key=lambda o: o.last_modified, reverse=True)[0]
        version = latest.object_name.split("/")[-1].replace(".tflite", "")

        import tempfile
        data   = client.get_object(settings.minio_bucket, latest.object_name)
        model_bytes = data.read()

        with tempfile.NamedTemporaryFile(suffix=".tflite", delete=False) as tmp:
            tmp.write(model_bytes)
            return tmp.name, version
    except Exception as exc:
        logger.warning("MinIO model fetch failed: %s", exc)
        return None, None


def _load_tflite_interpreter(model_path: str):
    """Load a TFLite interpreter from a local .tflite file."""
    try:
        import tflite_runtime.interpreter as tflite
    except ImportError:
        try:
            import tensorflow as tf
            tflite = tf.lite
        except ImportError:
            logger.warning("No TFLite runtime — install tflite-runtime or tensorflow")
            return None

    interpreter = tflite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    return interpreter


async def get_active_model():
    """
    Load TFLite model.

    LOCAL mode  (MINIO_DISABLED=true):
        → looks in  models/tflite/*.tflite
        → returns None (placeholder) if none found

    PRODUCTION mode:
        → downloads from MinIO
        → caches in-process until version changes
    """
    global _active_model, _active_model_version

    minio_disabled = os.getenv("MINIO_DISABLED", "false").lower() in ("true", "1", "yes")

    if minio_disabled:
        # ── Local mode ────────────────────────────────────────────────────
        local_path = _find_local_tflite()
        if local_path is None:
            return None     # → placeholder inference

        version = os.path.basename(local_path).replace(".tflite", "")
        if _active_model_version == version and _active_model is not None:
            return _active_model   # cache hit

        interpreter = _load_tflite_interpreter(local_path)
        if interpreter:
            _active_model         = interpreter
            _active_model_version = version
            logger.info("Loaded local TFLite model: %s", local_path)
        return interpreter

    else:
        # ── MinIO / production mode ───────────────────────────────────────
        tmp_path, version = await _load_from_minio()
        if tmp_path is None:
            return None

        if _active_model_version == version and _active_model is not None:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            return _active_model

        interpreter = _load_tflite_interpreter(tmp_path)
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

        if interpreter:
            _active_model         = interpreter
            _active_model_version = version
            logger.info("Loaded MinIO TFLite model version: %s", version)
        return interpreter


async def predict_amblyopia(
    enhanced_image_bytes: bytes,
    session_id: str = "unknown",
    age_group: str = "adult",
) -> dict:
    """
    Run amblyopia prediction on a preprocessed eye image.

    Priority:
      1. TFLite model (MinIO / local)
      2. MLflow pyfunc production model (registry)
      3. Placeholder score (triggers doctor review)

    Always logs result to MLflow.
    """
    input_hash = _hash_image(enhanced_image_bytes)

    # ── Try TFLite first ─────────────────────────────────────────────────────
    model = await get_active_model()

    # ── Fall back to MLflow registry model ────────────────────────────────────
    if model is None:
        try:
            from app.services.mlflow_model_service import get_production_model, model_status
            pyfunc_model = get_production_model()
            if pyfunc_model is not None:
                import io
                import numpy as np
                import pandas as pd
                from PIL import Image as PILImage

                size = settings.tflite_input_size
                img  = PILImage.open(io.BytesIO(enhanced_image_bytes)).convert("RGB").resize((size, size))
                inp  = np.array(img, dtype=np.float32).flatten()[None, ...] / 255.0
                df   = pd.DataFrame(inp)
                preds = pyfunc_model.predict(df)
                score = float(preds[0]) if hasattr(preds, '__len__') else float(preds)
                score = max(0.0, min(1.0, score))
                confidence = 0.85  # pyfunc model default confidence
                status = model_status()
                result = {
                    "prediction_score":    round(score, 4),
                    "confidence":          round(confidence, 4),
                    "needs_doctor_review": confidence < settings.model_confidence_threshold,
                    "model_version":       status.get("version", "mlflow-registry"),
                    "mode":                "mlflow_pyfunc",
                    "risk_score":          round(score * 100, 2),
                }
                _log_to_mlflow(
                    input_hash, score, confidence, status.get("version", "mlflow-registry"),
                    tags={"mode": "mlflow_pyfunc", "session_id": session_id},
                )
                return result
        except Exception as exc:
            logger.warning("MLflow pyfunc prediction failed: %s", exc)

    if model is None:
        # ── Placeholder ──────────────────────────────────────────────────
        score  = round(random.uniform(0.3, 0.7), 4)
        result = {
            "prediction_score":   score,
            "confidence":         0.0,
            "needs_doctor_review": True,
            "model_version":      "placeholder",
            "mode":               "no_model_available",
        }
        _log_to_mlflow(
            input_hash, score, 0.0, "placeholder",
            tags={"mode": "no_model_available", "session_id": session_id},
        )
        return result

    # ── Real TFLite inference ────────────────────────────────────────────
    try:
        import io
        import numpy as np
        from PIL import Image as PILImage

        size = settings.tflite_input_size
        img  = PILImage.open(io.BytesIO(enhanced_image_bytes)).convert("RGB").resize((size, size))
        inp  = np.array(img, dtype=np.float32)[None, ...] / 255.0

        input_details  = model.get_input_details()
        output_details = model.get_output_details()

        model.set_tensor(input_details[0]["index"], inp)
        model.invoke()
        output = model.get_tensor(output_details[0]["index"])

        score      = float(output[0][0])
        confidence = float(max(output[0]))

        result = {
            "prediction_score":   round(score, 4),
            "confidence":         round(confidence, 4),
            "needs_doctor_review": confidence < settings.model_confidence_threshold,
            "model_version":      _active_model_version,
            "mode":               "tflite_inference",
        }
        _log_to_mlflow(
            input_hash, score, confidence, _active_model_version,
            tags={"mode": "tflite_inference", "session_id": session_id},
        )
        return result

    except Exception as exc:
        logger.error("TFLite inference failed: %s — falling back to placeholder", exc)
        score = round(random.uniform(0.3, 0.7), 4)
        _log_to_mlflow(input_hash, score, 0.0, "inference_error")
        return {
            "prediction_score":   score,
            "confidence":         0.0,
            "needs_doctor_review": True,
            "model_version":      _active_model_version,
            "mode":               "inference_error_fallback",
        }
