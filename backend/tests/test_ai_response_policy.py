"""Unit tests for AI response sanitization (no MongoDB required)."""
import os
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from ai_response_policy import (
    _sanitize_patient_finding_text,
    build_patient_safe_screen_json,
    build_patient_safe_strabismus_json,
    cap_patient_strabismus_risk,
    sanitize_detail_for_patient,
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
        "findings": ["No major screening concern on this pass."],
        "medical_findings": [{"test": "X"}],
        "deviation": {"possible_type": "ET"},
    }
    sp = sanitize_prediction_for_patient(pred)
    assert "medical_findings" not in sp
    assert "deviation" not in sp


def test_cap_patient_strabismus_risk_urgent_ai_normal_rules():
    assert cap_patient_strabismus_risk("urgent", "normal") == "mild"
    assert cap_patient_strabismus_risk("urgent", "incomplete") == "mild"
    assert cap_patient_strabismus_risk("urgent", "urgent") == "urgent"


def test_build_patient_safe_strabismus_json_caps_urgent_when_rules_normal():
    out = build_patient_safe_strabismus_json(
        {"risk": "urgent", "model_version": "v1"},
        rule_based_risk_level="normal",
    )
    assert out["risk"] != "urgent"
    assert out["risk"] == "mild"
    assert "reviewed by an eye-care professional" in out["recommendation"].lower()


def test_build_patient_safe_strabismus_json_allows_urgent_when_rules_urgent():
    out = build_patient_safe_strabismus_json(
        {"risk": "urgent", "model_version": "v1"},
        rule_based_risk_level="urgent",
    )
    assert out["risk"] == "urgent"


def test_sanitize_prediction_patient_findings_win_over_findings():
    pred = {
        "risk_level": "normal",
        "findings": ["DOCTOR-ONLY MESSAGE"],
        "patient_findings": ["SAFE PATIENT MESSAGE"],
    }
    sp = sanitize_prediction_for_patient(pred)
    assert sp["findings"] == ["SAFE PATIENT MESSAGE"]
    assert "patient_findings" not in sp
    assert "DOCTOR-ONLY MESSAGE" not in sp["findings"]


def test_sanitize_prediction_incomplete_finding_preserved():
    msg = (
        "Screening session incomplete — some required tests were skipped, "
        "could not be scored, or need to be repeated."
    )
    sp = sanitize_prediction_for_patient({"findings": [msg], "patient_findings": [msg]})
    assert msg in sp["findings"]


def test_sanitize_between_not_blocked_by_et_substring():
    msg = "Screening found a difference between the two eyes."
    assert _sanitize_patient_finding_text(msg) == msg


def test_sanitize_standalone_et_rewritten():
    out = _sanitize_patient_finding_text("AI detected ET pattern")
    assert out is not None
    assert "ET" not in out.split()
    assert "reviewed by an eye-care professional" in out.lower()


def test_sanitize_family_amblyopia_not_inter_eye_alert():
    out = _sanitize_patient_finding_text(
        "Family history of lazy eye (amblyopia) was noted — routine checks important."
    )
    assert out is not None
    assert "difference between the two eyes" not in out.lower()
    assert "family history" in out.lower() or "follow-up" in out.lower()
    assert "amblyopia" not in out.lower()


def test_sanitize_inter_eye_amblyopia_wording():
    out = _sanitize_patient_finding_text(
        "Screening suggests possible amblyopia: 2-line difference between eyes"
    )
    assert out is not None
    assert "difference between the two eyes" in out.lower()
    assert "amblyopia" not in out.lower()


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
    assert "max_gaze_stability_index" not in d
    assert "per_direction" not in d
    assert "screening_status" in d
    assert d["quality_gate"]["quality_label"] == "good"


def test_sanitize_prism_no_numeric_proxy_index():
    out = sanitize_detail_for_patient(
        "prism",
        {"alignment_proxy_index": 12.5, "measurement_type": "alignment_screening_proxy"},
    )
    assert "alignment_proxy_index" not in out
    assert out.get("screening_status")


def test_sanitize_hirschberg_no_displacement_mm_uses_screening_status():
    out = sanitize_detail_for_patient(
        "hirschberg",
        {
            "displacement_mm": 3.5,
            "confidence": "adequate",
            "measurement_type": "hirschberg_alignment_proxy",
        },
    )
    assert "displacement_mm" not in out
    assert "confidence" not in out
    assert out.get("screening_status") == "notable alignment screening signal"


def test_sanitize_hirschberg_low_confidence_repeat():
    out = sanitize_detail_for_patient(
        "hirschberg",
        {"confidence": "low", "displacement_mm": 5.0},
    )
    assert "displacement_mm" not in out
    assert out.get("screening_status") == "repeat screening recommended"


def test_sanitize_gaze_no_numeric_index():
    out = sanitize_detail_for_patient(
        "gaze",
        {"max_gaze_stability_index": 9.2, "measurement_type": "gaze_alignment_proxy"},
    )
    assert "max_gaze_stability_index" not in out
    assert out.get("screening_status")


def test_scrub_patient_submitted_details_removes_deviation():
    bad = {"quality_gate": {"checked": True}, "deviation": {"possible_type": "XT"}}
    clean = scrub_patient_submitted_details(bad)
    assert "deviation" not in clean
    assert clean["quality_gate"]["checked"] is True


def test_classify_risk_runs_without_ai_predictions_collection():
    """Regression: clinical rule engine does not use Keras or ai_deviation_insights."""
    pytest.importorskip("motor")
    from server import classify_risk

    pred = classify_risk([], patient_age=8)
    assert pred["risk_level"] == "incomplete"
    assert pred["clinical_rule_version"]
