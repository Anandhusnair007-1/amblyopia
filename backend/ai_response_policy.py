"""
Patient vs doctor visibility for AI-assisted screening responses.
Pure functions — no I/O.
"""
from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

_STRABISMUS_CODE_RE = re.compile(
    r"\b(ET|XT|HT|esotropia|exotropia|hypertropia)\b",
    re.IGNORECASE,
)

PATIENT_INTER_EYE_SCREENING_MSG = (
    "Screening found a difference between the two eyes. "
    "Please confirm with an eye-care professional."
)
PATIENT_FAMILY_HISTORY_MSG = (
    "Family history may increase the need for routine eye-care follow-up."
)
PATIENT_AI_REVIEW_FINDING = (
    "AI screening output suggests this result should be reviewed by an eye-care professional."
)

# Keys never returned to patients on session GET (prediction document)
PATIENT_PREDICTION_STRIP = frozenset({
    "medical_findings",
    "confidence",
    "score",
    "possible_type",
    "deviation",
    "ai_deviation",
    "deviation_model_confidence",
    "quality_confidence",
})

# Form fields a patient must not inject into stored results
PATIENT_FORBIDDEN_DETAIL_ROOT_KEYS = frozenset({
    "deviation",
    "ai_deviation",
    "possible_type",
    "model_confidence",
    "prism_diagnosis",
})


def quality_label_to_patient_hint(label: Optional[str], is_usable: bool) -> str:
    """Map model quality label to a patient-safe action key (no medical jargon)."""
    if is_usable:
        return "ready"
    m = {
        "dark": "improve_lighting",
        "blurred": "hold_steady",
        "bad_crop": "center_face",
        "reflection_issue": "hold_steady",
        "unknown": "retake_image",
        "good": "retake_image",
    }
    return m.get((label or "").lower(), "retake_image")


def build_patient_safe_screen_json(
    full: Dict[str, Any],
    *,
    app_version: str,
    quality_model_version: str,
) -> Dict[str, Any]:
    """
    Response body for POST /api/ai/screen-quality when caller is a patient.
    Must not include deviation, ET/XT, or confidence scores.
    """
    q = full.get("quality") or {}
    label = q.get("label") or "unknown"
    is_usable = bool(q.get("is_usable"))
    return {
        "quality": {
            "label": label,
            "is_usable": is_usable,
        },
        "patient_hint": quality_label_to_patient_hint(label, is_usable),
        "disclaimer": (
            "This camera check helps improve screening quality. "
            "It is not a diagnosis."
        ),
        "app_version": app_version,
        "quality_model_version": quality_model_version,
    }


def build_doctor_safe_screen_json(full: Dict[str, Any]) -> Dict[str, Any]:
    """Full AI engine output for doctors (includes deviation when present)."""
    return dict(full)


PATIENT_AI_REVIEW_ONLY = (
    "AI screening output suggests this should be reviewed by an eye-care professional."
)


def cap_patient_strabismus_risk(
    ai_risk: Optional[str],
    rule_based_risk_level: Optional[str],
) -> str:
    """
    Patient-facing AI risk must not exceed rule-based corroboration.
    Urgent AI alone cannot surface as urgent to patients.
    """
    ai = str(ai_risk or "normal").lower()
    rule = str(rule_based_risk_level or "normal").lower()
    if rule == "urgent":
        if ai in ("urgent", "moderate"):
            return ai
        return "mild"
    if rule == "moderate":
        if ai in ("moderate", "mild"):
            return "mild"
        return "mild" if ai in ("urgent", "moderate") else ai
    # normal, mild, incomplete
    if ai in ("urgent", "moderate"):
        return "mild"
    return ai if ai in ("normal", "mild") else "mild"


def build_patient_safe_strabismus_json(
    full: Dict[str, Any],
    *,
    rule_based_risk_level: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Response body for POST /api/ai/analyze-strabismus when caller is a patient.
    Omits condition, confidence, and class scores; risk + plain-language guidance only.
    """
    confidence = full.get("confidence")
    try:
        confidence_f = float(confidence)
    except (TypeError, ValueError):
        confidence_f = 0.0
    rule = str(rule_based_risk_level or "normal").lower()
    uncertain = confidence is not None and confidence_f < 0.65
    ai_raw = "mild" if uncertain and rule != "urgent" else (full.get("risk") or "normal")
    risk_key = cap_patient_strabismus_risk(ai_raw, rule_based_risk_level)
    if risk_key == "urgent" and rule == "urgent":
        recommendation = (
            "Important screening findings detected. Please see an eye doctor as soon as possible."
        )
    elif uncertain:
        recommendation = PATIENT_AI_REVIEW_ONLY
    elif risk_key == "normal":
        recommendation = "No major screening concern on this pass. Continue regular eye check-ups."
    else:
        recommendation = PATIENT_AI_REVIEW_ONLY
    return {
        "screening_complete": True,
        "risk": risk_key,
        "uncertain": uncertain,
        "recommendation": recommendation,
        "disclaimer": (
            "This is an AI-assisted screening tool. It is not a medical diagnosis."
        ),
        "model_version": full.get("model_version") or "",
    }


def _sanitize_patient_finding_text(text: str) -> Optional[str]:
    s = str(text).strip()
    if not s:
        return None
    if _STRABISMUS_CODE_RE.search(s):
        return PATIENT_AI_REVIEW_FINDING
    low = s.lower()
    if "family history" in low or ("family" in low and ("amblyopia" in low or "lazy eye" in low)):
        return PATIENT_FAMILY_HISTORY_MSG
    if (
        "inter-eye" in low
        or "inter eye" in low
        or "possible amblyopia" in low
        or ("line(s)" in low and ("difference" in low or "acuity" in low))
        or ("amblyopia" in low and "difference" in low)
    ):
        return PATIENT_INTER_EYE_SCREENING_MSG
    if "amblyopia" in low or "lazy eye" in low:
        return PATIENT_FAMILY_HISTORY_MSG
    return s


def sanitize_prediction_for_patient(pred: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not pred:
        return pred
    out = {k: v for k, v in pred.items() if k not in PATIENT_PREDICTION_STRIP}
    raw_findings = pred.get("patient_findings")
    if not isinstance(raw_findings, list) or len(raw_findings) == 0:
        raw_findings = pred.get("findings")
    out.pop("patient_findings", None)
    if isinstance(raw_findings, list):
        cleaned: List[str] = []
        for f in raw_findings:
            safe = _sanitize_patient_finding_text(f)
            if safe and safe not in cleaned:
                cleaned.append(safe)
        out["findings"] = cleaned
    return out


def sanitize_detail_for_patient(test_name: str, details: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Patient-facing test result details: quality gate + minimal non-clinical summary.
    Raw gaze/Hirschberg/prism/red-reflex measurements are omitted from API (stored in DB for clinical rules).
    """
    if not details:
        return {}
    if details.get("skipped"):
        return {"skipped": True}

    out: Dict[str, Any] = {}
    qg = details.get("quality_gate")
    if isinstance(qg, dict):
        out["quality_gate"] = {
            k: qg[k]
            for k in ("checked", "quality_label", "is_usable", "quality_model_version", "checked_at")
            if k in qg
        }

    if test_name == "visual_acuity":
        if details.get("skipped"):
            return {"skipped": True, "test_status": details.get("test_status", "skipped")}
        if details.get("test_status"):
            out["test_status"] = details["test_status"]
        if details.get("measurement_valid") is False:
            out["measurement_valid"] = False
            return out
        od = details.get("od") if isinstance(details.get("od"), dict) else {}
        os = details.get("os") if isinstance(details.get("os"), dict) else {}
        out["od_label"] = (
            od.get("screening_line_label")
            or od.get("snellen_label")
            or (f"~6/{od['snellen_denominator']} screening" if od.get("snellen_denominator") else None)
        )
        out["os_label"] = (
            os.get("screening_line_label")
            or os.get("snellen_label")
            or (f"~6/{os['snellen_denominator']} screening" if os.get("snellen_denominator") else None)
        )
        if details.get("inter_eye_lines_diff") is not None:
            out["inter_eye_lines_diff"] = details["inter_eye_lines_diff"]
        if details.get("test_distance_cm") is not None:
            out["test_distance_cm"] = details["test_distance_cm"]
        if "calibrated" in details:
            out["calibrated"] = details["calibrated"]
        if details.get("measurement_type"):
            out["measurement_type"] = details["measurement_type"]
        out["notation_disclaimer"] = details.get("notation") or (
            "uncalibrated near-screen estimate; not equivalent to clinic Snellen"
        )
        if details.get("measurement_valid") is True:
            out["measurement_valid"] = True
        return out

    if test_name == "gaze":
        gsi = details.get("max_gaze_stability_index")
        out["measurement_type"] = details.get("measurement_type", "gaze_alignment_proxy")
        if gsi is not None:
            g = float(gsi)
            if g >= 15:
                out["screening_status"] = "needs review"
            elif g >= 8:
                out["screening_status"] = "notable alignment screening signal"
            else:
                out["screening_status"] = "within screening range"
        else:
            out["screening_status"] = "not assessable"
        return out

    if test_name == "prism":
        out["measurement_type"] = details.get("measurement_type", "alignment_screening_proxy")
        out["occlusion_verified"] = details.get("occlusion_verified", False)
        idx = details.get("alignment_proxy_index")
        if idx is not None:
            p = float(idx)
            if p >= 15:
                out["screening_status"] = "needs review"
            elif p >= 5:
                out["screening_status"] = "notable alignment screening signal"
            else:
                out["screening_status"] = "within screening range"
        else:
            out["screening_status"] = "not assessable"
        return out

    if test_name == "titmus":
        out["passed"] = details.get("passed")
        out["total"] = details.get("total")
        out["measurement_type"] = details.get("measurement_type", "stereo_screening_proxy")
        out["stereo_screening_proxy"] = details.get("stereo_screening_proxy", True)
        out["true_stereopsis_test"] = details.get("true_stereopsis_test", False)
        if details.get("test_status"):
            out["test_status"] = details["test_status"]
        return out

    if test_name == "hirschberg":
        out["measurement_type"] = details.get("measurement_type", "hirschberg_alignment_proxy")
        if details.get("test_status") == "incomplete":
            out["test_status"] = "incomplete"
            out["measurement_valid"] = False
            out["screening_status"] = "not assessable"
        elif details.get("confidence") == "low":
            out["measurement_valid"] = False
            out["note"] = "low_sample_count"
            out["screening_status"] = "repeat screening recommended"
        else:
            mm = details.get("displacement_mm")
            if mm is not None:
                m = float(mm)
                if m >= 4:
                    out["screening_status"] = "needs review"
                elif m >= 2:
                    out["screening_status"] = "notable alignment screening signal"
                else:
                    out["screening_status"] = "within screening range"
            else:
                out["screening_status"] = "recorded"
            out["measurement_valid"] = True
        return out

    if test_name == "red_reflex":
        cls = str(details.get("classification") or "").lower()
        out["measurement_type"] = details.get("measurement_type", "red_reflex_screening")
        if cls in ("leukocoria", "white", "absent", "media_opacity"):
            out["screening_status"] = "urgent eye-care review recommended"
        elif cls in ("dim", "indeterminate"):
            out["screening_status"] = "result needs doctor review"
        elif cls:
            out["screening_status"] = "no major screening concern on this pass"
        return out

    return out


def sanitize_results_for_patient(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for r in rows:
        rc = dict(r)
        rc["details"] = sanitize_detail_for_patient(rc.get("test_name") or "", rc.get("details") or {})
        out.append(rc)
    return out


def scrub_patient_submitted_details(details: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Strip forbidden keys from patient-submitted result details (anti-tamper)."""
    if not details:
        return {}
    return {k: v for k, v in details.items() if k not in PATIENT_FORBIDDEN_DETAIL_ROOT_KEYS}
