"""
AmbyoAI Backend - Pediatric Amblyopia Screening API
FastAPI + MongoDB — Patient + Doctor portals
"""
from fastapi import FastAPI, APIRouter, HTTPException, Depends
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
import bcrypt
import jwt
from datetime import datetime, timezone, timedelta

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

JWT_SECRET = os.environ.get('JWT_SECRET', 'ambyoai-hospital-secret-change-me-2026')
JWT_ALGO = "HS256"
PATIENT_TTL_MIN = 60 * 24        # 24h
DOCTOR_TTL_MIN = 60 * 8          # 8h shift
DEMO_OTP = os.environ.get("DEMO_OTP", "1234")

app = FastAPI(title="AmbyoAI API", version="2.0.0")
api_router = APIRouter(prefix="/api")
security = HTTPBearer(auto_error=False)

logger = logging.getLogger("ambyoai")
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

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

def age_from_dob(dob: str) -> int:
    try:
        d = datetime.fromisoformat(dob).date()
        today = datetime.now(timezone.utc).date()
        return max(0, today.year - d.year - ((today.month, today.day) < (d.month, d.day)))
    except Exception:
        return 0

def serialize_patient(p: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": p["id"], "name": p["name"],
        "date_of_birth": p.get("date_of_birth", ""),
        "age": p.get("age", age_from_dob(p.get("date_of_birth", ""))),
        "gender": p.get("gender", "unspecified"),
        "phone": p.get("phone"),
        "guardian_name": p.get("guardian_name"),
        "guardian_relation": p.get("guardian_relation"),
        "hospital_id": p.get("hospital_id"),
        "hospital_name": p.get("hospital_name"),
        "created_at": p.get("created_at"),
        "last_session_id": p.get("last_session_id"),
        "last_risk_level": p.get("last_risk_level"),
        "last_session_date": p.get("last_session_date"),
    }

# ── Models
class OtpRequestIn(BaseModel):
    phone: str

class OtpVerifyIn(BaseModel):
    phone: str
    otp: str

class DoctorLoginIn(BaseModel):
    email: EmailStr
    password: str

class PatientRegisterIn(BaseModel):
    name: str
    date_of_birth: str
    gender: str = "unspecified"
    guardian_name: Optional[str] = None
    guardian_relation: Optional[str] = None

class ConsentIn(BaseModel):
    patient_id: str
    toggles: Dict[str, bool]
    language: str = "en"
    app_version: str = "2.0.0"

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

# ── Clinical Risk Classifier
def classify_risk(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    by_name = {r["test_name"]: r for r in results}
    findings: List[str] = []
    medical_findings: List[Dict[str, Any]] = []  # detailed version for doctor
    urgent, high, mild = False, False, False

    rr = by_name.get("red_reflex")
    if rr:
        cls = (rr.get("details") or {}).get("classification", "")
        if cls in ("leukocoria", "white"):
            findings.append("White reflex detected in pupil — immediate ophthalmology referral required.")
            medical_findings.append({
                "test": "Red Reflex", "metric": "classification", "value": cls,
                "threshold": "Expected: symmetric red/orange reflex",
                "interpretation": "Leukocoria — possible retinoblastoma, cataract, or retinal detachment. URGENT.",
                "severity": "urgent",
            })
            urgent = True
        elif cls == "absent":
            findings.append("Red reflex not detectable — possible media opacity.")
            medical_findings.append({"test": "Red Reflex", "metric": "classification", "value": "absent",
                                     "threshold": "Expected: symmetric red/orange reflex",
                                     "interpretation": "Absent red reflex may indicate dense cataract or vitreous haemorrhage.",
                                     "severity": "urgent"})
            urgent = True
        elif cls == "dim":
            findings.append("Dim red reflex — further evaluation recommended.")
            medical_findings.append({"test": "Red Reflex", "metric": "classification", "value": "dim",
                                     "threshold": "Normal: bright red/orange", "interpretation": "Possible early media opacity.",
                                     "severity": "moderate"})
            high = True

    gz = by_name.get("gaze")
    if gz:
        dev = (gz.get("details") or {}).get("max_deviation_pd", 0)
        if dev > 20:
            findings.append(f"Significant eye misalignment detected ({dev:.1f} prism diopters).")
            medical_findings.append({"test": "Gaze Deviation", "metric": "max_deviation_pd", "value": f"{dev:.1f} Δ",
                                     "threshold": "Normal: ≤ 4 Δ",
                                     "interpretation": "Strabismus — manifest ocular deviation >20Δ. Urgent ophthalmology referral.",
                                     "severity": "urgent"})
            urgent = True
        elif dev > 10:
            medical_findings.append({"test": "Gaze Deviation", "metric": "max_deviation_pd", "value": f"{dev:.1f} Δ",
                                     "threshold": "Normal: ≤ 4 Δ",
                                     "interpretation": "Moderate deviation — consistent with manifest strabismus.",
                                     "severity": "high"})
            findings.append(f"Moderate eye deviation detected ({dev:.1f} Δ).")
            high = True
        elif dev > 4:
            medical_findings.append({"test": "Gaze Deviation", "metric": "max_deviation_pd", "value": f"{dev:.1f} Δ",
                                     "threshold": "Normal: ≤ 4 Δ",
                                     "interpretation": "Mild deviation — recommend cover/uncover clinical test.",
                                     "severity": "mild"})
            mild = True

    hb = by_name.get("hirschberg")
    if hb:
        disp = (hb.get("details") or {}).get("displacement_mm", 0)
        if disp > 4:
            findings.append(f"Asymmetric corneal reflex ({disp:.1f} mm displacement).")
            medical_findings.append({"test": "Hirschberg", "metric": "displacement_mm", "value": f"{disp:.1f} mm",
                                     "threshold": "Normal: < 1 mm (centered reflex)",
                                     "interpretation": "1 mm = ~7° deviation. Significant strabismus present.",
                                     "severity": "urgent"})
            urgent = True
        elif disp > 2:
            medical_findings.append({"test": "Hirschberg", "metric": "displacement_mm", "value": f"{disp:.1f} mm",
                                     "threshold": "Normal: < 1 mm", "interpretation": "Mild corneal reflex asymmetry.",
                                     "severity": "moderate"})
            high = True
            findings.append(f"Mild corneal reflex asymmetry ({disp:.1f} mm).")

    va = by_name.get("visual_acuity")
    if va:
        den = (va.get("details") or {}).get("snellen_denominator", 6)
        if den >= 24:
            findings.append(f"Reduced vision detected (6/{int(den)}).")
            medical_findings.append({"test": "Visual Acuity", "metric": "snellen", "value": f"6/{int(den)}",
                                     "threshold": "Normal: ≥ 6/9", "interpretation": "Significantly reduced acuity — refractive error or amblyopia likely.",
                                     "severity": "urgent"})
            urgent = True
        elif den >= 12:
            medical_findings.append({"test": "Visual Acuity", "metric": "snellen", "value": f"6/{int(den)}",
                                     "threshold": "Normal: ≥ 6/9", "interpretation": "Sub-optimal vision — refractive assessment advised.",
                                     "severity": "moderate"})
            high = True
            findings.append(f"Vision below normal (6/{int(den)}).")

    ts = by_name.get("titmus")
    if ts:
        passed = (ts.get("details") or {}).get("passed", 0)
        total = (ts.get("details") or {}).get("total", 3)
        if passed == 0:
            findings.append("No stereo depth perception detected.")
            medical_findings.append({"test": "Titmus Stereo", "metric": "passed", "value": f"{passed}/{total}",
                                     "threshold": "Normal: ≥ 2/3 sub-tests", "interpretation": "Lack of stereopsis — suggests binocular dysfunction or amblyopia.",
                                     "severity": "high"})
            high = True
        elif passed < total:
            medical_findings.append({"test": "Titmus Stereo", "metric": "passed", "value": f"{passed}/{total}",
                                     "threshold": "Normal: full", "interpretation": "Partial stereopsis — borderline binocular vision.",
                                     "severity": "mild"})
            mild = True

    pr = by_name.get("prism")
    if pr:
        pd = (pr.get("details") or {}).get("max_prism_diopters", 0)
        medical_findings.append({"test": "Prism Diopter", "metric": "max_prism_diopters", "value": f"{pd:.1f} Δ",
                                 "threshold": "Normal: ≤ 4 Δ", "interpretation": "Derived from gaze deviation — quantifies ocular misalignment magnitude.",
                                 "severity": "urgent" if pd > 20 else "moderate" if pd > 10 else "mild" if pd > 4 else "normal"})

    if urgent:
        level, score = "urgent", 0.95
    elif high:
        level, score = "moderate", 0.70
    elif mild:
        level, score = "mild", 0.40
    else:
        level, score = "normal", 0.10

    health = round((1 - score) * 100, 1)
    if not findings and level == "normal":
        findings.append("All screening indicators within normal range.")

    return {
        "risk_level": level,
        "risk_score": round(score, 3),
        "health_score": health,
        "findings": findings,
        "medical_findings": medical_findings,
        "model_version": "clinical-fallback-v1",
    }

# ── Routes: Auth
@api_router.get("/")
async def root():
    return {"service": "AmbyoAI", "version": "2.0.0", "status": "ok", "time": now_iso()}

@api_router.get("/health")
async def health():
    return {"status": "ok"}

@api_router.post("/auth/patient/request-otp")
async def patient_request_otp(body: OtpRequestIn):
    phone = (body.phone or "").strip()
    if not phone.isdigit() or len(phone) != 10:
        raise HTTPException(400, "Phone must be 10 digits")
    # In demo mode, always return the fixed OTP hint (1234)
    await db.otp_log.insert_one({"id": mk_id(), "phone": phone, "created_at": now_iso()})
    return {"ok": True, "demo_otp": DEMO_OTP, "message": "OTP sent (demo mode)"}

@api_router.post("/auth/patient/verify-otp")
async def patient_verify_otp(body: OtpVerifyIn):
    phone = (body.phone or "").strip()
    if not phone.isdigit() or len(phone) != 10:
        raise HTTPException(400, "Phone must be 10 digits")
    if (body.otp or "").strip() != DEMO_OTP:
        raise HTTPException(401, "Invalid OTP")
    # Find or return pending registration flag
    existing = await db.patients.find_one({"phone": phone}, {"_id": 0})
    if existing:
        token = make_token(existing["id"], "patient", {"phone": phone, "name": existing["name"]}, PATIENT_TTL_MIN)
        return {"token": token, "user": {"id": existing["id"], "role": "patient", "name": existing["name"], "phone": phone}, "registered": True}
    # Issue a temporary patient session token (no patient record yet)
    tmp_id = "tmp-" + mk_id()
    token = make_token(tmp_id, "patient_pending", {"phone": phone}, 60)
    return {"token": token, "user": {"id": tmp_id, "role": "patient_pending", "phone": phone}, "registered": False}

@api_router.post("/auth/doctor/login")
async def doctor_login(body: DoctorLoginIn):
    doc = await db.users.find_one({"email": body.email.lower(), "role": "doctor"}, {"_id": 0})
    if not doc or not verify_pwd(body.password, doc.get("password_hash", "")):
        raise HTTPException(401, "Invalid email or password")
    await db.users.update_one({"id": doc["id"]}, {"$set": {"last_login": now_iso()}})
    token = make_token(doc["id"], "doctor", {"name": doc["name"], "email": doc["email"], "hospital_id": doc.get("hospital_id")}, DOCTOR_TTL_MIN)
    await audit("login.doctor", {"sub": doc["id"], "role": "doctor"})
    return {"token": token, "user": {"id": doc["id"], "role": "doctor", "name": doc["name"], "email": doc["email"], "hospital_name": doc.get("hospital_name")}}

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
        "name": body.name.strip(),
        "phone": phone,
        "date_of_birth": body.date_of_birth,
        "age": age,
        "gender": body.gender,
        "guardian_name": body.guardian_name,
        "guardian_relation": body.guardian_relation,
        "hospital_id": hosp["id"] if hosp else None,
        "hospital_name": hosp["name"] if hosp else None,
        "created_at": now_iso(),
    }
    await db.patients.insert_one(doc.copy())
    # Re-issue full patient token now that record exists
    token = make_token(doc["id"], "patient", {"phone": phone, "name": doc["name"]}, PATIENT_TTL_MIN)
    await audit("patient.register", {"sub": doc["id"], "role": "patient"}, doc["id"])
    return {"token": token, "user": {"id": doc["id"], "role": "patient", "name": doc["name"], "phone": phone}, "patient": serialize_patient(doc)}

@api_router.get("/patient/me")
async def patient_me(u = Depends(current_user)):
    if u.get("role") != "patient":
        raise HTTPException(403, "Patient role required")
    p = await db.patients.find_one({"id": u["sub"]}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient record not found")
    sessions = await db.test_sessions.find({"patient_id": u["sub"]}, {"_id": 0}).sort("created_at", -1).to_list(50)
    return {"patient": serialize_patient(p), "sessions": sessions}

# ── Consent
@api_router.post("/consent")
async def save_consent(body: ConsentIn, u = Depends(current_user)):
    if not all(body.toggles.get(k) for k in ("camera", "storage", "research", "doctor_share")):
        raise HTTPException(400, "All 4 consent toggles must be accepted")
    p = await db.patients.find_one({"id": body.patient_id}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient not found")
    # Patients can only save consent for themselves
    if u.get("role") == "patient" and u["sub"] != body.patient_id:
        raise HTTPException(403, "Cannot save consent for another patient")
    doc = {
        "id": mk_id(), "patient_id": body.patient_id,
        "patient_name": p["name"], "date_of_birth": p.get("date_of_birth", ""),
        "guardian_name": p.get("guardian_name"), "guardian_relation": p.get("guardian_relation"),
        "language": body.language, "app_version": body.app_version, "toggles": body.toggles,
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
    return c or {"exists": False}

# ── Sessions
@api_router.post("/sessions")
async def create_session(body: Dict[str, Any], u = Depends(current_user)):
    patient_id = body.get("patient_id") or (u["sub"] if u.get("role") == "patient" else None)
    if not patient_id: raise HTTPException(400, "patient_id required")
    if u.get("role") == "patient" and u["sub"] != patient_id:
        raise HTTPException(403, "Forbidden")
    p = await db.patients.find_one({"id": patient_id}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient not found")
    doc = {
        "id": mk_id(), "patient_id": patient_id,
        "hospital_id": p.get("hospital_id"), "status": "in_progress",
        "created_at": now_iso(), "completed_at": None, "created_by": u["sub"], "created_role": u.get("role"),
    }
    await db.test_sessions.insert_one(doc.copy())
    await audit("session.create", u, doc["id"], {"patient_id": patient_id})
    return {"id": doc["id"], "patient_id": patient_id, "created_at": doc["created_at"], "status": doc["status"]}

@api_router.post("/sessions/{sid}/results")
async def add_result(sid: str, body: TestResultIn, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    doc = {
        "id": mk_id(), "session_id": sid, "test_name": body.test_name,
        "raw_score": body.raw_score, "normalized_score": body.normalized_score,
        "details": body.details, "created_at": now_iso(),
    }
    await db.test_results.delete_many({"session_id": sid, "test_name": body.test_name})
    await db.test_results.insert_one(doc.copy())
    return {"ok": True, "result_id": doc["id"]}

@api_router.post("/sessions/{sid}/complete")
async def complete_session(sid: str, u = Depends(current_user)):
    s = await db.test_sessions.find_one({"id": sid}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    if u.get("role") == "patient" and s["patient_id"] != u["sub"]:
        raise HTTPException(403, "Forbidden")
    results = await db.test_results.find({"session_id": sid}, {"_id": 0}).to_list(50)
    pred = classify_risk(results)
    pred_doc = {"id": mk_id(), "session_id": sid, **pred, "created_at": now_iso()}
    await db.ai_predictions.delete_many({"session_id": sid})
    await db.ai_predictions.insert_one(pred_doc.copy())
    await db.test_sessions.update_one({"id": sid}, {"$set": {
        "status": "completed", "completed_at": now_iso(),
        "risk_level": pred["risk_level"], "risk_score": pred["risk_score"], "health_score": pred["health_score"],
    }})
    await db.patients.update_one({"id": s["patient_id"]}, {"$set": {
        "last_session_id": sid, "last_risk_level": pred["risk_level"], "last_session_date": now_iso(),
    }})
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
    pred = await db.ai_predictions.find_one({"session_id": sid}, {"_id": 0})
    diag = await db.doctor_diagnoses.find_one({"session_id": sid}, {"_id": 0})
    # Patients get simplified prediction (hide medical_findings details)
    if u.get("role") == "patient" and pred:
        pred = {k: v for k, v in pred.items() if k != "medical_findings"}
    return {"session": s, "patient": serialize_patient(p) if p else None, "results": results, "prediction": pred, "diagnosis": diag}

# ── Doctor endpoints
@api_router.get("/doctor/stats")
async def doctor_stats(u = Depends(current_user)):
    await require_role(u, ["doctor"])
    total_patients = await db.patients.count_documents({})
    completed = await db.test_sessions.count_documents({"status": "completed"})
    urgent = await db.test_sessions.count_documents({"risk_level": "urgent"})
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    today = await db.test_sessions.count_documents({"created_at": {"$gte": today_start}})
    pending_review = await db.test_sessions.count_documents({"status": "completed", "reviewed": {"$ne": True}})
    return {
        "total_patients": total_patients, "completed_sessions": completed,
        "urgent_cases": urgent, "today_sessions": today, "pending_review": pending_review,
    }

@api_router.get("/doctor/patients")
async def doctor_patients(risk: Optional[str] = None, q: Optional[str] = None, u = Depends(current_user)):
    await require_role(u, ["doctor"])
    query: Dict[str, Any] = {}
    if risk:
        query["last_risk_level"] = risk
    if q:
        query["name"] = {"$regex": q, "$options": "i"}
    rows = await db.patients.find(query, {"_id": 0}).sort("created_at", -1).to_list(500)
    return [serialize_patient(r) for r in rows]

@api_router.get("/doctor/patients/{pid}")
async def doctor_patient_detail(pid: str, u = Depends(current_user)):
    await require_role(u, ["doctor"])
    p = await db.patients.find_one({"id": pid}, {"_id": 0})
    if not p: raise HTTPException(404, "Patient not found")
    sessions = await db.test_sessions.find({"patient_id": pid}, {"_id": 0}).sort("created_at", -1).to_list(50)
    return {"patient": serialize_patient(p), "sessions": sessions}

@api_router.post("/doctor/diagnoses")
async def save_diagnosis(body: DiagnosisIn, u = Depends(current_user)):
    await require_role(u, ["doctor"])
    s = await db.test_sessions.find_one({"id": body.session_id}, {"_id": 0})
    if not s: raise HTTPException(404, "Session not found")
    doc = {
        "id": mk_id(), "session_id": body.session_id, "doctor_id": u["sub"], "doctor_name": u.get("name"),
        "diagnosis": body.diagnosis, "treatment": body.treatment, "risk_label": body.risk_label,
        "follow_up_date": body.follow_up_date, "referred_to": body.referred_to,
        "created_at": now_iso(),
    }
    await db.doctor_diagnoses.update_one({"session_id": body.session_id}, {"$set": doc}, upsert=True)
    await db.test_sessions.update_one({"id": body.session_id}, {"$set": {"reviewed": True, "reviewed_at": now_iso(), "reviewed_by": u["sub"]}})
    await audit("diagnosis.save", u, body.session_id, {"diagnosis": body.diagnosis[:80]})
    return {"ok": True, "diagnosis_id": doc["id"]}

# ── Seed defaults
@app.on_event("startup")
async def seed_defaults():
    try:
        hosp = await db.hospitals.find_one({})
        if not hosp:
            hosp_id = mk_id()
            await db.hospitals.insert_one({
                "id": hosp_id, "name": "Aravind Eye Hospital", "location": "Coimbatore, Tamil Nadu",
                "created_at": now_iso(),
            })
            hosp = {"id": hosp_id, "name": "Aravind Eye Hospital"}

        doctor = await db.users.find_one({"role": "doctor"})
        if not doctor:
            await db.users.insert_one({
                "id": mk_id(), "name": "Dr. Meera Sundaram",
                "email": "doctor@aravind.in", "role": "doctor",
                "password_hash": hash_pwd("aravind2026"),
                "hospital_id": hosp["id"], "hospital_name": hosp["name"],
                "created_at": now_iso(),
            })
            logger.info("Seeded default doctor: doctor@aravind.in / aravind2026")
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
