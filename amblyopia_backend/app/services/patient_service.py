"""
Amblyopia Care System — Patient Service
CRUD operations for de-identified patients.
Face vector comparison for longitudinal tracking.
"""
from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.combined_result import CombinedResult
from app.models.patient import Patient
from app.models.session import ScreeningSession
from app.services.encryption_service import decrypt_if_not_none, encrypt_if_not_none


async def create_patient(
    db: AsyncSession,
    age_group: str,
    village_id: UUID,
    face_vector: Optional[str] = None,
) -> Patient:
    """Create a new de-identified patient record."""
    encrypted_vector = encrypt_if_not_none(face_vector)
    patient = Patient(
        age_group=age_group,
        village_id=village_id,
        face_vector=encrypted_vector,
    )
    db.add(patient)
    await db.flush()
    return patient


async def get_patient(db: AsyncSession, patient_id: UUID) -> Patient:
    """Retrieve a patient by UUID. Raises 404 if not found."""
    result = await db.execute(
        select(Patient).where(Patient.id == patient_id, Patient.is_active == True)
    )
    patient = result.scalar_one_or_none()
    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )
    return patient


async def get_patient_history(
    db: AsyncSession, patient_id: UUID
) -> dict:
    """Return full longitudinal screening history for a patient."""
    patient = await get_patient(db, patient_id)

    sessions_result = await db.execute(
        select(ScreeningSession, CombinedResult)
        .outerjoin(CombinedResult, CombinedResult.session_id == ScreeningSession.id)
        .where(ScreeningSession.patient_id == patient_id)
        .order_by(ScreeningSession.started_at.desc())
    )
    rows = sessions_result.all()

    sessions = []
    for sess, combined in rows:
        entry = {
            "session_id": str(sess.id),
            "started_at": sess.started_at.isoformat() if sess.started_at else None,
            "completed_at": sess.completed_at.isoformat() if sess.completed_at else None,
            "lighting_condition": sess.lighting_condition,
            "severity_grade": combined.severity_grade if combined else None,
            "risk_level": combined.risk_level if combined else None,
            "overall_risk_score": float(combined.overall_risk_score) if combined and combined.overall_risk_score else None,
            "referral_needed": combined.referral_needed if combined else False,
        }
        sessions.append(entry)

    return {
        "patient": {
            "id": str(patient.id),
            "age_group": patient.age_group,
            "village_id": str(patient.village_id) if patient.village_id else None,
            "total_screenings": patient.total_screenings,
            "last_screened_at": patient.last_screened_at.isoformat() if patient.last_screened_at else None,
        },
        "sessions": sessions,
        "total": len(sessions),
    }


async def update_face_vector(
    db: AsyncSession, patient_id: UUID, face_vector: str
) -> Patient:
    """Update the encrypted face vector for a patient."""
    patient = await get_patient(db, patient_id)
    patient.face_vector = encrypt_if_not_none(face_vector)
    await db.flush()
    return patient


async def increment_screening_count(
    db: AsyncSession, patient_id: UUID
) -> None:
    """Increment total_screenings and update last_screened_at."""
    patient = await get_patient(db, patient_id)
    patient.total_screenings = (patient.total_screenings or 0) + 1
    patient.last_screened_at = datetime.utcnow()
    await db.flush()
