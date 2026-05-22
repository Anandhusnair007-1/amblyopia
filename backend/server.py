"""
AmbyoAI Backend - Pediatric Amblyopia Screening API
FastAPI + MongoDB — Patient + Doctor portals
"""
from fastapi import FastAPI, APIRouter, HTTPException, Depends, File, UploadFile, Form, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional, Dict, Any
import uuid
import importlib.util
import bcrypt
import jwt
from datetime import datetime, timezone, timedelta

try:
    import sentry_sdk
except ImportError:  # optional; install sentry-sdk for production monitoring
    sentry_sdk = None  # type: ignore

try:
    from backend.security.crypto import (
        decrypt_pii,
        encrypt_pii,
        hash_lookup,
        legacy_jwt_phone_hash,
        validate_pii_startup,
    )
except ImportError:
    from security.crypto import (
        decrypt_pii,
        encrypt_pii,
        hash_lookup,
        legacy_jwt_phone_hash,
        validate_pii_startup,
    )

try:
    from backend.ai_response_policy import (
        build_patient_safe_screen_json,
        build_doctor_safe_screen_json,
        build_patient_safe_strabismus_json,
        sanitize_prediction_for_patient,
        sanitize_results_for_patient,
        scrub_patient_submitted_details,
    )
    from backend.rate_limit import allow_request, client_key_from_request, parse_limit
except ImportError:
    from ai_response_policy import (
        build_patient_safe_screen_json,
        build_doctor_safe_screen_json,
        build_patient_safe_strabismus_json,
        sanitize_prediction_for_patient,
        sanitize_results_for_patient,
        scrub_patient_submitted_details,
    )
    from rate_limit import allow_request, client_key_from_request, parse_limit

try:
    from backend.rbac import (
        ADMIN_API_ROLES,
        STAFF_PASSWORD_ROLES,
        camp_scope_filter,
        can_create_top_level_hospital,
        can_operate_session,
        can_post_diagnosis,
        can_see_ai_deviation_insights,
        can_use_admin_api,
        is_super_admin,
        patient_list_hospital_filter,
        referral_scope_filter,
        staff_belongs_to_hospital,
    )
except ImportError:
    from rbac import (
        ADMIN_API_ROLES,
        STAFF_PASSWORD_ROLES,
        camp_scope_filter,
        can_create_top_level_hospital,
        can_operate_session,
        can_post_diagnosis,
        can_see_ai_deviation_insights,
        can_use_admin_api,
        is_super_admin,
        patient_list_hospital_filter,
        referral_scope_filter,
        staff_belongs_to_hospital,
    )

try:
    from backend.clinical_classifier import apply_ai_screening_flag, classify_risk, CLINICAL_RULE_VERSION
except ImportError:
    from clinical_classifier import apply_ai_screening_flag, classify_risk, CLINICAL_RULE_VERSION

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Constants
APP_VERSION = "2.0.0"
DATASET_VERSION = os.environ.get("DATASET_VERSION", "unknown")

ENV = os.environ.get("ENV", "development")
JWT_SECRET = os.environ.get('JWT_SECRET')
JWT_ALGO = "HS256"
PATIENT_TTL_MIN = 60 * 24
DOCTOR_TTL_MIN = 60 * 8

ENABLE_DEMO_OTP = os.environ.get("ENABLE_DEMO_OTP", "true").lower() == "true" if ENV != "production" else False
DEMO_OTP = os.environ.get("DEMO_OTP", "1234") if ENABLE_DEMO_OTP else None
ENABLE_SEED_DOCTOR = os.environ.get("ENABLE_SEED_DOCTOR", "true").lower() == "true" if ENV != "production" else False

SENTRY_DSN = os.environ.get("SENTRY_DSN")
if SENTRY_DSN and sentry_sdk is not None:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        traces_sample_rate=1.0 if ENV == "development" else 0.2,
        environment=ENV,
    )

app = FastAPI(title="AmbyoAI API", version=APP_VERSION)
api_router = APIRouter(prefix="/api")
security = HTTPBearer(auto_error=False)

logger = logging.getLogger("ambyoai")
_LOG_FMT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
logging.basicConfig(level=logging.INFO, format=_LOG_FMT)

# Optional host-mounted log dir (Docker: LOG_DIR=/app/logs → ./logs/backend)
_log_dir = os.environ.get("LOG_DIR", "").strip()
if _log_dir:
    try:
        _lp = Path(_log_dir)
        _lp.mkdir(parents=True, exist_ok=True)
        _fh = logging.FileHandler(_lp / "backend.log", encoding="utf-8")
        _fh.setLevel(logging.INFO)
        _fh.setFormatter(logging.Formatter(_LOG_FMT))
        logging.getLogger().addHandler(_fh)
        logger.info("File logging enabled: %s", _lp / "backend.log")
    except OSError as exc:
        logger.warning("LOG_DIR not usable (%s): %s", _log_dir, exc)

# ── Utils
def now_iso() -> str: return datetime.now(timezone.utc).isoformat()
def mk_id() -> str: return str(uuid.uuid4())
def hash_pwd(p: str) -> str: return bcrypt.hashpw(p.encode(), bcrypt.gensalt()).decode()
def verify_pwd(p: str, h: str) -> bool:
    try: return bcrypt.checkpw(p.encode(), h.encode())
    except Exception: return False

def make_token(sub: str, role: str, extras: Dict[str, Any], ttl_min: int) -> str:
    payload = {
        "sub": sub, "role": role, **extras,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=ttl_min),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGO)

async def current_user(creds: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> Dict[str, Any]:
    if not creds:
        raise HTTPException(401, "Missing authorization")
    try:
        return jwt.decode(creds.credentials, JWT_SECRET, algorithms=[JWT_ALGO])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")

async def require_role(u: Dict[str, Any], allowed: List[str]):
    if u.get("role") not in allowed:
        raise HTTPException(403, f"Requires role: {' or '.join(allowed)}")

async def audit(action: str, u: Dict[str, Any], target_id: Optional[str] = None, details: Optional[Dict] = None):
    await db.audit_logs.insert_one({
        "id": mk_id(), "action": action, "user_id": u.get("sub"),
        "user_role": u.get("role"), "target_id": target_id,
        "timestamp": now_iso(), "details": details or {},
    })


# Rate limits: OTP_RATE_LIMIT and LOGIN_RATE_LIMIT (e.g. "30/minute", "15/minute")
def _default_otp_spec() -> str:
    return os.environ.get("OTP_RATE_LIMIT", "30/minute").strip()


def _default_login_spec() -> str:
    return os.environ.get("LOGIN_RATE_LIMIT", "15/minute").strip()


async def enforce_auth_rate_limit(request: Request, kind: str) -> None:
    """
    kind: 'otp_request' | 'otp_verify' | 'doctor_login'
    Raises HTTPException(429) if over limit; logs rate_limit.auth to audit_logs.
    """
    if kind in ("otp_request", "otp_verify"):
        spec = _default_otp_spec()
    else:
        spec = _default_login_spec()
    n, w = parse_limit(spec)
    ck = client_key_from_request(request)
    bucket = f"{kind}:{ck}"
    if allow_request(bucket, n, w):
        return
    await audit("rate_limit.auth", {"sub": ck, "role": "anonymous"}, details={
        "kind": kind, "path": str(request.url.path), "limit": spec,
    })
    raise HTTPException(429, "Too many requests. Try again later.")

def age_from_dob(dob: str) -> int:
    try:
        d = datetime.fromisoformat(dob).date()
        today = datetime.now(timezone.utc).date()
        return max(0, today.year - d.year - ((today.month, today.day) < (d.month, d.day)))
    except Exception:
        return 0


def _parse_iso_ts(ts: Optional[str]) -> datetime:
    if not ts:
        return datetime.now(timezone.utc)
    try:
        if isinstance(ts, datetime):
            return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)
        s = str(ts).replace("Z", "+00:00")
        return datetime.fromisoformat(s)
    except Exception:
        return datetime.now(timezone.utc)


def _contact_sla_due_iso(risk_level: Optional[str], anchor_iso: Optional[str]) -> Optional[str]:
    if not anchor_iso:
        return None
    anch = _parse_iso_ts(anchor_iso)
    rl = (risk_level or "normal").lower()
    if rl == "urgent":
        return (anch + timedelta(hours=24)).isoformat()
    if rl in ("moderate", "high"):
        return (anch + timedelta(hours=72)).isoformat()
    return None


def _sla_status_label(due_iso: Optional[str]) -> str:
    if not due_iso:
        return "none"
    due = _parse_iso_ts(due_iso)
    now = datetime.now(timezone.utc)
    if now > due:
        return "breached"
    if (due - now).total_seconds() < 3600 * 8:
        return "at_risk"
    return "on_track"

def serialize_patient(p: Dict[str, Any]) -> Dict[str, Any]:
    dob_plain = decrypt_pii(p.get("date_of_birth")) or ""
    return {
        "id": p["id"], "name": decrypt_pii(p["name"]) or "",
        "date_of_birth": dob_plain,
        "age": p.get("age") if p.get("age") is not None else age_from_dob(dob_plain),
        "gender": p.get("gender", "unspecified"),
        "phone": decrypt_pii(p.get("phone")) or "",
        "guardian_name": decrypt_pii(p.get("guardian_name")) or "",
        "guardian_relation": decrypt_pii(p.get("guardian_relation")) or "",
        "hospital_id": p.get("hospital_id"),
        "hospital_name": p.get("hospital_name"),
        "created_at": p.get("created_at"),
        "last_session_id": p.get("last_session_id"),
        "last_risk_level": p.get("last_risk_level"),
        "last_session_date": p.get("last_session_date"),
        "mrn": (p.get("mrn") or "").strip() or None,
    }


def _serialize_consent_record(c: Dict[str, Any]) -> Dict[str, Any]:
    """Decrypt PII fields for authorized API responses (never log this)."""
    if not c:
        return c
    out = dict(c)
    for key in ("patient_name", "date_of_birth", "guardian_name", "guardian_relation"):
        if key in out and out[key] is not None:
            out[key] = decrypt_pii(out[key]) or out[key]
    return out


async def _find_patient_by_phone(phone: str) -> Optional[Dict[str, Any]]:
    ph = hash_lookup(phone)
    existing = await db.patients.find_one({"phone_hash": ph}, {"_id": 0})
    if not existing and JWT_SECRET:
        existing = await db.patients.find_one(
            {"phone_hash": legacy_jwt_phone_hash(phone, JWT_SECRET)}, {"_id": 0}
        )
    if not existing:
        existing = await db.patients.find_one({"phone": phone}, {"_id": 0})
    return existing

# ── Models
class OtpRequestIn(BaseModel):
    phone: str

class OtpVerifyIn(BaseModel):
    phone: str
    otp: str

class DoctorLoginIn(BaseModel):
    email: EmailStr
    password: str

class HospitalIn(BaseModel):
    name: str
    location: str

class CampIn(BaseModel):
    hospital_id: str
    branch_id: Optional[str] = None
    name: str
    location: str
    start_date: str
    end_date: str

class CampPatchIn(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    status: Optional[str] = None  # planned | active | completed | archived

class BranchIn(BaseModel):
    hospital_id: str
    name: str
    location: str = ""

class HospitalExtendedIn(BaseModel):
    name: str
    location: str = ""
    address: Optional[str] = None
    contact: Optional[str] = None
    status: str = "active"

class StaffCreateIn(BaseModel):
    email: EmailStr
    password: str
    name: str
    role: str
    hospital_id: str
    branch_id: Optional[str] = None
    camp_ids: List[str] = Field(default_factory=list)

class StaffPatchIn(BaseModel):
    active: Optional[bool] = None
    branch_id: Optional[str] = None
    camp_ids: Optional[List[str]] = None
    name: Optional[str] = None

class DeviceIn(BaseModel):
    hospital_id: str
    branch_id: Optional[str] = None
    camp_id: Optional[str] = None
    device_label: str
    device_type: str = "tablet"
    assigned_to: Optional[str] = None
    status: str = "active"

class DevicePatchIn(BaseModel):
    device_label: Optional[str] = None
    device_type: Optional[str] = None
    assigned_to: Optional[str] = None
    status: Optional[str] = None
    camp_id: Optional[str] = None
    branch_id: Optional[str] = None

class ContactAttemptIn(BaseModel):
    channel: str = "phone"
    note: str = ""
    outcome: str = ""


class ReferralPatchIn(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[str] = None
    notes: Optional[str] = None
    next_follow_up_at: Optional[str] = None
    appointment_at: Optional[str] = None
    urgency: Optional[str] = None
    escalation_flag: Optional[bool] = None
    contact_attempt: Optional[ContactAttemptIn] = None

class FollowUpPatchIn(BaseModel):
    status: Optional[str] = None
    due_date: Optional[str] = None
    outcome: Optional[str] = None

class PatientRegisterIn(BaseModel):
    name: str
    date_of_birth: str
    gender: str = "unspecified"
    guardian_name: Optional[str] = None
    guardian_relation: Optional[str] = None
    mrn: Optional[str] = None  # Medical record number / hospital patient ID (optional)


class PatientSelfPatchIn(BaseModel):
    """Patient updates their own demographics (phone stays tied to login)."""

    name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    guardian_name: Optional[str] = None
    guardian_relation: Optional[str] = None


class ConsentIn(BaseModel):
    patient_id: str
    toggles: Dict[str, bool]
    language: str = "en"
    app_version: str = APP_VERSION
    consent_version: str = "v1.0"
    consent_text_hash: Optional[str] = None
    guardian_name: Optional[str] = None
    consent_scope: Dict[str, bool] = Field(default_factory=lambda: {
        "camera_screening": True,
        "medical_record_storage": True,
        "doctor_review": True,
        "anonymized_ai_training": False
    })

class TestResultIn(BaseModel):
    test_name: str
    raw_score: float
    normalized_score: float
    details: Dict[str, Any] = Field(default_factory=dict)

class DiagnosisIn(BaseModel):
    session_id: str
    diagnosis: str
    treatment: Optional[str] = ""
    risk_label: Optional[str] = ""
    follow_up_date: Optional[str] = ""
    referred_to: Optional[str] = ""
    confirmed_by_doctor: bool = True
    override_reason: Optional[str] = ""
    ai_agreement: str = "not_reviewed" # agree / disagree / uncertain / not_reviewed
    clinical_final_label: Optional[str] = ""
    referral_urgency: Optional[str] = ""
    follow_up_required: bool = False


class ExportAuditIn(BaseModel):
    export_type: str = "pdf"

# ── Routes: Auth
@api_router.get("/")
async def root():
    return {"service": "AmbyoAI", "version": "2.0.0", "status": "ok", "time": now_iso()}

@api_router.get("/health")
async def health():
    return {"status": "ok"}

@api_router.post("/auth/patient/request-otp")
async def patient_request_otp(request: Request, body: OtpRequestIn):
    await enforce_auth_rate_limit(request, "otp_request")
    phone = (body.phone or "").strip()
    if not phone.isdigit() or len(phone) != 10:
        raise HTTPException(400, "Phone must be 10 digits")
    # In demo mode, always return the fixed OTP hint (1234)
    await db.otp_log.insert_one({
        "id": mk_id(),
        "phone_hash": hash_lookup(phone),
        "phone_last4": phone[-4:],
        "created_at": now_iso(),
    })
    return {"ok": True, "demo_otp": DEMO_OTP, "message": "OTP sent (demo mode)"}

@api_router.post("/auth/patient/verify-otp")
async def patient_verify_otp(request: Request, body: OtpVerifyIn):
    await enforce_auth_rate_limit(request, "otp_verify")
    phone = (body.phone or "").strip()
    if not phone.isdigit() or len(phone) != 10:
        raise HTTPException(400, "Phone must be 10 digits")
    if not DEMO_OTP or (body.otp or "").strip() != DEMO_OTP:
        await audit(
            "login.patient_otp.failed",
            {"sub": "anonymous", "role": "anonymous"},
            details={"reason": "invalid_otp", "phone_hash": hash_lookup(phone)},
        )
        raise HTTPException(401, "Invalid OTP or demo mode disabled")
    existing = await _find_patient_by_phone(phone)
    if existing:
        name = decrypt_pii(existing["name"])
        token = make_token(existing["id"], "patient", {"phone": phone, "name": name}, PATIENT_TTL_MIN)
        return {"token": token, "user": {"id": existing["id"], "role": "patient", "name": name, "phone": phone}, "registered": True}
    # Issue a temporary patient session token (no patient record yet)
    tmp_id = "tmp-" + mk_id()
    token = make_token(tmp_id, "patient_pending", {"phone": phone}, 60)
    return {"token": token, "user": {"id": tmp_id, "role": "patient_pending", "phone": phone}, "registered": False}

@api_router.post("/auth/doctor/login")
async def doctor_login(request: Request, body: DoctorLoginIn):
    await enforce_auth_rate_limit(request, "doctor_login")
    doc = await db.users.find_one(
        {"email": body.email.lower(), "role": {"$in": list(STAFF_PASSWORD_ROLES)}},
        {"_id": 0},
    )
    if not doc or not verify_pwd(body.password, doc.get("password_hash", "")):
        await audit("login.doctor.failed", {"sub": body.email.lower(), "role": "anonymous"}, details={"reason": "invalid_credentials"})
        raise HTTPException(401, "Invalid email or password")
    await db.users.update_one({"id": doc["id"]}, {"$set": {"last_login": now_iso()}})
    await db.staff_users.update_one(
        {"user_id": doc["id"]},
        {"$set": {"last_login": now_iso()}},
        upsert=False,
    )
    role = doc.get("role") or "doctor"
    extras = {
        "name": doc["name"],
        "email": doc["email"],
        "hospital_id": doc.get("hospital_id"),
        "branch_id": doc.get("branch_id"),
        "camp_ids": doc.get("camp_ids") or [],
    }
    token = make_token(doc["id"], role, extras, DOCTOR_TTL_MIN)
    await audit("login.staff", {"sub": doc["id"], "role": role})
    return {
        "token": token,
        "user": {
            "id": doc["id"],
            "role": role,
            "name": doc["name"],
            "email": doc["email"],
            "hospital_name": doc.get("hospital_name"),
            "hospital_id": doc.get("hospital_id"),
            "branch_id": doc.get("branch_id"),
            "camp_ids": doc.get("camp_ids") or [],
        },
    }

@api_router.get("/auth/me")
async def me(u = Depends(current_user)):
    return {"id": u["sub"], "role": u["role"], **{k: u.get(k) for k in ["name", "email", "phone", "hospital_id"] if u.get(k)}}

# ── Patient: register own profile
@api_router.post("/patient/register")
async def patient_register(body: PatientRegisterIn, u = Depends(current_user)):
    if u.get("role") not in ("patient", "patient_pending"):
        raise HTTPException(403, "Patient role required")
    phone = u.get("phone")
    if not phone:
        raise HTTPException(400, "Phone missing in token")
    age = age_from_dob(body.date_of_birth)
    # Find default hospital for attribution
    hosp = await db.hospitals.find_one({}, {"_id": 0})
    doc = {
        "id": mk_id(),
        "name": encrypt_pii(body.name.strip()),
        "phone": encrypt_pii(phone),
        "phone_hash": hash_lookup(phone),
        "name_search_hash": hash_lookup(body.name.strip().lower()),
        "date_of_birth": encrypt_pii(body.date_of_birth),
        "age": age,
        "gender": body.gender,
        "guardian_name": encrypt_pii(body.guardian_name),
        "guardian_relation": encrypt_pii(body.guardian_relation) if body.guardian_relation else None,
        "hospital_id": hosp["id"] if hosp else None,
        "hospital_name": hosp["name"] if hosp else None,
        "created_at": now_iso(),
    }
    if body.mrn and str(body.mrn).strip():
        doc["mrn"] = str(body.mrn).strip()[:64]
    await db.patients.insert_one(doc.copy())
    # Re-issue full patient token now that record exists
    token = make_token(doc["id"], "patient", {"phone": phone, "name": body.name.strip()}, PATIENT_TTL_MIN)
    await audit("patient.register", {"sub": doc["id"], "role": "patient"}, doc["id"])
    return {"token": token, "user": {"id": doc["id"], "role": "patient", "name": body.name.strip(), "phone": phone}, "patient": serialize_patient(doc)}

@api_router.get("/patient/me")
async def patient_me(u = Depends(current_user)):
    if u.get("role") != "patient":
        raise HTTPException(403, "Patient role required")
    p = await db.patients.find_one({"id": u["sub"]}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient record not found")
    sessions = await db.test_sessions.find({"patient_id": u["sub"]}, {"_id": 0}).sort("created_at", -1).to_list(50)
    return {"patient": serialize_patient(p), "sessions": sessions}


@api_router.patch("/patient/me")
async def patient_patch_me(body: PatientSelfPatchIn, u = Depends(current_user)):
    if u.get("role") != "patient":
        raise HTTPException(403, "Patient role required")
    p = await db.patients.find_one({"id": u["sub"]}, {"_id": 0})
    if not p:
        raise HTTPException(404, "Patient record not found")
    data = body.model_dump(exclude_unset=True)
    if not data:
        raise HTTPException(400, "No fields to update")
    upd: Dict[str, Any] = {}
    if "name" in data and data["name"] is not None:
        nm = (data["name"] or "").strip()
        if not nm:
            raise HTTPException(400, "Name cannot be empty")
        upd["name"] = encrypt_pii(nm)
        upd["name_search_hash"] = hash_lookup(nm.lower())
    if "date_of_birth" in data and data["date_of_birth"] is not None:
        dob = (data["date_of_birth"] or "").strip()
        if not dob:
            raise HTTPException(400, "date_of_birth cannot be empty when provided")
        upd["date_of_birth"] = encrypt_pii(dob)
        upd["age"] = age_from_dob(dob)
    if "gender" in data and data["gender"] is not None:
        upd["gender"] = data["gender"]
    if "guardian_name" in data:
        upd["guardian_name"] = encrypt_pii(data["guardian_name"]) if data["guardian_name"] else None
    if "guardian_relation" in data:
        upd["guardian_relation"] = (
            encrypt_pii(data["guardian_relation"]) if data["guardian_relation"] else None
        )
    await db.patients.update_one({"id": u["sub"]}, {"$set": upd})
    p2 = await db.patients.find_one({"id": u["sub"]}, {"_id": 0})
    await audit("patient.self_patch", u, u["sub"], {"keys": list(upd.keys())})
    return {"patient": serialize_patient(p2 or p)}

# ── Consent
@api_router.post("/consent")
async def save_consent(body: ConsentIn, u = Depends(current_user)):
    required = ("camera", "storage", "doctor_share", "referral_communication")
    if not all(body.toggles.get(k) for k in required):
        raise HTTPException(
            400,
            "Required consent (camera, data storage, doctor review, referral follow-up contact) must all be accepted",
        )
    p = await db.patients.find_one({"id": body.patient_id}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient not found")
    # Patients can only save consent for themselves
    if u.get("role") == "patient" and u["sub"] != body.patient_id:
        raise HTTPException(403, "Cannot save consent for another patient")
    gn = encrypt_pii(body.guardian_name) if body.guardian_name else p.get("guardian_name")
    doc = {
        "id": mk_id(), "patient_id": body.patient_id,
        "patient_name": p["name"],
        "date_of_birth": p.get("date_of_birth"),
        "guardian_name": gn,
        "guardian_relation": p.get("guardian_relation"),
        "language": body.language, "app_version": body.app_version, 
        "consent_version": body.consent_version, 
        "consent_text_hash": body.consent_text_hash,
        "consent_scope": body.consent_scope,
        "consent_date": now_iso(), "consent_by": u["sub"],
    }
    await db.consent_records.update_one({"patient_id": body.patient_id}, {"$set": doc}, upsert=True)
    await audit("consent.save", u, body.patient_id)
    return {"ok": True}

@api_router.get("/consent/{pid}")
async def get_consent(pid: str, u = Depends(current_user)):
    if u.get("role") == "patient" and u["sub"] != pid:
        raise HTTPException(403, "Forbidden")
    c = await db.consent_records.find_one({"patient_id": pid}, {"_id": 0})
    if not c:
        return {"exists": False}
    out = _serialize_consent_record(c)
    out["exists"] = True
    return out

# ── Sessions
@api_router.post("/sessions")
async def create_session(body: Dict[str, Any], u = Depends(current_user)):
    if not can_operate_session(u):
        raise HTTPException(403, "Cannot create sessions for this role")
    patient_id = body.get("patient_id") or (u["sub"] if u.get("role") == "patient" else None)
    if not patient_id:
        raise HTTPException(400, "patient_id required")
    if u.get("role") == "patient" and u["sub"] != patient_id:
        raise HTTPException(403, "Forbidden")
    p = await db.patients.find_one({"id": patient_id}, {"_id": 0})
    if not p:
        raise HTTPException(404, "Patient not found")
    if not is_super_admin(u) and u.get("hospital_id") and p.get("hospital_id") and p["hospital_id"] != u["hospital_id"]:
        raise HTTPException(403, "Patient not in your hospital")
    hid = body.get("hospital_id") or p.get("hospital_id")
    branch_id = body.get("branch_id")
    camp_id = body.get("camp_id")
    device_id = body.get("device_id")
    r = u.get("role") or ""
    doc = {
        "id": mk_id(),
        "patient_id": patient_id,
        "hospital_id": hid,
        "branch_id": branch_id,
        "camp_id": camp_id,
        "device_id": device_id,
        "status": "in_progress",
        "created_at": now_iso(),
        "completed_at": None,
        "created_by": u["sub"],
        "created_role": r,
        "created_by_role": r,
    }
    await db.test_sessions.insert_one(doc.copy())
    await audit("session.create", u, doc["id"], {"patient_id": patient_id, "hospital_id": hid, "camp_id": camp_id})
    return {"id": doc["id"], "patient_id": patient_id, "created_at": doc["created_at"], "status": doc["status"]}

@api_router.post("/sessions/{sid}/results")
async def add_result(sid: str, body: TestResultIn, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    if u.get("role") not in ("patient", "patient_pending") and can_operate_session(u):
        if not is_super_admin(u) and u.get("hospital_id"):
            pp = await db.patients.find_one({"id": s["patient_id"]}, {"hospital_id": 1, "_id": 0})
            if pp and pp.get("hospital_id") and pp["hospital_id"] != u.get("hospital_id"):
                raise HTTPException(403, "Session not in your hospital")
    elif u.get("role") not in ("patient", "patient_pending"):
        raise HTTPException(403, "Forbidden")
    details_in = body.details if isinstance(body.details, dict) else {}
    details_save = scrub_patient_submitted_details(details_in) if u.get("role") == "patient" else details_in
    doc = {
        "id": mk_id(), "session_id": sid, "test_name": body.test_name,
        "raw_score": body.raw_score, "normalized_score": body.normalized_score,
        "details": details_save, "created_at": now_iso(),
    }
    await db.test_results.delete_many({"session_id": sid, "test_name": body.test_name})
    await db.test_results.insert_one(doc.copy())
    return {"ok": True, "result_id": doc["id"]}

@api_router.post("/sessions/{sid}/history")
async def save_session_history(sid: str, body: Dict[str, Any], u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    if u.get("role") not in ("patient", "patient_pending"):
        raise HTTPException(403, "Forbidden")
    answers = body.get("answers") if isinstance(body.get("answers"), dict) else body
    await db.test_sessions.update_one(
        {"id": sid},
        {"$set": {"screening_history": answers, "history_completed_at": now_iso()}},
    )
    await audit("session.history", u, sid, {"keys": list(answers.keys())[:20]})
    return {"ok": True}

@api_router.post("/sessions/{sid}/complete")
async def complete_session(sid: str, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    if u.get("role") not in ("patient", "patient_pending") and can_operate_session(u):
        if not is_super_admin(u) and u.get("hospital_id"):
            pp = await db.patients.find_one({"id": s["patient_id"]}, {"hospital_id": 1, "_id": 0})
            if pp and pp.get("hospital_id") and pp["hospital_id"] != u.get("hospital_id"):
                raise HTTPException(403, "Session not in your hospital")
    elif u.get("role") not in ("patient", "patient_pending"):
        raise HTTPException(403, "Forbidden")
    results = await db.test_results.find({"session_id": sid}, {"_id": 0}).to_list(50)
    patient_doc = await db.patients.find_one({"id": s["patient_id"]}, {"age": 1, "_id": 0})
    patient_age = patient_doc.get("age") if patient_doc else None
    pred = classify_risk(
        results,
        patient_age=patient_age,
        screening_history=s.get("screening_history"),
    )

    ai_insight = await db.ai_deviation_insights.find_one(
        {"session_id": sid},
        sort=[("created_at", -1)],
    )
    strabismus_ai: Optional[Dict[str, Any]] = None
    session_ai_fields: Dict[str, Any] = {}
    if ai_insight and ai_insight.get("condition") is not None:
        strabismus_ai = {
            "condition": ai_insight["condition"],
            "confidence": ai_insight.get("confidence"),
            "risk": ai_insight.get("risk"),
            "all_scores": ai_insight.get("all_scores"),
        }
        session_ai_fields = {
            "ai_condition": ai_insight["condition"],
            "ai_confidence": ai_insight.get("confidence"),
            "ai_risk": ai_insight.get("risk"),
        }
        pred = apply_ai_screening_flag(pred, ai_insight)
        if pred.get("needs_clinician_review"):
            session_ai_fields["ai_screening_flag"] = True
            session_ai_fields["needs_clinician_review"] = True
    
    # Immutable Prediction Revisions
    latest = await db.ai_predictions.find_one({"session_id": sid}, sort=[("prediction_revision_number", -1)])
    revision = (latest.get("prediction_revision_number", 0) + 1) if latest else 1
    
    try:
        _eng = _get_ai_engine()
        _qmv = getattr(_eng, "quality_version", "unknown")
        _dmv = getattr(_eng, "version", "unknown")
    except Exception:
        _qmv, _dmv = "unknown", "unknown"
    pred_doc: Dict[str, Any] = {
        "id": mk_id(), "session_id": sid, **pred,
        "prediction_revision_number": revision,
        "supersedes_prediction_id": latest["id"] if latest else None,
        "app_version": APP_VERSION,
        "quality_model_version": _qmv,
        "deviation_model_version": _dmv,
        "dataset_version": DATASET_VERSION,
        "test_algorithm_version": pred.get("test_algorithm_version", "unknown"),
        "clinical_rule_version": pred.get("clinical_rule_version", CLINICAL_RULE_VERSION),
        "prediction_created_at": now_iso(),
    }
    if strabismus_ai is not None:
        pred_doc["strabismus_ai"] = strabismus_ai
    await db.ai_predictions.insert_one(pred_doc.copy())
    session_update: Dict[str, Any] = {
        "status": "completed", "completed_at": now_iso(),
        "risk_level": pred["risk_level"], "risk_score": pred["risk_score"], "health_score": pred["health_score"],
        "app_version": APP_VERSION,
        "clinical_rule_version": CLINICAL_RULE_VERSION,
        "quality_model_version": _qmv,
        "deviation_model_version": _dmv,
        "dataset_version": DATASET_VERSION,
        "test_algorithm_version": pred.get("test_algorithm_version", "unknown"),
        "prediction_created_at": now_iso(),
    }
    session_update.update(session_ai_fields)
    await db.test_sessions.update_one({"id": sid}, {"$set": session_update})
    await db.patients.update_one({"id": s["patient_id"]}, {"$set": {
        "last_session_id": sid, "last_risk_level": pred["risk_level"], "last_session_date": now_iso(),
    }})
    if pred.get("risk_level") == "urgent":
        ref_ts = now_iso()
        sla_due = _contact_sla_due_iso("urgent", ref_ts)
        ref = {
            "id": mk_id(),
            "patient_id": s["patient_id"],
            "session_id": sid,
            "hospital_id": s.get("hospital_id"),
            "camp_id": s.get("camp_id"),
            "urgency": "urgent",
            "status": "new",
            "doctor_review_required": True,
            "assigned_to": None,
            "notes": None,
            "created_at": ref_ts,
            "updated_at": ref_ts,
            "sla_due_at": sla_due,
            "sla_status": _sla_status_label(sla_due) if sla_due else "none",
            "contact_attempts": [],
            "next_follow_up_at": None,
            "appointment_at": None,
            "escalation_flag": False,
        }
        await db.referrals.insert_one(ref)
        await audit("referral.created", u, ref["id"], {"session_id": sid, "patient_id": s["patient_id"]})
    await audit("session.complete", u, sid, {"risk_level": pred["risk_level"]})
    return pred

@api_router.get("/sessions/{sid}")
async def get_session(sid: str, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    p = await db.patients.find_one({"id": s["patient_id"]}, {"_id": 0})
    results = await db.test_results.find({"session_id": sid}, {"_id": 0}).to_list(50)
    pred = await db.ai_predictions.find_one(
        {"session_id": sid},
        projection={"_id": 0},
        sort=[("prediction_revision_number", -1)],
    )
    diag = await db.doctor_diagnoses.find_one({"session_id": sid}, {"_id": 0})
    r = u.get("role") or ""
    insights = None
    latest_insight: Optional[Dict[str, Any]] = None
    if can_see_ai_deviation_insights(r):
        insights = await db.ai_deviation_insights.find({"session_id": sid}, {"_id": 0}).sort(
            [("created_at", -1)]
        ).to_list(50)
        latest_insight = insights[0] if insights else None
    else:
        latest_insight = await db.ai_deviation_insights.find_one(
            {"session_id": sid},
            {"_id": 0},
            sort=[("created_at", -1)],
        )
    if r == "patient":
        pred = sanitize_prediction_for_patient(pred)
        results = sanitize_results_for_patient(results)
    elif r == "field_worker" and isinstance(pred, dict):
        pred = dict(pred)
        pred.pop("medical_findings", None)
    out = {
        "session": s, "patient": serialize_patient(p) if p else None,
        "results": results, "prediction": pred, "diagnosis": diag,
    }
    if can_see_ai_deviation_insights(r) and insights is not None:
        out["ai_deviation_insights"] = insights

    strabismus_ai_out: Optional[Dict[str, Any]] = None
    if latest_insight is not None and latest_insight.get("condition") is not None:
        safe_full = {
            "risk": latest_insight.get("risk"),
            "model_version": latest_insight.get("model_version"),
        }
        rule_level = (pred or {}).get("risk_level") if isinstance(pred, dict) else None
        if r == "patient":
            strabismus_ai_out = build_patient_safe_strabismus_json(
                safe_full,
                rule_based_risk_level=rule_level,
            )
        else:
            rec_safe = build_patient_safe_strabismus_json(safe_full)
            strabismus_ai_out = {
                "condition": latest_insight["condition"],
                "confidence": latest_insight.get("confidence"),
                "risk": latest_insight.get("risk"),
                "all_scores": latest_insight.get("all_scores"),
                "recommendation": rec_safe["recommendation"],
                "model_version": latest_insight.get("model_version"),
            }
    out["strabismus_ai"] = strabismus_ai_out
    return out

@api_router.get("/sessions/{sid}/fhir")
async def get_session_fhir(sid: str, u = Depends(current_user)):
    await require_role(u, ["doctor", "admin", "super_admin", "hospital_admin", "optometrist"])
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    p = await db.patients.find_one({"id": s["patient_id"]}, {"_id": 0})
    pred = await db.ai_predictions.find_one({"session_id": sid}, {"_id": 0})
    
    # Simple FHIR Bundle generation
    patient_resource = {
        "resourceType": "Patient",
        "id": p["id"] if p else "unknown",
        "name": [{"text": decrypt_pii(p["name"]) if p else "Unknown"}],
        "gender": p.get("gender", "unknown") if p else "unknown",
        "birthDate": (decrypt_pii(p.get("date_of_birth")) if p else None) or None
    }
    
    diagnostic_report = {
        "resourceType": "DiagnosticReport",
        "id": sid,
        "status": "final" if s.get("status") == "completed" else "registered",
        "code": {"coding": [{"system": "http://loinc.org", "code": "59614-8", "display": "Eye screening report"}]},
        "subject": {"reference": f"Patient/{patient_resource['id']}"},
        "effectiveDateTime": s.get("completed_at", s.get("created_at")),
        "conclusion": pred.get("risk_level", "unknown") if pred else "pending",
        "presentedForm": [{"data": pred.get("findings", []) if pred else []}]
    }

    bundle = {
        "resourceType": "Bundle",
        "type": "document",
        "timestamp": now_iso(),
        "entry": [
            {"resource": patient_resource},
            {"resource": diagnostic_report}
        ]
    }
    await audit("session.export_fhir", u, sid)
    return bundle


@api_router.post("/sessions/{sid}/export-audit")
async def audit_session_export(sid: str, body: ExportAuditIn, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s:
        raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s.get("patient_id") != u.get("sub"):
        raise HTTPException(403, "Forbidden")
    if u.get("role") != "patient":
        await require_role(u, ["doctor", "admin", "super_admin", "hospital_admin", "optometrist"])
        if not is_super_admin(u) and u.get("hospital_id") and s.get("hospital_id") and s["hospital_id"] != u["hospital_id"]:
            raise HTTPException(403, "Session not in your hospital")
    allowed = {"patient_pdf", "patient_share_pdf", "medical_pdf", "referral_letter", "fhir"}
    export_type = (body.export_type or "pdf").strip()
    if export_type not in allowed:
        raise HTTPException(400, "Invalid export type")
    await audit("session.export", u, sid, {"export_type": export_type})
    return {"ok": True}

# ── Doctor endpoints
@api_router.get("/doctor/stats")
async def doctor_stats(u = Depends(current_user)):
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    pq = patient_list_hospital_filter(u) or {}
    if pq.get("_no_access"):
        return {
            "total_patients": 0, "completed_sessions": 0, "urgent_cases": 0,
            "today_sessions": 0, "pending_review": 0,
        }
    total_patients = await db.patients.count_documents(pq if pq else {})
    sq: Dict[str, Any] = {}
    if not is_super_admin(u) and u.get("hospital_id"):
        sq["hospital_id"] = u["hospital_id"]
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    completed = await db.test_sessions.count_documents({**sq, "status": "completed"})
    urgent = await db.test_sessions.count_documents({**sq, "risk_level": "urgent"})
    today = await db.test_sessions.count_documents({**sq, "created_at": {"$gte": today_start}})
    pending_review = await db.test_sessions.count_documents({**sq, "status": "completed", "reviewed": {"$ne": True}})
    urgent_unreviewed = await db.test_sessions.count_documents({
        **sq, "status": "completed", "risk_level": "urgent", "reviewed": {"$ne": True},
    })
    reviewed_today = await db.test_sessions.count_documents({
        **sq, "reviewed": True, "reviewed_at": {"$gte": today_start},
    })
    now_iso_s = now_iso()
    followups_due = 0
    if not pq.get("_no_access"):
        fq: Dict[str, Any] = {
            "status": {"$nin": ["done", "closed", "completed"]},
            "due_date": {"$lte": now_iso_s},
        }
        if not is_super_admin(u) and u.get("hospital_id"):
            fq["hospital_id"] = u["hospital_id"]
        followups_due = await db.follow_ups.count_documents(fq)

    return {
        "total_patients": total_patients, "completed_sessions": completed,
        "urgent_cases": urgent, "today_sessions": today, "pending_review": pending_review,
        "urgent_unreviewed": urgent_unreviewed,
        "reviewed_today": reviewed_today,
        "followups_due": followups_due,
    }

@api_router.get("/audit/logs")
async def get_audit_logs(
    action: Optional[str] = None, 
    user_role: Optional[str] = None, 
    target_id: Optional[str] = None,
    limit: int = 100,
    u = Depends(current_user)
):
    await require_role(u, ["doctor", "admin", "super_admin", "hospital_admin", "optometrist"])
    query: Dict[str, Any] = {}
    if action: query["action"] = action
    if user_role: query["user_role"] = user_role
    if target_id: query["target_id"] = target_id
    
    logs = await db.audit_logs.find(query, {"_id": 0}).sort("timestamp", -1).to_list(limit)
    return logs

@api_router.get("/doctor/patients")
async def doctor_patients(risk: Optional[str] = None, q: Optional[str] = None, u = Depends(current_user)):
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    query: Dict[str, Any] = {}
    hf = patient_list_hospital_filter(u)
    if hf is not None:
        query.update(hf)
    if risk:
        query["last_risk_level"] = risk
    if q:
        qt = q.strip()
        if len(qt) == 10 and qt.isdigit():
            query["phone_hash"] = hash_lookup(qt)
        elif len(qt) >= 32 and "-" in qt:
            query["id"] = qt
        else:
            query["name_search_hash"] = hash_lookup(qt.lower())
    rows = await db.patients.find(query, {"_id": 0}).sort("created_at", -1).to_list(500)
    return [serialize_patient(r) for r in rows]


def _mask_phone_display(phone: str) -> str:
    if not phone:
        return "—"
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) <= 4:
        return "••••"
    return f"••••{digits[-4:]}"


@api_router.get("/doctor/worklist")
async def doctor_worklist(
    queue: str = "all",
    risk: Optional[str] = None,
    q: Optional[str] = None,
    camp_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    review_status: Optional[str] = None,
    assigned_me: Optional[str] = None,
    u=Depends(current_user),
):
    """Session-oriented clinical worklist (completed sessions + review state)."""
    _ = assigned_me  # reserved: filter by session.reviewed_by == me when populated
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    sq: Dict[str, Any] = {"status": "completed"}
    if not is_super_admin(u) and u.get("hospital_id"):
        sq["hospital_id"] = u["hospital_id"]

    pending_clause: Dict[str, Any] = {"$or": [{"reviewed": {"$ne": True}}, {"reviewed": None}]}
    if queue == "urgent_unreviewed":
        sq["risk_level"] = "urgent"
        sq.update(pending_clause)
    elif queue == "pending_review":
        sq.update(pending_clause)
    elif queue == "followups_due":
        # Rows driven by open follow-ups with due date in the past / today
        fq: Dict[str, Any] = {
            "status": {"$nin": ["done", "closed", "completed"]},
            "due_date": {"$lte": now_iso()},
        }
        if not is_super_admin(u) and u.get("hospital_id"):
            fq["hospital_id"] = u["hospital_id"]
        fus = await db.follow_ups.find(fq, {"_id": 0}).sort("due_date", 1).to_list(200)
        out = []
        for fu in fus:
            pid = fu.get("patient_id")
            if not pid:
                continue
            p = await db.patients.find_one({"id": pid}, {"_id": 0})
            if not p:
                continue
            if not is_super_admin(u) and u.get("hospital_id") and p.get("hospital_id") and p["hospital_id"] != u["hospital_id"]:
                continue
            sid = fu.get("session_id")
            s = await db.test_sessions.find_one({"id": sid}, {"_id": 0}) if sid else None
            if not s:
                s = {}
            phone_plain = decrypt_pii(p.get("phone")) or ""
            out.append({
                "queue": "followups_due",
                "session_id": sid,
                "patient_id": pid,
                "patient_name": decrypt_pii(p.get("name")) or "",
                "age": p.get("age"),
                "gender": p.get("gender", "unspecified"),
                "mrn": (p.get("mrn") or "").strip() or None,
                "mrn_display": (p.get("mrn") or "").strip() or f"…{pid[-6:]}",
                "phone_masked": _mask_phone_display(phone_plain),
                "risk_level": s.get("risk_level") or p.get("last_risk_level") or "normal",
                "last_screening_at": s.get("completed_at") or s.get("created_at"),
                "camp_id": s.get("camp_id"),
                "review_status": "reviewed" if s.get("reviewed") else "pending",
                "assigned_doctor_id": s.get("reviewed_by"),
                "sla_due_at": fu.get("due_date"),
                "sla_status": _sla_status_label(fu.get("due_date")),
                "followup_id": fu.get("id"),
            })
        return out

    if risk and queue != "urgent_unreviewed":
        sq["risk_level"] = risk
    if camp_id:
        sq["camp_id"] = camp_id
    if date_from or date_to:
        dr: Dict[str, Any] = {}
        if date_from:
            dr["$gte"] = date_from
        if date_to:
            dr["$lte"] = date_to
        if dr:
            sq["completed_at"] = dr
    if review_status == "reviewed":
        sq["reviewed"] = True
    elif review_status == "pending":
        sq["$or"] = [{"reviewed": {"$ne": True}}, {"reviewed": None}]

    sessions = await db.test_sessions.find(sq, {"_id": 0}).sort("completed_at", -1).limit(300).to_list(300)
    rows = []
    for s in sessions:
        pid = s.get("patient_id")
        if not pid:
            continue
        p = await db.patients.find_one({"id": pid}, {"_id": 0})
        if not p:
            continue
        if not is_super_admin(u) and u.get("hospital_id") and p.get("hospital_id") and p["hospital_id"] != u["hospital_id"]:
            continue
        nm = (decrypt_pii(p.get("name")) or "").lower()
        if q and q.strip():
            qt = q.strip().lower()
            if qt not in nm and qt != pid:
                continue
        phone_plain = decrypt_pii(p.get("phone")) or ""
        rl = s.get("risk_level") or "normal"
        anchor = s.get("completed_at") or s.get("created_at")
        sla_due = s.get("contact_sla_due_at") or _contact_sla_due_iso(rl, anchor)
        rows.append({
            "queue": queue,
            "session_id": s["id"],
            "patient_id": pid,
            "patient_name": decrypt_pii(p.get("name")) or "",
            "age": p.get("age"),
            "gender": p.get("gender", "unspecified"),
            "mrn": (p.get("mrn") or "").strip() or None,
            "mrn_display": (p.get("mrn") or "").strip() or f"…{pid[-6:]}",
            "phone_masked": _mask_phone_display(phone_plain),
            "risk_level": rl,
            "last_screening_at": anchor,
            "camp_id": s.get("camp_id"),
            "review_status": "reviewed" if s.get("reviewed") else "pending",
            "assigned_doctor_id": s.get("reviewed_by"),
            "sla_due_at": sla_due,
            "sla_status": _sla_status_label(sla_due) if sla_due else "none",
        })
    return rows


@api_router.get("/doctor/patients/{pid}")
async def doctor_patient_detail(pid: str, u = Depends(current_user)):
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    p = await db.patients.find_one({"id": pid}, {"_id": 0})
    if not p:
        raise HTTPException(404, "Patient not found")
    if not is_super_admin(u) and u.get("hospital_id") and p.get("hospital_id") and p["hospital_id"] != u["hospital_id"]:
        raise HTTPException(403, "Patient not in your hospital")
    sessions = await db.test_sessions.find({"patient_id": pid}, {"_id": 0}).sort("created_at", -1).to_list(50)
    return {"patient": serialize_patient(p), "sessions": sessions}

@api_router.post("/doctor/diagnoses")
async def save_diagnosis(body: DiagnosisIn, u = Depends(current_user)):
    if not can_post_diagnosis(u):
        raise HTTPException(403, "Only doctors may submit diagnoses")
    if not body.confirmed_by_doctor:
        raise HTTPException(400, "Diagnosis must be confirmed by doctor")
    diagnosis_text = (body.diagnosis or "").strip()
    if len(diagnosis_text) < 5:
        raise HTTPException(400, "Diagnosis must be at least 5 characters")
    if body.follow_up_date:
        try:
            fud = datetime.fromisoformat(str(body.follow_up_date)).date()
            if fud < datetime.now(timezone.utc).date():
                raise HTTPException(400, "Follow-up date cannot be in the past")
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(400, "Invalid follow-up date")
    if body.ai_agreement == "disagree" and not body.override_reason:
        raise HTTPException(400, "Override reason required when disagreeing with AI")

    s = await db.test_sessions.find_one({"id": body.session_id}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    if not is_super_admin(u) and u.get("hospital_id") and s.get("hospital_id") and s["hospital_id"] != u["hospital_id"]:
        raise HTTPException(403, "Session not in your hospital")
    
    latest = await db.doctor_diagnoses.find_one({"session_id": body.session_id}, sort=[("diagnosis_revision_number", -1)])
    revision = (latest.get("diagnosis_revision_number", 0) + 1) if latest else 1

    doc = {
        "id": mk_id(), "session_id": body.session_id, "doctor_id": u["sub"], "doctor_name": u.get("name"),
        "diagnosis": diagnosis_text, "treatment": body.treatment, "risk_label": body.risk_label,
        "follow_up_date": body.follow_up_date, "referred_to": body.referred_to,
        "confirmed_by_doctor": body.confirmed_by_doctor,
        "override_reason": body.override_reason,
        "ai_agreement": body.ai_agreement,
        "clinical_final_label": body.clinical_final_label,
        "referral_urgency": body.referral_urgency,
        "follow_up_required": body.follow_up_required,
        "diagnosis_revision_number": revision,
        "supersedes_diagnosis_id": latest["id"] if latest else None,
        "created_at": now_iso(),
    }
    await db.doctor_diagnoses.insert_one(doc.copy())
    await db.test_sessions.update_one({"id": body.session_id}, {"$set": {"reviewed": True, "reviewed_at": now_iso(), "reviewed_by": u["sub"]}})
    await audit("diagnosis.save", u, body.session_id, {"diagnosis": diagnosis_text[:80]})
    return {"ok": True, "diagnosis_id": doc["id"]}

# ── Admin / hospital operations (P1.2)
def _require_admin_api(u: Dict[str, Any]) -> None:
    if not can_use_admin_api(u):
        raise HTTPException(403, "Requires hospital_admin or super_admin")


async def _serialize_staff_row(doc: Dict[str, Any]) -> Dict[str, Any]:
    out = {k: v for k, v in doc.items() if k not in ("_id",)}
    if "name" in out and out["name"] is not None:
        out["name"] = decrypt_pii(out["name"]) or ""
    return out


@api_router.post("/admin/hospitals")
async def create_hospital(body: HospitalExtendedIn, u = Depends(current_user)):
    if not can_create_top_level_hospital(u):
        raise HTTPException(403, "Only super_admin can create hospitals")
    doc = {
        "id": mk_id(),
        "name": body.name,
        "location": body.location or "",
        "address": body.address,
        "contact": body.contact,
        "status": body.status,
        "created_at": now_iso(),
    }
    await db.hospitals.insert_one(doc.copy())
    await audit("hospital.create", u, doc["id"], {"name": body.name})
    return doc


@api_router.get("/admin/hospitals")
async def list_hospitals(u = Depends(current_user)):
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    if is_super_admin(u):
        return await db.hospitals.find({}, {"_id": 0}).to_list(200)
    hid = u.get("hospital_id")
    if hid:
        one = await db.hospitals.find_one({"id": hid}, {"_id": 0})
        return [one] if one else []
    return await db.hospitals.find({}, {"_id": 0}).to_list(200)


@api_router.get("/admin/branches")
async def list_branches(hospital_id: Optional[str] = None, u = Depends(current_user)):
    _require_admin_api(u)
    q: Dict[str, Any] = {}
    if hospital_id:
        if not is_super_admin(u) and hospital_id != u.get("hospital_id"):
            raise HTTPException(403, "Cannot view branches for another hospital")
        q["hospital_id"] = hospital_id
    elif not is_super_admin(u):
        q["hospital_id"] = u.get("hospital_id")
    return await db.branches.find(q, {"_id": 0}).to_list(200)


@api_router.post("/admin/branches")
async def create_branch(body: BranchIn, u = Depends(current_user)):
    _require_admin_api(u)
    if not staff_belongs_to_hospital(u, body.hospital_id):
        raise HTTPException(403, "Hospital scope denied")
    doc = {
        "id": mk_id(),
        "hospital_id": body.hospital_id,
        "name": body.name,
        "location": body.location,
        "status": "active",
        "created_at": now_iso(),
    }
    await db.branches.insert_one(doc.copy())
    await audit("branch.create", u, doc["id"], {"hospital_id": body.hospital_id})
    return doc


@api_router.post("/admin/camps")
async def create_camp(body: CampIn, u = Depends(current_user)):
    _require_admin_api(u)
    if not staff_belongs_to_hospital(u, body.hospital_id):
        raise HTTPException(403, "Hospital scope denied")
    hosp = await db.hospitals.find_one({"id": body.hospital_id}, {"_id": 0})
    if not hosp:
        raise HTTPException(404, "Hospital not found")
    doc = {
        "id": mk_id(),
        "hospital_id": body.hospital_id,
        "branch_id": body.branch_id,
        "hospital_name": hosp["name"],
        "name": body.name,
        "location": body.location,
        "start_date": body.start_date,
        "end_date": body.end_date,
        "created_at": now_iso(),
        "status": "planned",
        "created_by": u["sub"],
    }
    await db.camps.insert_one(doc.copy())
    await audit("camp.create", u, doc["id"], {"hospital_id": body.hospital_id})
    return doc


@api_router.get("/admin/camps")
async def list_camps(hospital_id: Optional[str] = None, u = Depends(current_user)):
    await require_role(u, ["doctor", "optometrist", "field_worker", "hospital_admin", "admin", "super_admin"])
    q = camp_scope_filter(u)
    if hospital_id:
        if not is_super_admin(u) and hospital_id != u.get("hospital_id"):
            raise HTTPException(403, "Cannot view camps for another hospital")
        q["hospital_id"] = hospital_id
    if q.get("_no_access"):
        return []
    return await db.camps.find(q, {"_id": 0}).to_list(200)


@api_router.patch("/admin/camps/{camp_id}")
async def patch_camp(camp_id: str, body: CampPatchIn, u = Depends(current_user)):
    _require_admin_api(u)
    c = await db.camps.find_one({"id": camp_id}, {"_id": 0})
    if not c:
        raise HTTPException(404, "Camp not found")
    if not staff_belongs_to_hospital(u, c["hospital_id"]):
        raise HTTPException(403, "Hospital scope denied")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    if not upd:
        return c
    await db.camps.update_one({"id": camp_id}, {"$set": upd})
    await audit("camp.patch", u, camp_id, {"keys": list(upd.keys())})
    return await db.camps.find_one({"id": camp_id}, {"_id": 0})


@api_router.get("/admin/staff")
async def list_staff(hospital_id: Optional[str] = None, u = Depends(current_user)):
    _require_admin_api(u)
    q: Dict[str, Any] = {}
    if hospital_id:
        if not is_super_admin(u) and hospital_id != u.get("hospital_id"):
            raise HTTPException(403, "Hospital scope denied")
        q["hospital_id"] = hospital_id
    elif not is_super_admin(u):
        q["hospital_id"] = u.get("hospital_id")
    rows = await db.staff_users.find(q, {"_id": 0}).to_list(500)
    return [await _serialize_staff_row(r) for r in rows]


@api_router.post("/admin/staff")
async def create_staff(body: StaffCreateIn, u = Depends(current_user)):
    _require_admin_api(u)
    if not staff_belongs_to_hospital(u, body.hospital_id):
        raise HTTPException(403, "Hospital scope denied")
    if body.role in ("patient", "patient_pending"):
        raise HTTPException(400, "Invalid staff role")
    if body.role not in STAFF_PASSWORD_ROLES:
        raise HTTPException(400, "Invalid role for staff account")
    if body.role == "super_admin" and not is_super_admin(u):
        raise HTTPException(403, "Only super_admin can create super_admin")
    uid = mk_id()
    user_doc = {
        "id": uid,
        "email": body.email.lower(),
        "password_hash": hash_pwd(body.password),
        "role": body.role,
        "name": body.name,
        "hospital_id": body.hospital_id,
        "branch_id": body.branch_id,
        "camp_ids": body.camp_ids or [],
        "created_at": now_iso(),
    }
    hosp = await db.hospitals.find_one({"id": body.hospital_id}, {"_id": 0})
    if hosp:
        user_doc["hospital_name"] = hosp.get("name")
    await db.users.insert_one(user_doc.copy())
    staff_doc = {
        "id": mk_id(),
        "user_id": uid,
        "hospital_id": body.hospital_id,
        "branch_id": body.branch_id,
        "camp_ids": body.camp_ids or [],
        "name": encrypt_pii(body.name.strip()),
        "email": body.email.lower(),
        "role": body.role,
        "active": True,
        "created_at": now_iso(),
    }
    await db.staff_users.insert_one(staff_doc.copy())
    await audit("staff.create", u, uid, {"role": body.role, "hospital_id": body.hospital_id})
    return {"id": uid, "email": user_doc["email"], "role": body.role}


@api_router.patch("/admin/staff/{staff_id}")
async def patch_staff(staff_id: str, body: StaffPatchIn, u = Depends(current_user)):
    _require_admin_api(u)
    st = await db.staff_users.find_one({"user_id": staff_id}, {"_id": 0})
    if not st:
        raise HTTPException(404, "Staff not found")
    if not staff_belongs_to_hospital(u, st["hospital_id"]):
        raise HTTPException(403, "Hospital scope denied")
    upd: Dict[str, Any] = {}
    if body.active is not None:
        upd["active"] = body.active
    if body.branch_id is not None:
        upd["branch_id"] = body.branch_id
    if body.camp_ids is not None:
        upd["camp_ids"] = body.camp_ids
    if body.name is not None:
        upd["name"] = encrypt_pii(body.name.strip())
    if upd:
        await db.staff_users.update_one({"user_id": staff_id}, {"$set": upd})
        uu: Dict[str, Any] = {}
        if body.branch_id is not None:
            uu["branch_id"] = body.branch_id
        if body.camp_ids is not None:
            uu["camp_ids"] = body.camp_ids
        if body.name is not None:
            uu["name"] = body.name.strip()
        if uu:
            await db.users.update_one({"id": staff_id}, {"$set": uu})
    await audit("staff.patch", u, staff_id, {"keys": list(upd.keys())})
    return await db.staff_users.find_one({"user_id": staff_id}, {"_id": 0})


@api_router.get("/admin/devices")
async def list_devices(hospital_id: Optional[str] = None, u = Depends(current_user)):
    _require_admin_api(u)
    q: Dict[str, Any] = {}
    if hospital_id:
        if not is_super_admin(u) and hospital_id != u.get("hospital_id"):
            raise HTTPException(403, "Hospital scope denied")
        q["hospital_id"] = hospital_id
    elif not is_super_admin(u):
        q["hospital_id"] = u.get("hospital_id")
    return await db.devices.find(q, {"_id": 0}).to_list(500)


@api_router.post("/admin/devices")
async def create_device(body: DeviceIn, u = Depends(current_user)):
    _require_admin_api(u)
    if not staff_belongs_to_hospital(u, body.hospital_id):
        raise HTTPException(403, "Hospital scope denied")
    doc = {
        "id": mk_id(),
        "hospital_id": body.hospital_id,
        "branch_id": body.branch_id,
        "camp_id": body.camp_id,
        "device_label": body.device_label,
        "device_type": body.device_type,
        "assigned_to": body.assigned_to,
        "status": body.status,
        "last_seen_at": None,
        "created_at": now_iso(),
    }
    await db.devices.insert_one(doc.copy())
    await audit("device.create", u, doc["id"])
    return doc


@api_router.patch("/admin/devices/{device_id}")
async def patch_device(device_id: str, body: DevicePatchIn, u = Depends(current_user)):
    _require_admin_api(u)
    d = await db.devices.find_one({"id": device_id}, {"_id": 0})
    if not d:
        raise HTTPException(404, "Device not found")
    if not staff_belongs_to_hospital(u, d["hospital_id"]):
        raise HTTPException(403, "Hospital scope denied")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    if upd:
        await db.devices.update_one({"id": device_id}, {"$set": upd})
    await audit("device.patch", u, device_id, {"keys": list(upd.keys())})
    return await db.devices.find_one({"id": device_id}, {"_id": 0})


@api_router.get("/referrals")
async def list_referrals(
    status: Optional[str] = None,
    hospital_id: Optional[str] = None,
    camp_id: Optional[str] = None,
    u = Depends(current_user),
):
    await require_role(u, ["doctor", "optometrist", "hospital_admin", "admin", "super_admin"])
    q = referral_scope_filter(u)
    if q.get("_no_access"):
        return []
    if hospital_id:
        if not is_super_admin(u) and hospital_id != u.get("hospital_id"):
            raise HTTPException(403, "Hospital scope denied")
        q["hospital_id"] = hospital_id
    if camp_id:
        q["camp_id"] = camp_id
    if status:
        q["status"] = status
    return await db.referrals.find(q, {"_id": 0}).sort("created_at", -1).to_list(200)


@api_router.patch("/referrals/{referral_id}")
async def patch_referral(referral_id: str, body: ReferralPatchIn, u = Depends(current_user)):
    await require_role(u, ["doctor", "hospital_admin", "admin", "super_admin"])
    ref = await db.referrals.find_one({"id": referral_id}, {"_id": 0})
    if not ref:
        raise HTTPException(404, "Referral not found")
    if not is_super_admin(u) and ref.get("hospital_id") != u.get("hospital_id"):
        raise HTTPException(403, "Hospital scope denied")
    raw = body.model_dump(exclude_unset=True)
    if "contact_attempt" in raw:
        raw.pop("contact_attempt")
    upd = {k: v for k, v in raw.items() if v is not None}
    if body.contact_attempt is not None:
        attempts = list(ref.get("contact_attempts") or [])
        attempts.append({
            "at": now_iso(),
            "by_user_id": u.get("sub"),
            "channel": body.contact_attempt.channel,
            "note": body.contact_attempt.note,
            "outcome": body.contact_attempt.outcome,
        })
        upd["contact_attempts"] = attempts
    upd["updated_at"] = now_iso()
    due = upd.get("sla_due_at", ref.get("sla_due_at"))
    if due:
        upd["sla_status"] = _sla_status_label(due)
    await db.referrals.update_one({"id": referral_id}, {"$set": upd})
    await audit("referral.patch", u, referral_id, {"keys": [k for k in upd if k != "updated_at"]})
    return await db.referrals.find_one({"id": referral_id}, {"_id": 0})


@api_router.get("/followups")
async def list_followups(
    status: Optional[str] = None,
    u = Depends(current_user),
):
    await require_role(u, ["doctor", "hospital_admin", "admin", "super_admin"])
    q: Dict[str, Any] = {}
    if not is_super_admin(u):
        hid = u.get("hospital_id")
        if not hid:
            return []
        # join via patient hospital — store hospital_id on follow_ups for simpler scope
        q["hospital_id"] = hid
    if status:
        q["status"] = status
    return await db.follow_ups.find(q, {"_id": 0}).sort("due_date", 1).to_list(200)


@api_router.patch("/followups/{followup_id}")
async def patch_followup(followup_id: str, body: FollowUpPatchIn, u = Depends(current_user)):
    await require_role(u, ["doctor", "hospital_admin", "admin", "super_admin"])
    f = await db.follow_ups.find_one({"id": followup_id}, {"_id": 0})
    if not f:
        raise HTTPException(404, "Follow-up not found")
    if not is_super_admin(u) and f.get("hospital_id") != u.get("hospital_id"):
        raise HTTPException(403, "Hospital scope denied")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    upd["updated_at"] = now_iso()
    await db.follow_ups.update_one({"id": followup_id}, {"$set": upd})
    await audit("followup.patch", u, followup_id, {"keys": [k for k in upd if k != "updated_at"]})
    return await db.follow_ups.find_one({"id": followup_id}, {"_id": 0})

# ── AI Screening (Experimental) — lazy import so server/tests load without TensorFlow
_ai_engine = None


def _get_ai_engine():
    """Load ai_engine from the file next to this module (works in Docker /app and plain backend/)."""
    global _ai_engine
    if _ai_engine is None:
        path = ROOT_DIR / "ai_engine.py"
        spec = importlib.util.spec_from_file_location("ambyoai_ai_engine", path)
        if spec is None or spec.loader is None:
            raise ImportError("ai_engine spec missing")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _eng = getattr(mod, "ai_engine", None)
        if _eng is None:
            raise ImportError("ai_engine singleton missing in ai_engine.py")
        _ai_engine = _eng
    return _ai_engine


@api_router.post("/ai/screen-quality")
async def ai_screen_quality(
    file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    test_name: Optional[str] = Form(None),
    u = Depends(current_user),
):
    """Quality + optional deviation (deviation stored doctor-only; patients get patient-safe JSON)."""
    try:
        eng = _get_ai_engine()
    except Exception:
        logger.exception("ai_engine load failed — see traceback (missing deps, bad ai_engine.py, or unreadable file)")
        raise HTTPException(503, "AI engine unavailable (missing dependencies)")
    result = await eng.screen_eye(file)
    await audit("ai.screen_eye", u, target_id=session_id, details={"test_name": test_name, "quality": (result or {}).get("quality")})

    qmv = (result or {}).get("quality_model_version") or getattr(eng, "quality_version", "unknown")
    if session_id and test_name:
        doc = {
            "id": mk_id(),
            "session_id": session_id,
            "test_name": test_name,
            "created_at": now_iso(),
            "app_version": APP_VERSION,
            "quality_model_version": qmv,
            "deviation_model_version": eng.version,
            "dataset_version": DATASET_VERSION,
            "test_algorithm_version": "ai_engine_screen_eye_v1",
            "prediction_created_at": now_iso(),
            "doctor_review_required": result.get("doctor_review_required"),
            "disclaimer": result.get("disclaimer"),
            "deviation": result.get("deviation"),
            "quality": result.get("quality"),
        }
        await db.ai_deviation_insights.insert_one(doc.copy())

    role = u.get("role")
    if role == "patient":
        return build_patient_safe_screen_json(result, app_version=APP_VERSION, quality_model_version=qmv)
    return build_doctor_safe_screen_json(result)


@api_router.post("/ai/analyze-strabismus")
async def ai_analyze_strabismus(
    file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    test_name: Optional[str] = Form(None),
    u = Depends(current_user),
):
    """4-class strabismus scan; optional persistence to ai_deviation_insights when session_id is set."""
    try:
        eng = _get_ai_engine()
    except Exception:
        logger.exception("ai_engine load failed — see traceback (missing deps, bad ai_engine.py, or unreadable file)")
        raise HTTPException(503, "AI engine unavailable (missing dependencies)")
    result = await eng.classify_strabismus(file)
    await audit(
        "ai.analyze_strabismus",
        u,
        target_id=session_id,
        details={"test_name": test_name, "condition": (result or {}).get("condition"), "risk": (result or {}).get("risk")},
    )

    if session_id:
        doc = {
            "id": mk_id(),
            "session_id": session_id,
            "test_name": test_name or "strabismus_scan",
            "condition": result["condition"],
            "confidence": result["confidence"],
            "risk": result["risk"],
            "all_scores": result["all_scores"],
            "model_version": result["model_version"],
            "created_at": now_iso(),
        }
        await db.ai_deviation_insights.insert_one(doc.copy())

    role = u.get("role")
    if role == "patient":
        rule_level = None
        if session_id:
            pred_doc = await db.ai_predictions.find_one(
                {"session_id": session_id},
                {"_id": 0, "risk_level": 1},
            )
            if pred_doc:
                rule_level = pred_doc.get("risk_level")
        return build_patient_safe_strabismus_json(
            result,
            rule_based_risk_level=rule_level,
        )
    return dict(result)

# ── Seed defaults
@app.on_event("startup")
async def validate_and_seed():
    validate_pii_startup()

    try:
        eng = _get_ai_engine()
        logger.info(
            "AI quality model: %s — path %s",
            "loaded" if getattr(eng, "quality_model", None) else "missing (heuristic fallback when screening)",
            getattr(eng, "quality_model_path", "?"),
        )
        logger.info(
            "AI deviation model: %s — path %s",
            "loaded" if getattr(eng, "deviation_model", None) else "not loaded",
            getattr(eng, "deviation_model_path", "?"),
        )
        logger.info(
            "AI strabismus model: %s — path %s",
            "loaded" if getattr(eng, "strabismus_model", None) else "using heuristic fallback",
            getattr(eng, "strabismus_model_path", "?"),
        )
    except Exception as exc:
        logger.warning("AI engine startup probe skipped (%s)", exc)

    # 1. Safety Checks
    if ENV == "production":
        if not JWT_SECRET or JWT_SECRET == "ambyoai-hospital-secret-change-me-2026":
            logger.error("FATAL: Default or missing JWT_SECRET in production!")
            raise RuntimeError("Insecure JWT_SECRET")
        if os.environ.get('CORS_ORIGINS', '*') == '*':
            logger.error("FATAL: CORS wildcard allowed in production!")
            raise RuntimeError("Insecure CORS configuration")

    # 2. Seed Defaults (Development only)
    if ENABLE_SEED_DOCTOR:
        try:
            hosp = await db.hospitals.find_one({})
            if not hosp:
                hosp_id = mk_id()
                await db.hospitals.insert_one({
                    "id": hosp_id,
                    "name": "Aravind Eye Hospital",
                    "location": "Coimbatore, Tamil Nadu",
                    "address": "Coimbatore, Tamil Nadu",
                    "contact": "+91-000-000-0000",
                    "status": "active",
                    "created_at": now_iso(),
                })
                hosp = {"id": hosp_id, "name": "Aravind Eye Hospital"}

            doctor = await db.users.find_one({"role": "doctor"})
            if not doctor:
                did = mk_id()
                dname = "Dr. Meera Sundaram"
                await db.users.insert_one({
                    "id": did, "name": dname,
                    "email": "doctor@aravind.in", "role": "doctor",
                    "password_hash": hash_pwd("aravind2026"),
                    "hospital_id": hosp["id"], "hospital_name": hosp["name"],
                    "created_at": now_iso(),
                })
                await db.staff_users.insert_one({
                    "id": mk_id(),
                    "user_id": did,
                    "hospital_id": hosp["id"],
                    "branch_id": None,
                    "camp_ids": [],
                    "name": encrypt_pii(dname),
                    "email": "doctor@aravind.in",
                    "role": "doctor",
                    "active": True,
                    "created_at": now_iso(),
                })
                logger.info("Seeded default doctor: doctor@aravind.in / aravind2026")

            admin = await db.users.find_one({"role": "admin"})
            if not admin:
                aid = mk_id()
                aname = "System Admin"
                await db.users.insert_one({
                    "id": aid, "name": aname,
                    "email": "admin@aravind.in", "role": "admin",
                    "password_hash": hash_pwd("admin2026"),
                    "hospital_id": hosp["id"], "hospital_name": hosp["name"],
                    "created_at": now_iso(),
                })
                await db.staff_users.insert_one({
                    "id": mk_id(),
                    "user_id": aid,
                    "hospital_id": hosp["id"],
                    "branch_id": None,
                    "camp_ids": [],
                    "name": encrypt_pii(aname),
                    "email": "admin@aravind.in",
                    "role": "admin",
                    "active": True,
                    "created_at": now_iso(),
                })
                logger.info("Seeded default admin: admin@aravind.in / admin2026")
        except Exception as e:
            logger.error(f"Seed error: {e}")

app.include_router(api_router)
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()

if __name__ == "__main__":
    import uvicorn
    # When run directly, we trigger the startup event to test safety gates
    port = int(os.environ.get("PORT", 8010))
    print(f"Starting AmbyoAI Server in {ENV} mode...")
    uvicorn.run(app, host="0.0.0.0", port=port)
