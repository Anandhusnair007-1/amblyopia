#!/usr/bin/env python3
"""Seed hospital-pilot demo records for patient, doctor, admin, and referral flows.

Usage from repo root:
  python3 backend/scripts/seed_pilot_demo.py

The script is idempotent. It removes only records tagged with demo_seed="pilot_v1".
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import bcrypt
from dotenv import load_dotenv
from pymongo import MongoClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from security.crypto import encrypt_pii, hash_lookup  # noqa: E402

DEMO_SEED = "pilot_v1"
HOSPITAL_ID = "demo-hospital-aravind"
DOCTOR_ID = "demo-doctor-meera"
ADMIN_ID = "demo-admin-ops"
FIELD_ID = "demo-field-worker"

TEST_ORDER = ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex"]


def now_iso(offset: timedelta | None = None) -> str:
    dt = datetime.now(timezone.utc) + (offset or timedelta())
    return dt.isoformat()


def env_mongo_url() -> str:
    url = os.environ.get("MONGO_URL", "mongodb://localhost:27017")
    return url.replace("://mongo:", "://localhost:")


def hash_pwd(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def patient_doc(pid: str, name: str, phone: str, dob: str, gender: str, guardian: str, mrn: str | None, risk: str, last_session_id: str):
    age = max(0, datetime.now(timezone.utc).year - int(dob[:4]))
    doc = {
        "id": pid,
        "name": encrypt_pii(name),
        "phone": encrypt_pii(phone),
        "phone_hash": hash_lookup(phone),
        "name_search_hash": hash_lookup(name.strip().lower()),
        "date_of_birth": encrypt_pii(dob),
        "age": age,
        "gender": gender,
        "guardian_name": encrypt_pii(guardian),
        "guardian_relation": encrypt_pii("Parent"),
        "hospital_id": HOSPITAL_ID,
        "hospital_name": "Aravind Eye Hospital",
        "last_session_id": last_session_id,
        "last_risk_level": risk,
        "last_session_date": now_iso(timedelta(days=-1)),
        "created_at": now_iso(timedelta(days=-7)),
        "demo_seed": DEMO_SEED,
    }
    if mrn:
        doc["mrn"] = mrn
    return doc


def result_docs(session_id: str, profile: str = "normal"):
    values = {
        "normal": {
            "visual_acuity": (0.15, 0.15, {"left_logmar": 0.1, "right_logmar": 0.15}),
            "gaze": (2.0, 0.1, {"deviation_px": 2, "direction": "none"}),
            "hirschberg": (1.0, 0.05, {"corneal_reflex_offset_mm": 0.5}),
            "prism": (1.0, 0.05, {"prism_diopters": 1}),
            "titmus": (60.0, 0.1, {"arc_seconds": 60}),
            "red_reflex": (0.1, 0.05, {"asymmetry": 0.1}),
        },
        "urgent": {
            "visual_acuity": (0.85, 0.85, {"left_logmar": 0.15, "right_logmar": 0.85}),
            "gaze": (32.0, 0.9, {"deviation_px": 32, "direction": "esotropia"}),
            "hirschberg": (5.5, 0.8, {"corneal_reflex_offset_mm": 5.5}),
            "prism": (24.0, 0.9, {"prism_diopters": 24}),
            "titmus": (400.0, 0.75, {"arc_seconds": 400}),
            "red_reflex": (0.7, 0.8, {"asymmetry": 0.7}),
        },
        "moderate": {
            "visual_acuity": (0.45, 0.55, {"left_logmar": 0.2, "right_logmar": 0.45}),
            "gaze": (10.0, 0.45, {"deviation_px": 10, "direction": "intermittent exotropia"}),
            "hirschberg": (2.5, 0.35, {"corneal_reflex_offset_mm": 2.5}),
            "prism": (8.0, 0.4, {"prism_diopters": 8}),
            "titmus": (160.0, 0.4, {"arc_seconds": 160}),
            "red_reflex": (0.25, 0.25, {"asymmetry": 0.25}),
        },
    }[profile]
    return [
        {
            "id": f"demo-result-{session_id}-{name}",
            "session_id": session_id,
            "test_name": name,
            "raw_score": raw,
            "normalized_score": norm,
            "details": details,
            "created_at": now_iso(timedelta(days=-1, minutes=i)),
            "demo_seed": DEMO_SEED,
        }
        for i, (name, (raw, norm, details)) in enumerate(values.items())
    ]


def prediction_doc(session_id: str, risk: str):
    score = {"normal": 0.1, "mild": 0.4, "moderate": 0.7, "urgent": 0.95}[risk]
    findings = {
        "normal": ["No major screening concern on this pass."],
        "moderate": ["Reduced acuity and ocular alignment findings need doctor review."],
        "urgent": ["Large gaze deviation detected.", "Red reflex asymmetry requires prompt ophthalmology review."],
    }.get(risk, ["Screening needs clinical review."])
    medical_findings = [] if risk == "normal" else [
        {
            "test": "Gaze Deviation",
            "metric": "max_deviation_px",
            "value": "32 px" if risk == "urgent" else "10 px",
            "threshold": "Screening reference: <= 4 px",
            "interpretation": "Possible ocular misalignment. Confirm clinically.",
            "severity": risk,
        }
    ]
    return {
        "id": f"demo-prediction-{session_id}",
        "session_id": session_id,
        "risk_level": risk,
        "risk_score": score,
        "health_score": round((1 - score) * 100, 1),
        "findings": findings,
        "medical_findings": medical_findings,
        "clinical_rule_version": "demo-pilot-v1",
        "test_algorithm_version": "ambyo-core-demo",
        "prediction_revision_number": 1,
        "supersedes_prediction_id": None,
        "app_version": "demo",
        "quality_model_version": "demo",
        "deviation_model_version": "demo",
        "dataset_version": "demo",
        "prediction_created_at": now_iso(timedelta(days=-1)),
        "demo_seed": DEMO_SEED,
    }


def main() -> None:
    global HOSPITAL_ID
    load_dotenv(BACKEND_DIR / ".env")
    client = MongoClient(env_mongo_url())
    db = client[os.environ.get("DB_NAME", "ambyoai")]

    for collection in [
        "patients", "test_sessions", "test_results", "ai_predictions", "doctor_diagnoses",
        "consent_records", "referrals", "follow_ups", "audit_logs",
    ]:
        db[collection].delete_many({"demo_seed": DEMO_SEED})

    existing_hospital = db.hospitals.find_one({}, {"_id": 0})
    if existing_hospital:
        HOSPITAL_ID = existing_hospital["id"]
        db.hospitals.update_one(
            {"id": HOSPITAL_ID},
            {"$set": {
                "name": existing_hospital.get("name") or "Aravind Eye Hospital",
                "location": existing_hospital.get("location") or "Coimbatore, Tamil Nadu",
                "address": existing_hospital.get("address") or "Coimbatore, Tamil Nadu",
                "contact": existing_hospital.get("contact") or "+91-000-000-0000",
                "status": existing_hospital.get("status") or "active",
            }},
        )
    else:
        db.hospitals.update_one(
            {"id": HOSPITAL_ID},
            {"$set": {
                "id": HOSPITAL_ID,
                "name": "Aravind Eye Hospital",
                "location": "Coimbatore, Tamil Nadu",
                "address": "Coimbatore, Tamil Nadu",
                "contact": "+91-000-000-0000",
                "status": "active",
                "created_at": now_iso(timedelta(days=-30)),
                "demo_seed": DEMO_SEED,
            }},
            upsert=True,
        )

    staff = [
        (DOCTOR_ID, "Dr. Meera Sundaram", "doctor@aravind.in", "doctor", "aravind2026"),
        (ADMIN_ID, "Hospital Ops Admin", "admin@aravind.in", "admin", "admin2026"),
        (FIELD_ID, "Screening Camp Worker", "field@aravind.in", "field_worker", "field2026"),
    ]
    for uid, name, email, role, password in staff:
        db.users.update_one(
            {"email": email},
            {"$set": {
                "id": uid,
                "name": name,
                "email": email,
                "role": role,
                "password_hash": hash_pwd(password),
                "hospital_id": HOSPITAL_ID,
                "hospital_name": "Aravind Eye Hospital",
                "created_at": now_iso(timedelta(days=-30)),
                "demo_seed": DEMO_SEED,
            }},
            upsert=True,
        )
        db.staff_users.update_one(
            {"user_id": uid},
            {"$set": {
                "id": f"staff-{uid}",
                "user_id": uid,
                "hospital_id": HOSPITAL_ID,
                "branch_id": None,
                "camp_ids": [],
                "name": encrypt_pii(name),
                "email": email,
                "role": role,
                "active": True,
                "created_at": now_iso(timedelta(days=-30)),
                "demo_seed": DEMO_SEED,
            }},
            upsert=True,
        )

    patients = [
        ("demo-patient-normal", "Asha Kumar", "9895316420", "2018-03-12", "female", "Priya Kumar", "MRN-DEMO-001", "normal", "demo-session-normal"),
        ("demo-patient-urgent", "Rahul Nair", "9895316421", "2017-08-25", "male", "Anita Nair", "MRN-DEMO-URG", "urgent", "demo-session-urgent"),
        ("demo-patient-pending", "Meena Ravi", "9895316422", "2019-01-05", "female", "Karthik Ravi", None, "moderate", "demo-session-pending"),
        ("demo-patient-resume", "Ishan Thomas", "9895316423", "2020-06-18", "male", "Mary Thomas", None, "normal", "demo-session-resume"),
    ]
    db.patients.insert_many([patient_doc(*row) for row in patients])

    for pid, name, _phone, dob, _gender, guardian, _mrn, _risk, _sid in patients:
        db.consent_records.insert_one({
            "id": f"demo-consent-{pid}",
            "patient_id": pid,
            "patient_name": encrypt_pii(name),
            "date_of_birth": encrypt_pii(dob),
            "guardian_name": encrypt_pii(guardian),
            "guardian_relation": encrypt_pii("Parent"),
            "language": "en",
            "app_version": "demo",
            "consent_version": "pilot-v1",
            "consent_text_hash": "demo-consent-text",
            "consent_scope": {
                "camera": True,
                "storage": True,
                "doctor_share": True,
                "referral_communication": True,
                "analytics_optional": False,
            },
            "consent_date": now_iso(timedelta(days=-2)),
            "consent_by": pid,
            "demo_seed": DEMO_SEED,
        })

    completed = [
        ("demo-session-normal", "demo-patient-normal", "normal", True, timedelta(days=-2)),
        ("demo-session-urgent", "demo-patient-urgent", "urgent", False, timedelta(days=-1, hours=-2)),
        ("demo-session-pending", "demo-patient-pending", "moderate", False, timedelta(hours=-6)),
    ]
    for sid, pid, risk, reviewed, offset in completed:
        created = now_iso(offset)
        completed_at = now_iso(offset + timedelta(minutes=8))
        db.test_sessions.insert_one({
            "id": sid,
            "patient_id": pid,
            "hospital_id": HOSPITAL_ID,
            "branch_id": None,
            "camp_id": "demo-school-camp",
            "device_id": "demo-browser",
            "status": "completed",
            "created_at": created,
            "completed_at": completed_at,
            "created_by": pid,
            "created_role": "patient",
            "created_by_role": "patient",
            "risk_level": risk,
            "risk_score": {"normal": 0.1, "moderate": 0.7, "urgent": 0.95}[risk],
            "health_score": {"normal": 90, "moderate": 30, "urgent": 5}[risk],
            "reviewed": reviewed,
            "reviewed_at": now_iso(timedelta(days=-1)) if reviewed else None,
            "reviewed_by": DOCTOR_ID if reviewed else None,
            "demo_seed": DEMO_SEED,
        })
        db.test_results.insert_many(result_docs(sid, risk if risk in ("normal", "urgent", "moderate") else "normal"))
        db.ai_predictions.insert_one(prediction_doc(sid, risk))

    db.doctor_diagnoses.insert_one({
        "id": "demo-diagnosis-normal",
        "session_id": "demo-session-normal",
        "doctor_id": DOCTOR_ID,
        "doctor_name": "Dr. Meera Sundaram",
        "diagnosis": "No major screening concern on this pass.",
        "treatment": "Routine rescreening in 6-12 months.",
        "risk_label": "No major screening concern",
        "follow_up_date": (datetime.now(timezone.utc) + timedelta(days=180)).date().isoformat(),
        "referred_to": "",
        "confirmed_by_doctor": True,
        "override_reason": "",
        "ai_agreement": "agree",
        "diagnosis_revision_number": 1,
        "created_at": now_iso(timedelta(days=-1)),
        "demo_seed": DEMO_SEED,
    })

    db.test_sessions.insert_one({
        "id": "demo-session-resume",
        "patient_id": "demo-patient-resume",
        "hospital_id": HOSPITAL_ID,
        "status": "in_progress",
        "created_at": now_iso(timedelta(hours=-3)),
        "completed_at": None,
        "created_by": "demo-patient-resume",
        "created_role": "patient",
        "created_by_role": "patient",
        "demo_seed": DEMO_SEED,
    })
    db.test_results.insert_many(result_docs("demo-session-resume", "normal")[:2])

    overdue_ref = {
        "id": "demo-referral-overdue",
        "patient_id": "demo-patient-urgent",
        "session_id": "demo-session-urgent",
        "hospital_id": HOSPITAL_ID,
        "camp_id": "demo-school-camp",
        "urgency": "urgent",
        "status": "contacting",
        "doctor_review_required": True,
        "assigned_to": ADMIN_ID,
        "notes": "Demo urgent referral for SLA and contact timeline review.",
        "created_at": now_iso(timedelta(days=-2)),
        "updated_at": now_iso(timedelta(hours=-8)),
        "sla_due_at": now_iso(timedelta(days=-1)),
        "sla_status": "breached",
        "contact_attempts": [
            {
                "at": now_iso(timedelta(days=-1, hours=-2)),
                "by_user_id": ADMIN_ID,
                "channel": "phone",
                "note": "Guardian did not answer. Left SMS callback request.",
                "outcome": "no_answer",
            },
            {
                "at": now_iso(timedelta(hours=-8)),
                "by_user_id": ADMIN_ID,
                "channel": "sms",
                "note": "Shared referral desk number and requested same-day appointment.",
                "outcome": "message_sent",
            },
        ],
        "next_follow_up_at": now_iso(timedelta(hours=2)),
        "appointment_at": None,
        "escalation_flag": True,
        "demo_seed": DEMO_SEED,
    }
    db.referrals.insert_one(overdue_ref)
    db.follow_ups.insert_one({
        "id": "demo-followup-overdue",
        "patient_id": "demo-patient-urgent",
        "session_id": "demo-session-urgent",
        "referral_id": "demo-referral-overdue",
        "hospital_id": HOSPITAL_ID,
        "due_date": now_iso(timedelta(hours=-4)),
        "status": "open",
        "type": "urgent_referral_contact",
        "notes": "Call guardian and confirm appointment.",
        "created_at": now_iso(timedelta(days=-1)),
        "updated_at": now_iso(timedelta(days=-1)),
        "demo_seed": DEMO_SEED,
    })

    db.audit_logs.insert_one({
        "id": "demo-audit-export",
        "action": "session.export",
        "user_id": DOCTOR_ID,
        "user_role": "doctor",
        "target_id": "demo-session-normal",
        "details": {"export_type": "medical_pdf"},
        "timestamp": now_iso(timedelta(hours=-4)),
        "demo_seed": DEMO_SEED,
    })

    print("Seeded hospital pilot demo data.")
    print("Doctor login: doctor@aravind.in / aravind2026")
    print("Admin login:  admin@aravind.in / admin2026")
    print("Field login:  field@aravind.in / field2026")
    print("Patient OTP phones: 9895316420 normal, 9895316421 urgent, 9895316422 pending, 9895316423 resume; OTP 1234")


if __name__ == "__main__":
    main()
