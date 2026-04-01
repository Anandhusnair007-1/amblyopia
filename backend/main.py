from datetime import datetime, timedelta, timezone, date
import os

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext

import json

from api.common import api_success
from api.models import router as model_router
from api.sync import router as sync_router
from database import Base, engine, get_session
from models import DoctorUser, PredictionRecord, SyncedSession
from training.scheduler import start_scheduler

JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_ALGORITHM = "HS256"
TOKEN_TTL_HOURS = 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/doctor/login")


def _require_doctor(token: str = Depends(oauth2_scheme)) -> str:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="invalid token")
        return username
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="invalid token") from exc


def _ensure_default_doctor():
    """Create default doctor user if none exists. CHANGE PASSWORD BEFORE CLINICAL PILOT."""
    with get_session() as session:
        existing = session.query(DoctorUser).filter(DoctorUser.username == "doctor").one_or_none()
        if existing is None:
            session.add(
                DoctorUser(
                    username="doctor",
                    password_hash=pwd_context.hash("doctor123"),  # Change before Aravind handoff
                    full_name="Default Doctor",
                )
            )


app = FastAPI(title="AmbyoAI Backend")
app.include_router(sync_router)
app.include_router(model_router)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    start_scheduler()
    _ensure_default_doctor()


@app.get("/health")
def health():
    return api_success(
        {
            "status": "ok",
            "service": "ambyoai-backend",
            "version": "1.0.0",
        }
    )


@app.get("/health/detailed")
def health_detailed():
    return api_success(
        {
            "status": "ok",
            "service": "ambyoai-backend",
            "version": "1.0.0",
            "features": {
                "doctor_auth": True,
                "model_registry": True,
                "sync_results": True,
                "sync_images": True,
            },
        },
        message="backend healthy",
    )


@app.post("/api/doctor/login")
def doctor_login(form_data: OAuth2PasswordRequestForm = Depends()):
    with get_session() as session:
        user = session.query(DoctorUser).filter(DoctorUser.username == form_data.username).one_or_none()
        if user is None or not pwd_context.verify(form_data.password, user.password_hash):
            raise HTTPException(status_code=401, detail="invalid credentials")

    expires_at = datetime.now(timezone.utc) + timedelta(hours=TOKEN_TTL_HOURS)
    token = jwt.encode(
        {"sub": form_data.username, "exp": expires_at},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM,
    )
    return api_success(
        {
            "access_token": token,
            "token_type": "bearer",
            "expires_at": expires_at.isoformat(),
        },
        message="doctor login successful",
    )


@app.get("/api/doctor/patients")
def doctor_patients(username: str = Depends(_require_doctor)):
    with get_session() as session:
        sessions = session.query(SyncedSession).order_by(SyncedSession.test_date.desc()).all()

        output = []
        for item in sessions:
            payload = {}
            try:
                payload = json.loads(item.payload_json or "{}")
            except json.JSONDecodeError:
                payload = {}

            prediction = item.prediction
            output.append(
                {
                    "session_id": item.hashed_session_id,
                    "hashed_session_id": item.hashed_session_id,
                    "device_id": item.device_id,
                    "test_date": item.test_date.isoformat(),
                    "age_group": item.age_group,
                    "test_count": payload.get("test_count", None),
                    "patient_name": payload.get("patient_name", "Unknown"),
                    "patient_age": payload.get("patient_age", None),
                    "patient_phone": payload.get("patient_phone", None),
                    "risk_score": prediction.risk_score if prediction else None,
                    "risk_level": prediction.risk_level if prediction else None,
                    "label": item.label,
                    "diagnosed": True if item.doctor_notes else False,
                    "doctor_notes": item.doctor_notes,
                }
            )

        return api_success(output)


@app.get("/api/doctor/urgent")
def doctor_urgent(username: str = Depends(_require_doctor)):
    with get_session() as session:
        rows = (
            session.query(SyncedSession)
            .join(PredictionRecord, PredictionRecord.session_id == SyncedSession.id)
            .filter(PredictionRecord.risk_level == "URGENT")
            .order_by(SyncedSession.test_date.desc())
            .all()
        )

        output = []
        for item in rows:
            payload = {}
            try:
                payload = json.loads(item.payload_json or "{}")
            except json.JSONDecodeError:
                payload = {}

            prediction = item.prediction
            output.append(
                {
                    "session_id": item.hashed_session_id,
                    "hashed_session_id": item.hashed_session_id,
                    "device_id": item.device_id,
                    "test_date": item.test_date.isoformat(),
                    "patient_name": payload.get("patient_name", "Unknown"),
                    "patient_age": payload.get("patient_age", None),
                    "patient_phone": payload.get("patient_phone", None),
                    "risk_score": prediction.risk_score if prediction else None,
                    "risk_level": prediction.risk_level if prediction else "URGENT",
                    "label": item.label,
                    "doctor_notes": item.doctor_notes,
                }
            )

        return api_success(output)


@app.get("/api/doctor/stats")
def doctor_stats(username: str = Depends(_require_doctor)):
    with get_session() as session:
        total = session.query(SyncedSession).count()
        urgent = (
            session.query(SyncedSession)
            .join(PredictionRecord, PredictionRecord.session_id == SyncedSession.id)
            .filter(PredictionRecord.risk_level == "URGENT")
            .count()
        )
        today_start = datetime.combine(date.today(), datetime.min.time(), tzinfo=timezone.utc)
        today_end = today_start + timedelta(days=1)
        screened_today = (
            session.query(SyncedSession)
            .filter(SyncedSession.test_date >= today_start)
            .filter(SyncedSession.test_date < today_end)
            .count()
        )

        return api_success(
            {
                "total_patients": total,
                "urgent_cases": urgent,
                "screened_today": screened_today,
            }
        )


@app.get("/api/doctor/reports/{session_id}")
def doctor_report(session_id: str, username: str = Depends(_require_doctor)):
    with get_session() as session:
        report = (
            session.query(SyncedSession)
            .filter(SyncedSession.hashed_session_id == session_id)
            .one_or_none()
        )
        if report is None:
            raise HTTPException(status_code=404, detail="report not found")
        try:
            results = json.loads(report.payload_json or "{}")
        except json.JSONDecodeError:
            results = {}
        return api_success(
            {
                "session_id": report.hashed_session_id,
                "device_id": report.device_id,
                "test_date": report.test_date.isoformat(),
                "results": results,
                "risk_score": report.prediction.risk_score if report.prediction else None,
                "risk_level": report.prediction.risk_level if report.prediction else None,
                "label": report.label,
                "doctor_notes": report.doctor_notes,
            }
        )


@app.post("/api/doctor/diagnosis")
def doctor_diagnosis(payload: dict, username: str = Depends(_require_doctor)):
    session_id = payload.get("session_id")
    label = payload.get("label")
    notes = payload.get("doctor_notes")
    if session_id is None or label is None:
        raise HTTPException(status_code=400, detail="session_id and label are required")

    with get_session() as session:
        report = (
            session.query(SyncedSession)
            .filter(SyncedSession.hashed_session_id == session_id)
            .one_or_none()
        )
        if report is None:
            raise HTTPException(status_code=404, detail="report not found")
        report.label = int(label)
        report.doctor_notes = notes
        return api_success({"status": "saved"}, message="diagnosis saved")
