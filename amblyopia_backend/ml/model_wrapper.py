"""
Amblyopia Care System — ML Layer
model_wrapper.py: TFLite model wrapper (thin shim over ml_wrapper_service).
This is the file the ML team replaces when a new model is ready.
"""
from __future__ import annotations

# Re-export everything from the service layer
from app.services.ml_wrapper_service import (  # noqa: F401
    get_active_model,
    predict_amblyopia,
)

__all__ = ["get_active_model", "predict_amblyopia"]
