"""
Role helpers for P1.2 hospital operations (no request objects — pass JWT user dict).
Legacy role `admin` is treated as hospital-scoped hospital_admin for permissions.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Set

ROLE_SUPER_ADMIN = "super_admin"
ROLE_HOSPITAL_ADMIN = "hospital_admin"
ROLE_ADMIN_LEGACY = "admin"
ROLE_DOCTOR = "doctor"
ROLE_OPTOMETRIST = "optometrist"
ROLE_FIELD_WORKER = "field_worker"
ROLE_PATIENT = "patient"
ROLE_PATIENT_PENDING = "patient_pending"

# Password-based staff login (doctor login endpoint)
STAFF_PASSWORD_ROLES: Set[str] = {
    ROLE_SUPER_ADMIN,
    ROLE_HOSPITAL_ADMIN,
    ROLE_ADMIN_LEGACY,
    ROLE_DOCTOR,
    ROLE_OPTOMETRIST,
    ROLE_FIELD_WORKER,
}

# Can open /admin APIs (mutations + sensitive lists)
ADMIN_API_ROLES: Set[str] = {ROLE_SUPER_ADMIN, ROLE_HOSPITAL_ADMIN, ROLE_ADMIN_LEGACY}

# Clinical read including AI deviation payloads on sessions
CLINICAL_AI_INSIGHT_ROLES: Set[str] = {
    ROLE_DOCTOR,
    ROLE_ADMIN_LEGACY,
    ROLE_SUPER_ADMIN,
    ROLE_HOSPITAL_ADMIN,
    ROLE_OPTOMETRIST,
}

# Who may POST final diagnosis
DIAGNOSIS_ROLES: Set[str] = {ROLE_DOCTOR, ROLE_SUPER_ADMIN}

# Who may create / complete screening sessions for a patient
SESSION_OPERATOR_ROLES: Set[str] = {
    ROLE_PATIENT,
    ROLE_FIELD_WORKER,
    ROLE_OPTOMETRIST,
    ROLE_DOCTOR,
    ROLE_HOSPITAL_ADMIN,
    ROLE_ADMIN_LEGACY,
    ROLE_SUPER_ADMIN,
}


def role(u: Dict[str, Any]) -> str:
    return (u.get("role") or "").strip()


def is_super_admin(u: Dict[str, Any]) -> bool:
    return role(u) == ROLE_SUPER_ADMIN


def is_hospital_admin_like(u: Dict[str, Any]) -> bool:
    r = role(u)
    return r in (ROLE_HOSPITAL_ADMIN, ROLE_ADMIN_LEGACY)


def can_use_admin_api(u: Dict[str, Any]) -> bool:
    return role(u) in ADMIN_API_ROLES


def can_create_top_level_hospital(u: Dict[str, Any]) -> bool:
    return is_super_admin(u)


def can_see_ai_deviation_insights(r: str) -> bool:
    if r in (ROLE_FIELD_WORKER, ROLE_PATIENT, ROLE_PATIENT_PENDING):
        return False
    return r in CLINICAL_AI_INSIGHT_ROLES


def can_post_diagnosis(u: Dict[str, Any]) -> bool:
    return role(u) in DIAGNOSIS_ROLES


def can_operate_session(u: Dict[str, Any]) -> bool:
    return role(u) in SESSION_OPERATOR_ROLES


def patient_list_hospital_filter(u: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Mongo filter fragment for patients visible to this user; None = no extra filter (super admin)."""
    if is_super_admin(u):
        return None
    hid = u.get("hospital_id")
    if not hid:
        return {"_no_access": True}
    return {"hospital_id": hid}


def staff_belongs_to_hospital(u: Dict[str, Any], hospital_id: str) -> bool:
    if is_super_admin(u):
        return True
    return (u.get("hospital_id") or "") == hospital_id


def camp_scope_filter(u: Dict[str, Any]) -> Dict[str, Any]:
    if is_super_admin(u):
        return {}
    hid = u.get("hospital_id")
    if not hid:
        return {"_no_access": True}
    return {"hospital_id": hid}


def referral_scope_filter(u: Dict[str, Any]) -> Dict[str, Any]:
    if is_super_admin(u):
        return {}
    hid = u.get("hospital_id")
    if not hid:
        return {"_no_access": True}
    return {"hospital_id": hid}


def allowed_roles_list(*groups: Set[str]) -> List[str]:
    out: List[str] = []
    for g in groups:
        out.extend(sorted(g))
    return sorted(set(out))
