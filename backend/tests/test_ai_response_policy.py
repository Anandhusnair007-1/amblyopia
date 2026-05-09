"""Unit tests for AI response sanitization (no MongoDB required)."""
import os
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from ai_response_policy import (
    build_patient_safe_screen_json,
    sanitize_prediction_for_patient,
    sanitize_results_for_patient,
    scrub_patient_submitted_details,
)


def test_patient_screen_json_excludes_deviation_and_et_xt():
    full = {
        "quality": {"label": "good", "confidence": 0.99, "is_usable": True},
        "deviation": {"possible_type": "ET", "confidence": 0.9, "score": 0.7},
        "doctor_review_required": True,
    }
    out = build_patient_safe_screen_json(full, app_version="2.0.0", quality_model_version="q1")
    assert "deviation" not in out
    assert "confidence" not in out.get("quality", {})
    s = str(out)
    assert "ET" not in s and "XT" not in s
    assert out["patient_hint"] == "ready"


def test_sanitize_prediction_strips_medical_and_deviation_keys():
    pred = {
        "risk_level": "mild",
        "findings": ["All screening indicators within normal range."],
        "medical_findings": [{"test": "X"}],
        "deviation": {"possible_type": "ET"},
    }
    sp = sanitize_prediction_for_patient(pred)
    assert "medical_findings" not in sp
    assert "deviation" not in sp


def test_sanitize_results_patient_keeps_only_safe_detail_keys_for_gaze():
    rows = [
        {
            "test_name": "gaze",
            "details": {
                "max_deviation_pd": 25,
                "per_direction": {"x": 1},
                "quality_gate": {
                    "checked": True,
                    "quality_label": "good",
                    "is_usable": True,
                    "quality_model_version": "q1",
                    "checked_at": "2026-01-01T00:00:00Z",
                },
            },
        }
    ]
    out = sanitize_results_for_patient(rows)
    d = out[0]["details"]
    assert "max_deviation_pd" not in d
    assert "per_direction" not in d
    assert d["quality_gate"]["quality_label"] == "good"


def test_scrub_patient_submitted_details_removes_deviation():
    bad = {"quality_gate": {"checked": True}, "deviation": {"possible_type": "XT"}}
    clean = scrub_patient_submitted_details(bad)
    assert "deviation" not in clean
    assert clean["quality_gate"]["checked"] is True


def test_classify_risk_runs_without_ai_predictions_collection():
    """Regression: clinical rule engine does not use Keras or ai_deviation_insights."""
    pytest.importorskip("motor")
    from server import classify_risk

    pred = classify_risk([])
    assert pred["risk_level"] == "normal"
    assert pred["clinical_rule_version"]
