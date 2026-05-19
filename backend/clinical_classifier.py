"""Clinical risk classifier — screening thresholds and field normalization."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

_CONSTANTS_PATH = Path(__file__).resolve().parent / "clinical_constants.json"
with open(_CONSTANTS_PATH, encoding="utf-8") as _f:
    CONSTANTS: Dict[str, Any] = json.load(_f)

CLINICAL_RULE_VERSION = CONSTANTS.get("version", "clinical-fallback-v2")
SNELLEN_LINES: List[int] = list(CONSTANTS.get("snellen_line_denominators", [60, 36, 24, 18, 12, 9, 6]))

AGE_TEST_BANDS: List[Dict[str, Any]] = list(
    CONSTANTS.get(
        "age_test_bands",
        [
            {"min": 0, "max": 1, "tests": ["red_reflex"]},
            {"min": 1, "max": 3, "tests": ["red_reflex", "visual_acuity", "gaze"]},
            {
                "min": 3,
                "max": 12,
                "tests": ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex"],
            },
            {
                "min": 13,
                "max": 17,
                "tests": ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex"],
            },
            {"min": 18, "max": 64, "tests": ["visual_acuity", "gaze", "hirschberg", "prism", "titmus"]},
            {"min": 65, "max": 99, "tests": ["visual_acuity", "red_reflex"]},
        ],
    )
)

SCREENING_VA_DISCLAIMER = (
    "Uncalibrated near-screen acuity estimate only; not equivalent to clinic Snellen or cycloplegic refraction."
)


def _num(v: Any, default: float = 0.0) -> float:
    try:
        if v is None:
            return default
        return float(v)
    except (TypeError, ValueError):
        return default


def required_tests_for_age(age_years: Optional[int]) -> List[str]:
    age = 8 if age_years is None else int(age_years)
    for band in AGE_TEST_BANDS:
        if band["min"] <= age <= band["max"]:
            return list(band["tests"])
    return list(AGE_TEST_BANDS[-2]["tests"])


def is_test_result_usable(result: Dict[str, Any]) -> bool:
    """False when a test was skipped, failed capture, or cannot be scored."""
    d = result.get("details") or {}
    state = str(result.get("result_state") or d.get("result_state") or d.get("test_status") or "").lower()
    if state in ("incomplete", "skipped", "unreliable"):
        return False
    if d.get("skipped"):
        return False
    if d.get("test_status") in ("incomplete", "skipped"):
        return False
    if d.get("measurement_valid") is False:
        return False

    name = result.get("test_name")
    if name == "hirschberg":
        if d.get("samples", 1) == 0 or d.get("note") == "no samples":
            return False
    if name == "prism" and d.get("error"):
        return False
    if name == "red_reflex" and (d.get("classification") or "") == "indeterminate":
        return False
    qg = d.get("quality_gate") if isinstance(d.get("quality_gate"), dict) else {}
    if qg and qg.get("is_usable") is False:
        return False
    return True


def assess_session_completeness(
    results: List[Dict[str, Any]],
    patient_age: Optional[int],
) -> Tuple[bool, List[str]]:
    required = required_tests_for_age(patient_age)
    by_name = {r["test_name"]: r for r in results}
    issues: List[str] = []
    for test_id in required:
        row = by_name.get(test_id)
        if not row:
            issues.append(f"missing:{test_id}")
        elif not is_test_result_usable(row):
            issues.append(f"incomplete:{test_id}")
    return (len(issues) == 0, issues)


def snellen_line_index(denominator: float) -> int:
    """Lower index = worse vision. Unknown den maps to worst line."""
    den = int(denominator) if denominator else 60
    for i, d in enumerate(SNELLEN_LINES):
        if den == d:
            return i
    for i, d in enumerate(SNELLEN_LINES):
        if den >= d:
            return i
    return len(SNELLEN_LINES) - 1


def normalize_hirschberg_displacement_mm(details: Dict[str, Any], raw_score: float = 0) -> float:
    d = details or {}
    left = _num(d.get("leftDisplacementMM") or d.get("left_displacement_mm"))
    right = _num(d.get("rightDisplacementMM") or d.get("right_displacement_mm"))
    if left > 0 or right > 0:
        return max(left, right)
    disp = _num(d.get("displacement_mm"))
    if disp > 0:
        return disp
    pd = _num(d.get("estimatedPD"))
    if pd > 0:
        return pd / _num(CONSTANTS.get("hirschberg_pd_per_mm"), 22)
    return _num(raw_score)


def normalize_prism_diopters(details: Dict[str, Any], raw_score: float = 0) -> float:
    d = details or {}
    pd = _num(d.get("max_prism_diopters"))
    if pd > 0:
        return pd
    pd = _num(d.get("estimatedPD"))
    if pd > 0:
        return pd
    return _num(raw_score)


def extract_va_denominators(details: Dict[str, Any]) -> Tuple[Optional[float], Optional[float], Optional[float]]:
    """
    Returns (worse_den, od_den, os_den).
    Legacy binocular: only worse_den set from snellen_denominator.
    """
    d = details or {}
    if d.get("measurement_valid") is False or d.get("test_status") == "incomplete":
        return None, None, None
    od_block = d.get("od") if isinstance(d.get("od"), dict) else {}
    os_block = d.get("os") if isinstance(d.get("os"), dict) else {}
    od = od_block.get("snellen_denominator")
    os = os_block.get("snellen_denominator")
    if od is not None and os is not None:
        if od_block.get("measurement_valid") is False or os_block.get("measurement_valid") is False:
            return None, None, None
        od_f, os_f = _num(od, 6), _num(os, 6)
        worse = max(od_f, os_f)
        return worse, od_f, os_f
    legacy = d.get("snellen_denominator")
    if legacy is not None:
        w = _num(legacy, 6)
        return w, None, None
    return None, None, None


def inter_eye_lines_diff(od_den: float, os_den: float) -> int:
    return abs(snellen_line_index(od_den) - snellen_line_index(os_den))


HIRSCHBERG_PD_PER_MM = _num(CONSTANTS.get("hirschberg_pd_per_mm"), 22)
HIRSCHBERG_MIN_SAMPLES_CONFIDENT = int(CONSTANTS.get("hirschberg_min_samples_confident", 8))
HIRSCHBERG_CONVERSION_METHOD = str(
    CONSTANTS.get("hirschberg_conversion_method", "max_displacement_mm_times_pd_per_mm")
)


def hirschberg_mm_to_proxy_pd(mm: float) -> float:
    """Consistent Hirschberg screening conversion (matches frontend storage)."""
    return mm * HIRSCHBERG_PD_PER_MM


def _gaze_proxy_index(details: Dict[str, Any]) -> float:
    d = details or {}
    return _num(d.get("max_gaze_stability_index") or d.get("max_deviation_pd"))


def _alignment_proxy_index(details: Dict[str, Any], raw_score: float = 0) -> float:
    d = details or {}
    return _num(d.get("alignment_proxy_index") or d.get("estimatedPD") or d.get("max_prism_diopters") or raw_score)


def apply_screening_history(
    history: Optional[Dict[str, Any]],
    *,
    findings: List[str],
    medical_findings: List[Dict[str, Any]],
    has_borderline_va: bool,
    has_alignment_proxy_signal: bool,
) -> Tuple[bool, bool, bool]:
    """Conservative history modifiers — screening context only, not diagnosis."""
    if not history or not isinstance(history, dict):
        return False, False, False
    urgent, high, mild = False, False, False

    if history.get("white_pupil_noticed"):
        urgent = True
        findings.append(
            "You reported a white or unusual pupil glow — please consult an eye-care professional promptly "
            "for an in-person examination."
        )
        medical_findings.append({
            "test": "Screening History",
            "metric": "white_pupil_noticed",
            "value": "yes",
            "threshold": "Any reported leukocoria sign",
            "interpretation": "Reported pupil glow concern — urgent in-person screening follow-up advised.",
            "severity": "urgent",
        })

    if history.get("squint_noticed") and (has_borderline_va or has_alignment_proxy_signal):
        high = True
        findings.append(
            "You reported an eye turn and the screening showed possible alignment or vision concerns — "
            "please schedule an eye-care visit."
        )
        medical_findings.append({
            "test": "Screening History",
            "metric": "squint_noticed",
            "value": "yes",
            "threshold": "History + borderline screening",
            "interpretation": "Reported squint with corroborating screening signals — clinical exam advised.",
            "severity": "high",
        })
    elif history.get("squint_noticed"):
        mild = True
        findings.append(
            "You reported an eye turn — mention this at your next eye-care visit even if screening looked OK."
        )
        medical_findings.append({
            "test": "Screening History",
            "metric": "squint_noticed",
            "value": "yes",
            "threshold": "History only",
            "interpretation": "Reported squint — confirm with in-person alignment testing.",
            "severity": "mild",
        })

    if history.get("family_amblyopia"):
        mild = True
        findings.append(
            "Family history of lazy eye (amblyopia) was noted — routine in-person eye checks are especially important."
        )
        medical_findings.append({
            "test": "Screening History",
            "metric": "family_amblyopia",
            "value": "yes",
            "threshold": "Risk modifier",
            "interpretation": "Family history — not a diagnosis; supports closer follow-up.",
            "severity": "mild",
        })

    if history.get("patching_before"):
        mild = True
        medical_findings.append({
            "test": "Screening History",
            "metric": "patching_before",
            "value": "yes",
            "threshold": "Context",
            "interpretation": "Prior patching reported — share with clinician; does not change automated risk alone.",
            "severity": "mild",
        })

    return urgent, high, mild


def apply_ai_screening_flag(
    pred: Dict[str, Any],
    ai_insight: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    """
    AI may flag clinician review only. Never set urgent from AI without rule-based corroboration.
    """
    try:
        from ai_response_policy import PATIENT_AI_REVIEW_FINDING
    except ImportError:
        from backend.ai_response_policy import PATIENT_AI_REVIEW_FINDING

    out = dict(pred)
    if not ai_insight or ai_insight.get("condition") in (None, "Normal"):
        return out

    conf = float(ai_insight.get("confidence") or 0)
    out["ai_screening_flag"] = True
    out["needs_clinician_review"] = True

    rule_level = str(out.get("risk_level") or "normal")
    rule_urgent_or_high = rule_level in ("urgent", "moderate")

    findings = list(out.get("findings") or [])
    findings.append(
        "AI-assisted camera screening flagged a possible alignment pattern for clinician review "
        f"(screening confidence {conf * 100:.0f}%). This is not a diagnosis."
    )
    out["findings"] = findings

    medical = list(out.get("medical_findings") or [])
    medical.append({
        "test": "AI Strabismus Screening",
        "metric": "condition",
        "value": str(ai_insight.get("condition") or "unknown"),
        "threshold": "Screening AI output",
        "interpretation": (
            "AI screening output for doctor review only. Confirm with clinical examination."
        ),
        "severity": "moderate" if rule_urgent_or_high else "mild",
    })
    out["medical_findings"] = medical

    if rule_level == "urgent":
        pass
    elif rule_level == "moderate":
        pass
    elif rule_level in ("normal", "mild", "incomplete"):
        if rule_level == "normal":
            out["risk_level"] = "mild"
            out["risk_score"] = max(_num(out.get("risk_score"), 0.1), 0.4)
            out["health_score"] = round((1 - out["risk_score"]) * 100, 1)

    patient_findings = list(out.get("patient_findings") or [])
    if rule_level != "incomplete":
        if PATIENT_AI_REVIEW_FINDING not in patient_findings:
            patient_findings.append(PATIENT_AI_REVIEW_FINDING)
    out["patient_findings"] = patient_findings

    return out


def classify_risk(
    results: List[Dict[str, Any]],
    *,
    patient_age: Optional[int] = None,
    screening_history: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    by_name = {r["test_name"]: r for r in results}
    findings: List[str] = []
    medical_findings: List[Dict[str, Any]] = []
    rule_urgent, rule_high, rule_mild = False, False, False
    proxy_high_signal, proxy_mild_signal = False, False
    has_borderline_va = False
    has_alignment_proxy_signal = False

    session_complete, completeness_issues = assess_session_completeness(results, patient_age)
    session_incomplete = not session_complete or not results

    rr = by_name.get("red_reflex")
    if rr:
        cls = (rr.get("details") or {}).get("classification", "")
        rr_details = rr.get("details") or {}
        rr_qg = rr_details.get("quality_gate") if isinstance(rr_details.get("quality_gate"), dict) else {}
        if rr_qg and rr_qg.get("is_usable") is False:
            findings.append(
                "Urgent eye-care review recommended because the red-reflex image quality was not reliable enough "
                "for safe screening."
            )
            medical_findings.append({
                "test": "Red Reflex",
                "metric": "quality_gate",
                "value": rr_qg.get("quality_label", "unusable"),
                "threshold": "Reliable image quality required",
                "interpretation": "Suspicious or unusable image quality on red-reflex screening — urgent review advised.",
                "severity": "urgent",
            })
            rule_urgent = True
        if cls in ("leukocoria", "white"):
            findings.append(
                "Urgent eye-care review recommended."
            )
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": cls,
                "threshold": "Expected: symmetric red/orange reflex on screening",
                "interpretation": "Abnormal reflex pattern on screening — specialist review advised.",
                "severity": "urgent",
            })
            rule_urgent = True
        elif cls == "absent":
            findings.append(
                "Urgent eye-care review recommended."
            )
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": "absent",
                "threshold": "Expected: visible red/orange reflex",
                "interpretation": "Absent reflex on screening — specialist review advised.",
                "severity": "urgent",
            })
            rule_urgent = True
        elif cls == "media_opacity":
            findings.append(
                "Screening detected an abnormal or unclear red-reflex result; "
                "please consult an eye-care professional."
            )
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": "media_opacity",
                "threshold": "Expected: symmetric red/orange reflex",
                "interpretation": "Abnormal reflex pattern on screening — further evaluation advised.",
                "severity": "high",
            })
            rule_high = True
        elif cls == "dim":
            findings.append("Dim red reflex on screening — further evaluation recommended.")
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": "dim",
                "threshold": "Expected: bright red/orange on screening",
                "interpretation": "Subtle reflex change on screening — clinical exam advised.",
                "severity": "moderate",
            })
            rule_high = True
        elif cls == "indeterminate":
            findings.append(
                "Red-reflex screening was unclear — please repeat in better lighting "
                "or see an eye-care professional."
            )
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": "indeterminate",
                "threshold": "Clear reflex required for screening",
                "interpretation": "Repeat screening or in-person red-reflex check advised.",
                "severity": "incomplete",
            })

    gz = by_name.get("gaze")
    if gz and is_test_result_usable(gz):
        gzd = gz.get("details") or {}
        dev = _gaze_proxy_index(gzd)
        has_alignment_proxy_signal = has_alignment_proxy_signal or dev > CONSTANTS["gaze_mild_pd"]
        if dev > CONSTANTS["gaze_urgent_pd"]:
            proxy_high_signal = True
            findings.append(
                "Gaze alignment screening proxy suggests a large stability concern — "
                "confirm with an in-person eye exam."
            )
            medical_findings.append({
                "test": "Gaze Alignment Proxy",
                "metric": "max_gaze_stability_index",
                "value": f"{dev:.2f}",
                "threshold": "Uncalibrated proxy only",
                "interpretation": "Weak gaze-stability signal — not a prism diopter measurement.",
                "severity": "moderate",
            })
        elif dev > CONSTANTS["gaze_moderate_pd"]:
            proxy_high_signal = True
            findings.append("Gaze alignment screening proxy shows a moderate concern — confirm in clinic.")
            medical_findings.append({
                "test": "Gaze Alignment Proxy",
                "metric": "max_gaze_stability_index",
                "value": f"{dev:.2f}",
                "threshold": "Uncalibrated proxy only",
                "interpretation": "Moderate gaze-stability proxy — clinical alignment test advised.",
                "severity": "mild",
            })
        elif dev > CONSTANTS["gaze_mild_pd"]:
            proxy_mild_signal = True
            medical_findings.append({
                "test": "Gaze Alignment Proxy",
                "metric": "max_gaze_stability_index",
                "value": f"{dev:.2f}",
                "threshold": "Uncalibrated proxy only",
                "interpretation": "Mild gaze-stability proxy.",
                "severity": "mild",
            })

    hb = by_name.get("hirschberg")
    if hb and is_test_result_usable(hb):
        hbd = hb.get("details") or {}
        disp = normalize_hirschberg_displacement_mm(hbd, _num(hb.get("raw_score")))
        samples_n = int(hbd.get("samples") or hbd.get("samples_count") or 0)
        confident = samples_n >= HIRSCHBERG_MIN_SAMPLES_CONFIDENT
        proxy_pd = hirschberg_mm_to_proxy_pd(disp)
        has_alignment_proxy_signal = has_alignment_proxy_signal or disp > CONSTANTS["hirschberg_moderate_mm"]
        pd_display = f"{proxy_pd:.1f}" if confident else "low confidence"
        if disp > CONSTANTS["hirschberg_urgent_mm"]:
            proxy_high_signal = True
            findings.append(
                "Corneal reflex screening proxy shows marked asymmetry — confirm with an in-person exam."
            )
            medical_findings.append({
                "test": "Hirschberg Proxy",
                "metric": "displacement_mm",
                "value": f"{disp:.1f} mm (proxy index {pd_display})",
                "threshold": f"Screening proxy; {HIRSCHBERG_CONVERSION_METHOD}",
                "interpretation": (
                    f"Conversion {HIRSCHBERG_PD_PER_MM} per mm; samples={samples_n}. "
                    "Not a calibrated prism measurement."
                ),
                "severity": "moderate",
            })
        elif disp > CONSTANTS["hirschberg_moderate_mm"]:
            proxy_mild_signal = True
            findings.append("Mild corneal reflex asymmetry on screening proxy.")
            medical_findings.append({
                "test": "Hirschberg Proxy",
                "metric": "displacement_mm",
                "value": f"{disp:.1f} mm",
                "threshold": "Screening proxy",
                "interpretation": f"pd_per_mm={HIRSCHBERG_PD_PER_MM}; samples={samples_n}.",
                "severity": "mild",
            })

    va = by_name.get("visual_acuity")
    if va:
        details = va.get("details") or {}
        if not is_test_result_usable(va):
            findings.append(
                "Visual acuity could not be scored on this device — "
                "in-person acuity testing with an eye-care professional is advised."
            )
            medical_findings.append({
                "test": "Visual Acuity",
                "metric": "measurement_valid",
                "value": "false",
                "threshold": "Valid near-screen estimate",
                "interpretation": details.get("reason") or "Acuity screening incomplete or unscorable.",
                "severity": "incomplete",
            })
        else:
            worse, od_den, os_den = extract_va_denominators(details)
            amblyopia_lines = CONSTANTS.get("amblyopia_inter_eye_lines_min", 2)
            va_urgent = CONSTANTS.get("va_urgent_denominator_min", 24)
            va_moderate = CONSTANTS.get("va_moderate_denominator_min", 12)
            dist_cm = details.get("test_distance_cm", details.get("distance_cm", 40))

            if od_den is not None and os_den is not None:
                lines_diff = inter_eye_lines_diff(od_den, os_den)
                worse_eye = "OD" if od_den >= os_den else "OS"
                od_label = details.get("od", {}).get("screening_line_label") or details.get("od", {}).get(
                    "snellen_label"
                ) or f"~6/{int(od_den)}"
                os_label = details.get("os", {}).get("screening_line_label") or details.get("os", {}).get(
                    "snellen_label"
                ) or f"~6/{int(os_den)}"
                medical_findings.append({
                    "test": "Visual Acuity",
                    "metric": "screening_acuity_estimate",
                    "value": f"OD {od_label}, OS {os_label}",
                    "threshold": "Screening only; not clinic Snellen",
                    "interpretation": (
                        f"{SCREENING_VA_DISCLAIMER} Distance ~{dist_cm} cm. "
                        f"Inter-eye difference: {lines_diff} line(s); worse eye: {worse_eye}."
                    ),
                    "severity": "normal",
                })
                if lines_diff >= amblyopia_lines:
                    findings.append(
                        f"Inter-eye acuity difference on screening ({lines_diff} line(s), "
                        f"{od_label} vs {os_label}) — clinical confirmation needed."
                    )
                    medical_findings.append({
                        "test": "Visual Acuity",
                        "metric": "inter_eye_lines_diff",
                        "value": str(lines_diff),
                        "threshold": f"Screening: < {amblyopia_lines} lines between eyes",
                        "interpretation": "Inter-eye acuity difference on screening — clinical confirmation needed.",
                        "severity": "moderate" if worse < va_urgent else "urgent",
                    })
                    has_borderline_va = True
                    if worse >= va_urgent:
                        rule_urgent = True
                    else:
                        rule_high = True
                if worse >= va_urgent:
                    findings.append(
                        f"Reduced vision on screening in worse eye (~6/{int(worse)}) — "
                        "confirm with an eye-care professional."
                    )
                    medical_findings.append({
                        "test": "Visual Acuity",
                        "metric": "worse_eye_screening_estimate",
                        "value": f"~6/{int(worse)}",
                        "threshold": "Screening estimate only",
                        "interpretation": SCREENING_VA_DISCLAIMER,
                        "severity": "urgent",
                    })
                    rule_urgent = True
                    has_borderline_va = True
                elif worse >= va_moderate and lines_diff < amblyopia_lines:
                    medical_findings.append({
                        "test": "Visual Acuity",
                        "metric": "worse_eye_screening_estimate",
                        "value": f"~6/{int(worse)}",
                        "threshold": "Screening estimate only",
                        "interpretation": "Below-target screening acuity — refractive assessment advised.",
                        "severity": "moderate",
                    })
                    rule_high = True
                    has_borderline_va = True
                    findings.append(
                        f"Vision below target on screening in worse eye (~6/{int(worse)}) — "
                        "confirm with an eye-care professional."
                    )
            elif worse is not None:
                den = worse
                if den >= va_urgent:
                    findings.append(
                        f"Reduced vision on screening (~6/{int(den)}) — "
                        "confirm with an eye-care professional."
                    )
                    medical_findings.append({
                        "test": "Visual Acuity",
                        "metric": "screening_acuity_estimate",
                        "value": f"~6/{int(den)}",
                        "threshold": "Screening estimate only",
                        "interpretation": SCREENING_VA_DISCLAIMER,
                        "severity": "urgent",
                    })
                    rule_urgent = True
                    has_borderline_va = True
                elif den >= va_moderate:
                    medical_findings.append({
                        "test": "Visual Acuity",
                        "metric": "screening_acuity_estimate",
                        "value": f"~6/{int(den)}",
                        "threshold": "Screening estimate only",
                        "interpretation": "Below-target screening acuity — clinical exam advised.",
                        "severity": "moderate",
                    })
                    rule_high = True
                    has_borderline_va = True
                    findings.append(
                        f"Vision below target on screening (~6/{int(den)}) — "
                        "confirm with an eye-care professional."
                    )

    ts = by_name.get("titmus")
    if ts and is_test_result_usable(ts):
        passed = (ts.get("details") or {}).get("passed", 0)
        total = (ts.get("details") or {}).get("total", 3)
        if passed == 0:
            proxy_mild_signal = True
            findings.append(
                "Stereo depth screening proxy showed no depth cues — "
                "confirm with an in-person stereo test if clinically indicated."
            )
            medical_findings.append({
                "test": "Stereo Screening Proxy",
                "metric": "passed",
                "value": f"{passed}/{total}",
                "threshold": "Not a validated Titmus test",
                "interpretation": "Self-reported / on-screen proxy only — cannot rule out poor stereopsis alone.",
                "severity": "mild",
            })
        elif passed < total:
            proxy_mild_signal = True
            medical_findings.append({
                "test": "Stereo Screening Proxy",
                "metric": "passed",
                "value": f"{passed}/{total}",
                "threshold": "Proxy only",
                "interpretation": "Partial responses on stereo screening proxy.",
                "severity": "mild",
            })

    pr = by_name.get("prism")
    if pr and is_test_result_usable(pr):
        pd = _alignment_proxy_index(pr.get("details") or {}, _num(pr.get("raw_score")))
        has_alignment_proxy_signal = has_alignment_proxy_signal or pd > CONSTANTS["prism_mild_pd"]
        if pd > CONSTANTS["prism_urgent_pd"]:
            proxy_high_signal = True
            findings.append(
                "Alignment screening proxy suggests a large shift — "
                "occlusion was not verified; confirm with an in-person cover test."
            )
        elif pd > CONSTANTS["prism_moderate_pd"]:
            proxy_high_signal = True
        elif pd > CONSTANTS["prism_mild_pd"]:
            proxy_mild_signal = True
        medical_findings.append({
            "test": "Alignment Screening Proxy",
            "metric": "alignment_proxy_index",
            "value": f"{pd:.2f}",
            "threshold": "Uncalibrated; occlusion not verified",
            "interpretation": "Cover-test proxy only — not a clinical prism cover test.",
            "severity": (
                "mild" if pd > CONSTANTS["prism_mild_pd"] else "normal"
            ),
        })

    hist_u, hist_h, hist_m = apply_screening_history(
        screening_history,
        findings=findings,
        medical_findings=medical_findings,
        has_borderline_va=has_borderline_va,
        has_alignment_proxy_signal=has_alignment_proxy_signal,
    )
    rule_urgent = rule_urgent or hist_u
    rule_high = rule_high or hist_h
    rule_mild = rule_mild or hist_m

    if proxy_high_signal and (rule_urgent or rule_high):
        rule_high = True
    elif proxy_high_signal:
        rule_mild = True
        findings.append(
            "Alignment or gaze screening proxies were notable — "
            "an in-person exam is recommended to confirm."
        )
    elif proxy_mild_signal:
        rule_mild = True

    if session_incomplete:
        findings.append(
            "Screening session incomplete — some required tests were skipped, "
            "could not be scored, or need to be repeated."
        )

    if any(str((r.get("result_state") or (r.get("details") or {}).get("result_state") or "")).lower() in ("unreliable", "needs_review", "urgent_review") for r in results):
        findings.append("One or more screening results need doctor review before they can be considered reliable.")
        if not rule_urgent and not rule_high:
            rule_mild = True

    if rule_urgent:
        level, score = "urgent", 0.95
    elif rule_high:
        level, score = "moderate", 0.70
    elif rule_mild:
        level, score = "mild", 0.40
    elif session_incomplete:
        level, score = "incomplete", 0.25
    else:
        level, score = "normal", 0.10

    health = round((1 - score) * 100, 1)
    if not findings and level == "normal":
        findings.append("All completed screening indicators were within expected range on this pass.")

    patient_findings: List[str] = []
    for f in findings:
        fl = f.lower()
        if "inter-eye acuity difference" in fl:
            msg = (
                "Screening found a difference between the two eyes. "
                "Please confirm with an eye-care professional."
            )
            if msg not in patient_findings:
                patient_findings.append(msg)
        elif "family history" in fl or ("family" in fl and ("amblyopia" in fl or "lazy eye" in fl)):
            msg = (
                "Family history may increase the need for routine eye-care follow-up."
            )
            if msg not in patient_findings:
                patient_findings.append(msg)
        elif "amblyopia" not in fl and "lazy eye" not in fl:
            patient_findings.append(f)

    return {
        "risk_level": level,
        "risk_score": round(score, 3),
        "health_score": health,
        "findings": findings,
        "patient_findings": patient_findings,
        "medical_findings": medical_findings,
        "clinical_rule_version": CLINICAL_RULE_VERSION,
        "test_algorithm_version": "ambyo-core-2.2",
        "session_complete": session_complete,
        "completeness_issues": completeness_issues,
    }
