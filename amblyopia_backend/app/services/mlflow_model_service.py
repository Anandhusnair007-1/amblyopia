"""
Amblyopia Care System — MLflow Model Registry Service
=====================================================
Manages the production model lifecycle:
  - Registers trained models to staging/production
  - Auto-loads the latest production model at startup
  - Falls back to placeholder model if registry empty
  - Logs AUROC, sensitivity, specificity, confusion matrix

Registered model name: settings.mlflow_model_name
Aliases used:          settings.mlflow_production_alias  (production)
                       settings.mlflow_staging_alias     (staging)
"""
from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Singleton — loaded at startup, used for all predictions
_production_model = None
_production_model_version: Optional[str] = None
_using_fallback = False


# ── Startup warm-up ───────────────────────────────────────────────────────────

async def warm_up_production_model() -> None:
    """
    Called from lifespan startup.
    Tries to load the registered 'production' model from MLflow.
    Falls back gracefully to placeholder if registry is empty or unreachable.
    """
    global _production_model, _production_model_version, _using_fallback

    from app.config import settings

    try:
        import mlflow
        import mlflow.pyfunc

        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        client = mlflow.tracking.MlflowClient()

        # Look for model tagged with production alias
        try:
            model_version = client.get_model_version_by_alias(
                name=settings.mlflow_model_name,
                alias=settings.mlflow_production_alias,
            )
            model_uri = f"models:/{settings.mlflow_model_name}@{settings.mlflow_production_alias}"
            _production_model = mlflow.pyfunc.load_model(model_uri)
            _production_model_version = model_version.version
            _using_fallback = False
            logger.info(
                "MLflow production model loaded: %s v%s",
                settings.mlflow_model_name, model_version.version,
            )
        except Exception as alias_err:
            logger.warning(
                "No production-aliased model found (%s) — trying latest version",
                alias_err,
            )
            # Fallback: load latest version in any stage
            versions = client.search_model_versions(f"name='{settings.mlflow_model_name}'")
            if versions:
                latest = sorted(versions, key=lambda v: int(v.version), reverse=True)[0]
                model_uri = f"models:/{settings.mlflow_model_name}/{latest.version}"
                _production_model = mlflow.pyfunc.load_model(model_uri)
                _production_model_version = latest.version
                _using_fallback = False
                logger.info("MLflow fallback: loaded model version %s", latest.version)
            else:
                raise ValueError("No registered model versions found")

    except Exception as exc:
        logger.warning(
            "MLflow model registry unavailable (%s) — using placeholder predictor", exc
        )
        _production_model = None
        _production_model_version = "placeholder"
        _using_fallback = True


def get_production_model():
    """Return the loaded production model, or None if using fallback."""
    return _production_model


def model_status() -> dict:
    """Return current model registry status for /health endpoint."""
    return {
        "version": _production_model_version,
        "using_fallback": _using_fallback,
        "loaded": _production_model is not None,
    }


# ── Model registration helpers ────────────────────────────────────────────────

def register_trained_model(
    model_path: str,
    val_accuracy: float,
    auroc: float,
    sensitivity: float,
    specificity: float,
    confusion_matrix: list,
    run_id: Optional[str] = None,
) -> Optional[str]:
    """
    Register a trained model to MLflow Model Registry.
    Returns the new version string, or None on failure.

    Called from the Airflow retraining DAG after evaluation.
    """
    from app.config import settings

    try:
        import mlflow
        import mlflow.sklearn

        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        client = mlflow.tracking.MlflowClient()

        with mlflow.start_run(run_id=run_id) as run:
            # Log evaluation metrics
            mlflow.log_metric("val_accuracy", val_accuracy)
            mlflow.log_metric("auroc", auroc)
            mlflow.log_metric("sensitivity", sensitivity)
            mlflow.log_metric("specificity", specificity)

            # Confusion matrix as params (TP, FN, FP, TN)
            if confusion_matrix and len(confusion_matrix) == 4:
                mlflow.log_param("cm_tp", confusion_matrix[0])
                mlflow.log_param("cm_fn", confusion_matrix[1])
                mlflow.log_param("cm_fp", confusion_matrix[2])
                mlflow.log_param("cm_tn", confusion_matrix[3])

            # Log model artifact
            mlflow.log_artifact(model_path, artifact_path="model")
            new_run_id = run.info.run_id

        # Register model version
        result = mlflow.register_model(
            f"runs:/{new_run_id}/model",
            settings.mlflow_model_name,
        )
        version = result.version
        logger.info("Registered model version %s", version)

        # Tag as staging first
        client.set_registered_model_alias(
            name=settings.mlflow_model_name,
            alias=settings.mlflow_staging_alias,
            version=version,
        )
        logger.info("Model v%s tagged as '%s'", version, settings.mlflow_staging_alias)

        return version

    except Exception as exc:
        logger.error("Model registration failed: %s", exc)
        return None


def promote_to_production(version: str, auroc: float) -> bool:
    """
    Promote a staging model to production if AUROC beats threshold.
    Returns True if promoted.
    """
    from app.config import settings

    if auroc < settings.mlflow_min_auroc:
        logger.warning(
            "AUROC %.4f below threshold %.4f — not promoting v%s to production",
            auroc, settings.mlflow_min_auroc, version,
        )
        return False

    try:
        import mlflow
        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        client = mlflow.tracking.MlflowClient()

        client.set_registered_model_alias(
            name=settings.mlflow_model_name,
            alias=settings.mlflow_production_alias,
            version=version,
        )
        logger.info(
            "Model v%s promoted to '%s' (AUROC=%.4f)",
            version, settings.mlflow_production_alias, auroc,
        )
        return True
    except Exception as exc:
        logger.error("Production promotion failed: %s", exc)
        return False
