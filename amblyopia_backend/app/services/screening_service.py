"""
Amblyopia Care System — Screening Service
Orchestrates session creation, result storage, and combined score calculation.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.combined_result import CombinedResult
from app.models.gaze_result import GazeResult
from app.models.redgreen_result import RedgreenResult
from app.models.session import ScreeningSession
from app.models.snellen_result import SnellenResult
from app.models.patient import Patient
from app.services import scoring_engine as se
from app.services.audit_service import log_action
from app.services.encryption_service import encrypt_if_not_none
from app.utils.helpers import utc_now


async def start_session(
    db: AsyncSession,
    patient_id: UUID,
    nurse_id: UUID,
    village_id: UUID,
    device_id: str,
    gps_lat: Optional[float],
    gps_lng: Optional[float],
    lighting_condition: str,
    battery_level: Optional[int],
    internet_available: bool,
    actor_ip: str = "unknown",
) -> ScreeningSession:
    """Create a new screening session record."""
    session = ScreeningSession(
        patient_id=patient_id,
        nurse_id=nurse_id,
        village_id=village_id,
        device_id=device_id,
        started_at=utc_now(),
        gps_lat=gps_lat,
        gps_lng=gps_lng,
        lighting_condition=lighting_condition,
        battery_level=battery_level,
        internet_available=internet_available,
        sync_status="pending",
    )
    db.add(session)
    await db.flush()

    await log_action(
        db=db, actor_id=nurse_id, actor_type="nurse",
        action="START_SCREENING_SESSION",
        resource_type="ScreeningSession", resource_id=session.id,
        ip_address=actor_ip, device_id=device_id,
        new_value={"patient_id": str(patient_id), "village_id": str(village_id)},
    )

    return session


async def save_gaze_result(
    db: AsyncSession, session_id: UUID, gaze_data: dict
) -> GazeResult:
    """Save gaze test result and determine if doctor review is needed."""
    # Get patient age_group from session -> patient
    result_q = await db.execute(
        select(ScreeningSession, Patient)
        .join(Patient, Patient.id == ScreeningSession.patient_id)
        .where(ScreeningSession.id == session_id)
    )
    row = result_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    sess, patient = row

    confidence = gaze_data.get("confidence_score")
    gaze_score = se.calculate_gaze_score(
        gaze_data.get("gaze_asymmetry_score"),
        gaze_data.get("left_fixation_stability"),
        gaze_data.get("right_fixation_stability"),
        gaze_data.get("blink_asymmetry"),
        confidence,
    )
    flag = se.needs_doctor_review(
        confidence, None, None, False, gaze_score, patient.age_group
    )

    gr = GazeResult(
        session_id=session_id,
        **{k: v for k, v in gaze_data.items()
           if k != "session_id" and hasattr(GazeResult, k)},
        needs_doctor_review=flag,
    )
    db.add(gr)
    await db.flush()
    return gr


async def save_redgreen_result(
    db: AsyncSession, session_id: UUID, rg_data: dict
) -> RedgreenResult:
    """Save red-green dichoptic result."""
    result_q = await db.execute(
        select(ScreeningSession, Patient)
        .join(Patient, Patient.id == ScreeningSession.patient_id)
        .where(ScreeningSession.id == session_id)
    )
    row = result_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    sess, patient = row

    confidence = rg_data.get("confidence_score")
    suppression = rg_data.get("suppression_flag", False)
    rg_score = se.calculate_redgreen_score(
        rg_data.get("asymmetry_ratio"),
        rg_data.get("binocular_score"),
        suppression,
        rg_data.get("constriction_amount_left"),
        rg_data.get("constriction_amount_right"),
        confidence,
    )
    flag = se.needs_doctor_review(None, confidence, None, suppression, rg_score, patient.age_group)

    rg = RedgreenResult(
        session_id=session_id,
        **{k: v for k, v in rg_data.items()
           if k != "session_id" and hasattr(RedgreenResult, k)},
        needs_doctor_review=flag,
    )
    db.add(rg)
    await db.flush()
    return rg


async def save_snellen_result(
    db: AsyncSession, session_id: UUID, sn_data: dict
) -> SnellenResult:
    """Save Snellen visual acuity result."""
    result_q = await db.execute(
        select(ScreeningSession, Patient)
        .join(Patient, Patient.id == ScreeningSession.patient_id)
        .where(ScreeningSession.id == session_id)
    )
    row = result_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    sess, patient = row

    confidence = sn_data.get("confidence_score")
    sn_score = se.calculate_snellen_score(
        sn_data.get("visual_acuity_right"),
        sn_data.get("visual_acuity_left"),
        sn_data.get("hesitation_score"),
        confidence,
        patient.age_group,
    )
    flag = se.needs_doctor_review(None, None, confidence, False, sn_score, patient.age_group)

    sn = SnellenResult(
        session_id=session_id,
        **{k: v for k, v in sn_data.items()
           if k != "session_id" and hasattr(SnellenResult, k)},
        needs_doctor_review=flag,
    )
    db.add(sn)
    await db.flush()
    return sn


async def complete_session(
    db: AsyncSession,
    session_id: UUID,
    nurse_id: UUID,
    device_id: str,
    actor_ip: str = "unknown",
) -> CombinedResult:
    """
    Complete a session: gather all test results, compute combined score,
    assign severity grade. Create referral if grade >= 2.
    """
    # Load session + patient
    result_q = await db.execute(
        select(ScreeningSession, Patient)
        .join(Patient, Patient.id == ScreeningSession.patient_id)
        .where(ScreeningSession.id == session_id)
    )
    row = result_q.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    session, patient = row

    # Load individual results
    gaze_q = await db.execute(select(GazeResult).where(GazeResult.session_id == session_id))
    rg_q = await db.execute(select(RedgreenResult).where(RedgreenResult.session_id == session_id))
    sn_q = await db.execute(select(SnellenResult).where(SnellenResult.session_id == session_id))

    gaze = gaze_q.scalar_one_or_none()
    rg = rg_q.scalar_one_or_none()
    sn = sn_q.scalar_one_or_none()

    # Calculate scores
    gaze_score = se.calculate_gaze_score(
        float(gaze.gaze_asymmetry_score) if gaze and gaze.gaze_asymmetry_score else None,
        float(gaze.left_fixation_stability) if gaze and gaze.left_fixation_stability else None,
        float(gaze.right_fixation_stability) if gaze and gaze.right_fixation_stability else None,
        float(gaze.blink_asymmetry) if gaze and gaze.blink_asymmetry else None,
        float(gaze.confidence_score) if gaze and gaze.confidence_score else None,
    ) if gaze else None

    rg_score = se.calculate_redgreen_score(
        float(rg.asymmetry_ratio) if rg and rg.asymmetry_ratio else None,
        rg.binocular_score if rg else None,
        rg.suppression_flag if rg else False,
        float(rg.constriction_amount_left) if rg and rg.constriction_amount_left else None,
        float(rg.constriction_amount_right) if rg and rg.constriction_amount_right else None,
        float(rg.confidence_score) if rg and rg.confidence_score else None,
    ) if rg else None

    sn_score = se.calculate_snellen_score(
        sn.visual_acuity_right if sn else None,
        sn.visual_acuity_left if sn else None,
        float(sn.hesitation_score) if sn and sn.hesitation_score else None,
        float(sn.confidence_score) if sn and sn.confidence_score else None,
        patient.age_group,
    ) if sn else None

    combined = se.calculate_combined_score(gaze_score, rg_score, sn_score, patient.age_group)
    grading = se.assign_severity_grade(combined)

    combined_result = CombinedResult(
        session_id=session_id,
        gaze_score=gaze_score,
        redgreen_score=rg_score,
        snellen_score=sn_score,
        overall_risk_score=combined,
        severity_grade=grading["severity_grade"],
        risk_level=grading["risk_level"],
        recommendation=grading["recommendation"],
        referral_needed=grading["referral_needed"],
    )
    db.add(combined_result)

    # Mark session complete
    session.completed_at = utc_now()
    session.sync_status = "synced"
    await db.flush()

    # Update patient stats
    patient.total_screenings = (patient.total_screenings or 0) + 1
    patient.last_screened_at = utc_now()
    await db.flush()

    await log_action(
        db=db, actor_id=nurse_id, actor_type="nurse",
        action="COMPLETE_SCREENING_SESSION",
        resource_type="ScreeningSession", resource_id=session_id,
        ip_address=actor_ip, device_id=device_id,
        new_value={
            "severity_grade": grading["severity_grade"],
            "risk_level": grading["risk_level"],
            "referral_needed": grading["referral_needed"],
        },
    )
    return combined_result


async def get_session_report(
    db: AsyncSession, session_id: UUID
) -> dict:
    """Return full report for a session."""
    sess_q = await db.execute(select(ScreeningSession).where(ScreeningSession.id == session_id))
    session = sess_q.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    combined_q = await db.execute(select(CombinedResult).where(CombinedResult.session_id == session_id))
    gaze_q = await db.execute(select(GazeResult).where(GazeResult.session_id == session_id))
    rg_q = await db.execute(select(RedgreenResult).where(RedgreenResult.session_id == session_id))
    sn_q = await db.execute(select(SnellenResult).where(SnellenResult.session_id == session_id))

    combined = combined_q.scalar_one_or_none()
    gaze = gaze_q.scalar_one_or_none()
    rg = rg_q.scalar_one_or_none()
    sn = sn_q.scalar_one_or_none()

    def to_dict(obj):
        if obj is None:
            return None
        return {c.name: getattr(obj, c.name) for c in obj.__table__.columns}

    return {
        "session": to_dict(session),
        "combined_result": to_dict(combined),
        "gaze_result": to_dict(gaze),
        "redgreen_result": to_dict(rg),
        "snellen_result": to_dict(sn),
    }
