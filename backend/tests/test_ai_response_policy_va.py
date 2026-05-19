"""Patient-safe visual acuity detail sanitization."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from ai_response_policy import sanitize_detail_for_patient


def test_va_patient_safe_fields():
    details = {
        "measurement_valid": True,
        "test_status": "completed",
        "measurement_type": "screening_acuity_estimate",
        "calibrated": False,
        "test_distance_cm": 40,
        "notation": "uncalibrated near-screen estimate",
        "inter_eye_lines_diff": 2,
        "od": {"snellen_denominator": 12, "screening_line_label": "~6/12 screening"},
        "os": {"snellen_denominator": 6, "screening_line_label": "~6/6 screening"},
        "leftDisplacementMM": 99,
    }
    out = sanitize_detail_for_patient("visual_acuity", details)
    assert out["od_label"] == "~6/12 screening"
    assert out["os_label"] == "~6/6 screening"
    assert out["inter_eye_lines_diff"] == 2
    assert out["test_distance_cm"] == 40
    assert out["calibrated"] is False
    assert out["measurement_type"] == "screening_acuity_estimate"
    assert "leftDisplacementMM" not in out


def test_titmus_patient_safe_includes_stereo_proxy_metadata():
    out = sanitize_detail_for_patient(
        "titmus",
        {
            "passed": 1,
            "total": 3,
            "measurement_type": "stereo_screening_proxy",
            "stereo_screening_proxy": True,
            "true_stereopsis_test": False,
        },
    )
    assert out["measurement_type"] == "stereo_screening_proxy"
    assert out.get("stereo_screening_proxy") is True
    assert out.get("true_stereopsis_test") is False
