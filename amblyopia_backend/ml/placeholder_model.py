"""
Placeholder model — returns deterministic fixed scores based on input hash.
Used during development before real training data is available.
Replace this entire file with a proper TFLite model once Phase 2 data is collected.
"""
from __future__ import annotations

import hashlib
import random


def placeholder_predict(input_hash: str) -> dict:
    """
    Deterministic pseudo-random prediction for consistent test results.
    Ensures same image_hash always returns same score during testing.
    """
    # Seed RNG with hash for determinism
    seed = int(input_hash[:8], 16)
    rng = random.Random(seed)
    score = round(rng.uniform(0.25, 0.75), 4)

    return {
        "prediction_score": score,
        "confidence": 0.0,
        "needs_doctor_review": True,
        "model_version": "placeholder_v0",
        "mode": "placeholder",
    }
