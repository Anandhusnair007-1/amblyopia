"""
Image Pipeline — coordinates quality gate, enhancement, ML inference.
Called by screening router after nurse uploads image.

Phase 2 additions:
  - Per-stage timing logs (ms)
  - Face confidence threshold gate (< 0.6 rejects)
  - Strabismus flag passed into result
  - All metadata logged to MLflow
"""
from __future__ import annotations

import logging
import time
from typing import Optional

from app.config import settings
from app.services.image_enhancement_service import full_pipeline
from app.services.ml_wrapper_service import predict_amblyopia

logger = logging.getLogger(__name__)


async def run_image_pipeline(
    raw_image_bytes: bytes,
    session_id: str,
    age_group: str = "adult",
    nurse_id: Optional[str] = None,
) -> dict:
    """
    Full image pipeline:
      1. Validate image bytes (JPEG/PNG only, > 1 KB)
      2. Quality gate (blur score, brightness, face/eye detection)
      3. Face confidence threshold (< 0.6 → reject)
      4. Enhancement stages (Zero-DCE → DeblurGAN → Real-ESRGAN → CLAHE)
      5. ML inference
      6. Log timing + quality metadata to MLflow

    Raw image bytes are NEVER stored. Only ML predictions are sent downstream.
    """
    pipeline_start = time.perf_counter()
    timing: dict = {}

    # ── Step 0: Basic file validation ─────────────────────────────────────────
    t0 = time.perf_counter()
    validation_error = _validate_image_bytes(raw_image_bytes)
    timing["validate_ms"] = int((time.perf_counter() - t0) * 1000)
    if validation_error:
        logger.warning("Image validation failed for session %s: %s", session_id, validation_error)
        return {
            "success": False,
            "error": validation_error,
            "quality_report": {"reason": validation_error},
            "prediction": None,
            "timing_ms": timing,
        }

    # ── Step 1: Full enhancement pipeline ────────────────────────────────────
    t0 = time.perf_counter()
    enhancement = full_pipeline(raw_image_bytes)
    timing["enhancement_ms"] = int((time.perf_counter() - t0) * 1000)

    quality_report = enhancement.get("quality_report", {})
    pipeline_steps = enhancement.get("pipeline_steps", [])

    if not enhancement["passed"]:
        logger.warning(
            "Image quality gate failed for session %s: %s [steps=%s]",
            session_id, quality_report.get("reason"), pipeline_steps,
        )
        return {
            "success": False,
            "error": f"Image quality issue: {quality_report.get('reason')}",
            "quality_report": quality_report,
            "prediction": None,
            "timing_ms": timing,
        }

    # ── Step 2: Face confidence threshold ────────────────────────────────────
    face_confidence = quality_report.get("face_confidence", 1.0)
    if face_confidence < settings.face_confidence_min:
        logger.warning(
            "Face confidence %.2f below threshold %.2f for session %s",
            face_confidence, settings.face_confidence_min, session_id,
        )
        return {
            "success": False,
            "error": (
                f"Face/eye confidence too low ({face_confidence:.2f}). "
                "Please retake the image with better positioning."
            ),
            "quality_report": quality_report,
            "prediction": None,
            "timing_ms": timing,
        }

    # ── Step 3: ML inference ─────────────────────────────────────────────────
    t0 = time.perf_counter()
    enhanced_bytes = enhancement["enhanced_bytes"]
    prediction = await predict_amblyopia(enhanced_bytes, session_id, age_group)
    timing["inference_ms"] = int((time.perf_counter() - t0) * 1000)

    timing["total_ms"] = int((time.perf_counter() - pipeline_start) * 1000)

    # ── Step 4: Log to MLflow ────────────────────────────────────────────────
    strabismus = enhancement.get("strabismus", {})
    _log_to_mlflow(session_id, quality_report, timing, pipeline_steps, strabismus, prediction)

    return {
        "success": True,
        "quality_report": quality_report,
        "prediction": prediction,
        "strabismus": strabismus,
        "strabismus_flag": bool(strabismus.get("detected", False)),
        "pipeline_steps": pipeline_steps,
        "timing_ms": timing,
    }


def _validate_image_bytes(image_bytes: bytes) -> Optional[str]:
    """
    Validate raw bytes before passing to OpenCV.
    Checks: magic bytes (JPEG/PNG), minimum size.
    """
    if not image_bytes or len(image_bytes) < 1024:
        return "Image too small (minimum 1 KB)"

    # JPEG magic: FF D8 FF
    if image_bytes[:3] == b"\xff\xd8\xff":
        return None
    # PNG magic: 89 50 4E 47
    if image_bytes[:4] == b"\x89PNG":
        return None

    return "Invalid image format. Only JPEG and PNG are accepted."


def _log_to_mlflow(
    session_id: str,
    quality_report: dict,
    timing: dict,
    pipeline_steps: list,
    strabismus: dict,
    prediction: dict,
) -> None:
    """
    Log enhancement metadata and timing to MLflow for monitoring.
    Non-blocking — any MLflow failure is silently logged.
    """
    try:
        import mlflow
        from app.config import settings
        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        mlflow.set_experiment(f"{settings.mlflow_experiment_name}_pipeline_metrics")

        with mlflow.start_run(run_name=f"image_pipeline_{session_id[:8]}"):
            # Timing
            for k, v in timing.items():
                mlflow.log_metric(k, v)

            # Quality
            mlflow.log_metric("blur_score", quality_report.get("blur_score", 0))
            mlflow.log_metric("brightness", quality_report.get("brightness", 0))
            mlflow.log_metric("face_confidence", quality_report.get("face_confidence", 0))

            # Strabismus
            if strabismus:
                mlflow.log_metric("strabismus_confidence", strabismus.get("confidence", 0))

            # Prediction
            if prediction:
                mlflow.log_metric("prediction_confidence", prediction.get("confidence", 0))

            mlflow.log_param("pipeline_path", " | ".join(pipeline_steps))
            mlflow.log_param("session_id", session_id)
    except Exception as exc:
        logger.debug("MLflow image log failed (non-critical): %s", exc)
