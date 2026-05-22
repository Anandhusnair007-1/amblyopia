"""Clinical classifier unit tests — field normalization, completeness, and screening safety."""
import pytest

from clinical_classifier import (
    apply_ai_screening_flag,
    apply_screening_history,
    assess_session_completeness,
    classify_risk,
    classify_titmus_arc_seconds,
    hirschberg_mm_to_proxy_pd,
    hirschberg_predicted_pd,
    hirschberg_zone_label,
    inter_eye_lines_diff,
    is_test_result_usable,
    normalize_hirschberg_displacement_mm,
    normalize_prism_diopters,
)


def _va_result(od_den, os_den, **extra):
    details = {
        "measurement_valid": True,
        "test_status": "completed",
        "measurement_type": "screening_acuity_estimate",
        "calibrated": False,
        "test_distance_cm": 40,
        "od": {
            "snellen_denominator": od_den,
            "snellen_label": f"~6/{od_den} screening",
            "measurement_valid": True,
        },
        "os": {
            "snellen_denominator": os_den,
            "snellen_label": f"~6/{os_den} screening",
            "measurement_valid": True,
        },
        **extra,
    }
    return {
        "test_name": "visual_acuity",
        "raw_score": max(od_den, os_den),
        "normalized_score": 0.5,
        "details": details,
    }


def _full_normal_child_results():
    return [
        _va_result(6, 6),
        {
            "test_name": "gaze",
            "raw_score": 2,
            "normalized_score": 0.05,
            "details": {"max_gaze_stability_index": 2, "measurement_type": "gaze_alignment_proxy"},
        },
        {
            "test_name": "hirschberg",
            "raw_score": 0.5,
            "normalized_score": 0.1,
            "details": {
                "leftDisplacementMM": 0.5,
                "rightDisplacementMM": 0.3,
                "samples": 10,
                "samples_count": 10,
                "confidence": "adequate",
            },
        },
        {
            "test_name": "prism",
            "raw_score": 2,
            "normalized_score": 0.1,
            "details": {"alignment_proxy_index": 2, "measurement_type": "alignment_screening_proxy"},
        },
        {
            "test_name": "titmus",
            "raw_score": 3,
            "normalized_score": 0,
            "details": {"passed": 3, "total": 3, "measurement_type": "stereo_screening_proxy"},
        },
        {"test_name": "red_reflex", "raw_score": 0.05, "normalized_score": 0.05, "details": {"classification": "normal"}},
    ]


def test_hirschberg_alone_not_urgent_without_corroboration():
    results = [
        {
            "test_name": "hirschberg",
            "raw_score": 110,
            "normalized_score": 0.9,
            "details": {
                "leftDisplacementMM": 5.2,
                "rightDisplacementMM": 1.0,
                "samples": 12,
            },
        },
    ]
    pred = classify_risk(results, patient_age=8)
    assert pred["risk_level"] != "urgent"


def test_hirschberg_with_va_corroboration_can_be_urgent():
    results = [
        _va_result(24, 6),
        {
            "test_name": "hirschberg",
            "raw_score": 110,
            "normalized_score": 0.9,
            "details": {"leftDisplacementMM": 5.2, "rightDisplacementMM": 1.0, "samples": 12},
        },
    ]
    pred = classify_risk(results, patient_age=8)
    assert pred["risk_level"] == "urgent"


def test_prism_proxy_alone_not_urgent():
    results = [
        {
            "test_name": "prism",
            "raw_score": 25,
            "normalized_score": 0.9,
            "details": {"alignment_proxy_index": 25, "measurement_type": "alignment_screening_proxy"},
        },
    ]
    pred = classify_risk(results, patient_age=8)
    assert pred["risk_level"] != "urgent"


def test_monocular_va_amblyopia_inter_eye():
    pred = classify_risk([_va_result(24, 6)], patient_age=8)
    assert pred["risk_level"] == "urgent"
    assert not any("possible amblyopia" in f.lower() for f in pred["findings"])
    patient = pred.get("patient_findings") or []
    assert any("difference between the two eyes" in f.lower() for f in patient)
    assert not any("amblyopia" in f.lower() for f in patient)


def test_monocular_va_moderate_inter_eye_only():
    pred = classify_risk([_va_result(12, 6)], patient_age=8)
    assert pred["risk_level"] in ("moderate", "urgent")
    assert inter_eye_lines_diff(12, 6) >= 2


def test_normalize_helpers():
    assert normalize_hirschberg_displacement_mm({"leftDisplacementMM": 3, "rightDisplacementMM": 1}) == 3
    assert normalize_prism_diopters({"estimatedPD": 12}) == 12
    assert normalize_prism_diopters({}, raw_score=8) == 8


def test_all_tests_skipped_incomplete_not_normal():
    results = [
        {
            "test_name": "visual_acuity",
            "raw_score": 0,
            "normalized_score": 0,
            "details": {"skipped": True, "test_status": "skipped"},
        },
        {
            "test_name": "gaze",
            "raw_score": 0,
            "normalized_score": 0,
            "details": {"skipped": True, "test_status": "skipped"},
        },
    ]
    pred = classify_risk(results, patient_age=8)
    assert pred["risk_level"] == "incomplete"
    assert not any("within expected range" in f for f in pred["findings"])


def test_empty_results_incomplete():
    pred = classify_risk([], patient_age=8)
    assert pred["risk_level"] == "incomplete"


def test_red_reflex_media_opacity_high_or_urgent():
    pred = classify_risk([
        {
            "test_name": "red_reflex",
            "raw_score": 0.55,
            "normalized_score": 0.55,
            "details": {"classification": "media_opacity"},
        },
    ], patient_age=1)
    assert pred["risk_level"] in ("moderate", "urgent")
    assert any("red-reflex" in f.lower() or "red reflex" in f.lower() for f in pred["findings"])


def test_red_reflex_indeterminate_session_incomplete():
    pred = classify_risk([
        {
            "test_name": "red_reflex",
            "raw_score": 0.3,
            "normalized_score": 0.3,
            "details": {"classification": "indeterminate", "test_status": "incomplete"},
        },
    ], patient_age=1)
    assert pred["risk_level"] == "incomplete"
    assert pred["session_complete"] is False


def test_hirschberg_no_samples_incomplete():
    pred = classify_risk([
        {
            "test_name": "hirschberg",
            "raw_score": 0,
            "normalized_score": 0,
            "details": {"samples": 0, "note": "no samples", "test_status": "incomplete"},
        },
    ], patient_age=8)
    assert pred["risk_level"] == "incomplete"


def test_hirschberg_no_samples_not_usable():
    row = {
        "test_name": "hirschberg",
        "details": {"samples": 0, "note": "no samples"},
    }
    assert is_test_result_usable(row) is False


def test_pediatric_va_invalid_incomplete():
    pred = classify_risk([
        {
            "test_name": "visual_acuity",
            "raw_score": 0,
            "normalized_score": 0,
            "details": {
                "measurement_valid": False,
                "test_status": "incomplete",
                "reason": "picture_optotype_not_scorable",
            },
        },
    ], patient_age=3)
    assert pred["risk_level"] == "incomplete"
    assert any("could not be scored" in f.lower() for f in pred["findings"])


def test_full_child_session_can_be_normal():
    pred = classify_risk(_full_normal_child_results(), patient_age=8)
    assert pred["risk_level"] == "normal"
    assert pred["session_complete"] is True
    assert any("within expected range" in f for f in pred["findings"])


def test_assess_session_completeness_missing_test():
    ok, issues = assess_session_completeness(
        [{"test_name": "red_reflex", "details": {"classification": "normal"}}],
        patient_age=8,
    )
    assert ok is False
    assert any("missing:" in i for i in issues)


def test_hirschberg_mm_to_proxy_pd_consistent():
    assert hirschberg_mm_to_proxy_pd(2) == 44.0


def test_hirschberg_conversion_method_matches_frontend():
    from clinical_classifier import HIRSCHBERG_CONVERSION_METHOD

    assert HIRSCHBERG_CONVERSION_METHOD == "iris_radius_zone_mapping"


def test_hirschberg_predicted_pd_from_zone():
    assert hirschberg_predicted_pd({"hirschberg_zone": "pupil_edge", "predicted_pd": 15}) == 15
    assert hirschberg_predicted_pd({"hirschberg_zone": "center", "predicted_pd": 0}) == 0
    assert hirschberg_zone_label({"hirschberg_zone": "limbus"}) == "At limbus"


def test_classify_titmus_arc_seconds_bands():
    assert classify_titmus_arc_seconds(50)["label"] == "normal"
    assert classify_titmus_arc_seconds(100)["label"] == "mild_impairment"
    assert classify_titmus_arc_seconds(400)["label"] == "moderate"
    assert classify_titmus_arc_seconds(1000)["label"] == "severe"
    assert classify_titmus_arc_seconds(3000)["label"] == "absence_stereo"


def test_white_pupil_history_urgent():
    pred = classify_risk([], patient_age=8, screening_history={"white_pupil_noticed": True})
    assert pred["risk_level"] == "urgent"


def test_titmus_zero_alone_not_high_in_full_session():
    results = _full_normal_child_results()
    results = [r for r in results if r["test_name"] != "titmus"] + [
        {
            "test_name": "titmus",
            "raw_score": 0,
            "normalized_score": 1,
            "details": {
                "passed": 0,
                "total": 3,
                "arc_seconds": 2500,
                "stereo_grade": "absence_stereo",
                "measurement_type": "stereo_screening_proxy",
            },
        },
    ]
    pred = classify_risk(results, patient_age=8)
    assert pred["risk_level"] not in ("urgent", "moderate")


def test_gaze_proxy_alone_not_urgent():
    pred = classify_risk(
        [
            {
                "test_name": "gaze",
                "raw_score": 25,
                "normalized_score": 0.9,
                "details": {"max_gaze_stability_index": 25},
            },
        ],
        patient_age=8,
    )
    assert pred["risk_level"] != "urgent"


def test_ai_only_sets_review_not_urgent():
    pred = classify_risk(_full_normal_child_results(), patient_age=8)
    out = apply_ai_screening_flag(
        pred,
        {"condition": "ET", "confidence": 0.92, "risk": "urgent"},
    )
    assert out["needs_clinician_review"] is True
    assert out["risk_level"] != "urgent"


def test_ai_flag_adds_patient_safe_review_finding():
    pred = classify_risk(_full_normal_child_results(), patient_age=8)
    out = apply_ai_screening_flag(
        pred,
        {"condition": "ET", "confidence": 0.92, "risk": "urgent"},
    )
    patient = out.get("patient_findings") or []
    assert any("reviewed by an eye-care professional" in f.lower() for f in patient)
    assert not any("ET" in f for f in patient)


def test_ai_flag_skips_patient_review_on_incomplete():
    pred = classify_risk([], patient_age=8)
    out = apply_ai_screening_flag(
        pred,
        {"condition": "ET", "confidence": 0.92, "risk": "urgent"},
    )
    patient = out.get("patient_findings") or []
    assert not any("reviewed by an eye-care professional" in f.lower() for f in patient)


def test_family_history_patient_findings_not_inter_eye():
    pred = classify_risk([], patient_age=8, screening_history={"family_amblyopia": True})
    patient = pred.get("patient_findings") or []
    assert any("family history" in f.lower() or "follow-up" in f.lower() for f in patient)
    assert not any("difference between the two eyes" in f.lower() for f in patient)


def test_apply_screening_history_squint_with_va():
    findings: list = []
    medical: list = []
    u, h, m = apply_screening_history(
        {"squint_noticed": True},
        findings=findings,
        medical_findings=medical,
        has_borderline_va=True,
        has_alignment_proxy_signal=False,
    )
    assert h is True
