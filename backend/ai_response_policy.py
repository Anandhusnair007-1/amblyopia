"""
Patient vs doctor visibility for AI-assisted screening responses.
Pure functions — no I/O.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

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


def build_patient_safe_strabismus_json(full: Dict[str, Any]) -> Dict[str, Any]:
    """
    Response body for POST /api/ai/analyze-strabismus when caller is a patient.
    Omits condition, confidence, and class scores; risk + plain-language guidance only.
    """
    risk_raw = full.get("risk") or "normal"
    risk_key = str(risk_raw).lower()
    recommendations: Dict[str, str] = {
        "normal": (
            "Your eye screening looks good. Continue regular check-ups."
        ),
        "mild": (
            "Minor findings detected. Please consult your eye doctor."
        ),
        "moderate": (
            "Some findings require attention. Please visit an eye specialist soon."
        ),
        "urgent": (
            "Important findings detected. Please see an eye doctor as soon as possible."
        ),
    }
    recommendation = recommendations.get(risk_key, recommendations["normal"])
    return {
        "screening_complete": True,
        "risk": risk_raw,
        "recommendation": recommendation,
        "disclaimer": (
            "This is an AI-assisted screening tool. It is not a medical diagnosis."
        ),
        "model_version": full.get("model_version") or "",
    }


def sanitize_prediction_for_patient(pred: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not pred:
        return pred
    out = {k: v for k, v in pred.items() if k not in PATIENT_PREDICTION_STRIP}
    if "findings" in out and isinstance(out["findings"], list):
        out["findings"] = [
            f for f in out["findings"]
            if "ET" not in str(f).upper() and "XT" not in str(f).upper()
        ]
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

    if test_name == "titmus":
        out["passed"] = details.get("passed")
        out["total"] = details.get("total")
        return out

    if test_name == "visual_acuity":
        if "snellen_denominator" in details:
            out["snellen_denominator"] = details["snellen_denominator"]
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
