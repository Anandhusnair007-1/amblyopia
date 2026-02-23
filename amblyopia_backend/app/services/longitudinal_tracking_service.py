"""
Amblyopia Care System — Longitudinal Tracking Service
Finds returning patients via face vector similarity.
Calculates improvement trends across screening sessions.
"""
from __future__ import annotations

import base64
import logging
from typing import List, Optional
from uuid import UUID

import numpy as np
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.combined_result import CombinedResult
from app.models.patient import Patient
from app.models.session import ScreeningSession
from app.services.encryption_service import decrypt, encrypt

logger = logging.getLogger(__name__)

SIMILARITY_THRESHOLD = 0.85


def _decode_vector(encrypted_vector: str) -> Optional[np.ndarray]:
    """Decrypt and decode a face vector to numpy array."""
    try:
        plaintext = decrypt(encrypted_vector)
        floats = [float(x) for x in plaintext.split(",")]
        return np.array(floats, dtype=np.float32)
    except Exception as exc:
        logger.warning("Vector decode failed: %s", exc)
        return None


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two vectors."""
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


async def find_existing_patient(
    db: AsyncSession, face_vector: str
) -> Optional[UUID]:
    """
    Compare incoming face vector against all active patients.
    Returns patient_id if cosine similarity >= SIMILARITY_THRESHOLD, else None.
    """
    incoming_vec = _decode_vector(face_vector)
    if incoming_vec is None:
        return None

    result = await db.execute(
        select(Patient).where(
            Patient.is_active == True,
            Patient.face_vector.isnot(None),
        )
    )
    patients = result.scalars().all()

    best_sim = 0.0
    best_patient_id = None

    for patient in patients:
        existing_vec = _decode_vector(patient.face_vector)
        if existing_vec is None:
            continue
        try:
            sim = _cosine_similarity(incoming_vec, existing_vec)
            if sim > best_sim:
                best_sim = sim
                best_patient_id = patient.id
        except Exception:
            continue

    if best_sim >= SIMILARITY_THRESHOLD:
        logger.info("Returning patient found: %s (similarity=%.3f)", best_patient_id, best_sim)
        return best_patient_id
    return None


async def get_patient_trend(
    db: AsyncSession, patient_id: UUID
) -> List[dict]:
    """
    Return risk score trend across all sessions for chart data.
    Sorted oldest to newest.
    """
    result = await db.execute(
        select(ScreeningSession, CombinedResult)
        .outerjoin(CombinedResult, CombinedResult.session_id == ScreeningSession.id)
        .where(ScreeningSession.patient_id == patient_id,
               ScreeningSession.completed_at.isnot(None))
        .order_by(ScreeningSession.started_at.asc())
    )
    rows = result.all()

    trend = []
    for i, (sess, combined) in enumerate(rows):
        trend.append({
            "session_number": i + 1,
            "session_id": str(sess.id),
            "date": sess.started_at.isoformat() if sess.started_at else None,
            "overall_risk_score": float(combined.overall_risk_score) if combined and combined.overall_risk_score else None,
            "gaze_score": float(combined.gaze_score) if combined and combined.gaze_score else None,
            "redgreen_score": float(combined.redgreen_score) if combined and combined.redgreen_score else None,
            "snellen_score": float(combined.snellen_score) if combined and combined.snellen_score else None,
            "severity_grade": combined.severity_grade if combined else None,
            "risk_level": combined.risk_level if combined else None,
        })

    return trend


async def calculate_improvement(
    db: AsyncSession, patient_id: UUID
) -> dict:
    """
    Compare first session to latest session.
    Returns improvement percentage and direction.
    """
    trend = await get_patient_trend(db, patient_id)
    if len(trend) < 2:
        return {
            "can_calculate": False,
            "message": "At least 2 sessions required for improvement tracking",
            "session_count": len(trend),
        }

    first = trend[0]
    latest = trend[-1]

    first_score = first["overall_risk_score"]
    latest_score = latest["overall_risk_score"]

    if first_score is None or latest_score is None:
        return {
            "can_calculate": False,
            "message": "Score data unavailable for comparison",
        }

    # Risk score going DOWN = improvement
    change = first_score - latest_score
    pct_improvement = round((change / first_score) * 100, 1) if first_score > 0 else 0.0

    return {
        "can_calculate": True,
        "patient_id": str(patient_id),
        "total_sessions": len(trend),
        "first_session_date": first["date"],
        "latest_session_date": latest["date"],
        "first_risk_score": first_score,
        "latest_risk_score": latest_score,
        "improvement_percentage": pct_improvement,
        "improved": change > 0,
        "trend": trend,
    }
