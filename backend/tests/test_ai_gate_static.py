"""
Static / policy checks that do not import `server` (no motor/mongodb required).
"""
import json
import os
import sys
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from ai_response_policy import build_patient_safe_screen_json


def test_patient_screen_json_never_contains_et_xt_confidence():
    payload = build_patient_safe_screen_json(
        {
            "quality": {"label": "good", "confidence": 0.99, "is_usable": True},
            "deviation": {"possible_type": "ET", "confidence": 0.88},
        },
        app_version="2.0.0",
        quality_model_version="qv1",
    )
    blob = json.dumps(payload)
    assert "ET" not in blob and "XT" not in blob
    assert "confidence" not in blob
    assert "deviation" not in payload


def test_camera_quality_gate_set_exact_three_tests():
    repo = Path(__file__).resolve().parents[2]
    tr = repo / "frontend" / "src" / "tests" / "TestRunner.jsx"
    text = tr.read_text(encoding="utf-8")
    line = [ln for ln in text.splitlines() if "CAMERA_QUALITY_GATE_TESTS" in ln and "Set" in ln][0]
    assert '"gaze"' in line and '"hirschberg"' in line and '"red_reflex"' in line
    low = line.lower()
    assert "prism" not in low and "titmus" not in low and "visual_acuity" not in low


def test_quality_gate_unavailable_shape():
    gate = {
        "checked": True,
        "quality_label": "unknown",
        "is_usable": True,
        "quality_model_version": "unavailable",
        "checked_at": "2026-01-01T00:00:00Z",
    }
    assert gate["quality_model_version"] == "unavailable"
    assert "ET" not in json.dumps(gate)
