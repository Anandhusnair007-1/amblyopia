"""
Doctor router — review queue, verdicts, stats.
GET  /api/doctor/review-queue
POST /api/doctor/submit-verdict/{session_id}
GET  /api/doctor/stats
"""
from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_doctor, get_device_id, rate_limit
from app.models.combined_result import CombinedResult
from app.models.doctor_review import DoctorReview
from app.models.session import ScreeningSession
from app.schemas.doctor_review import DoctorVerdictRequest
from app.services import audit_service
from app.services.encryption_service import encrypt_if_not_none
from app.utils.helpers import standard_response, utc_now

router = APIRouter(prefix="/api/doctor", tags=["doctor"])


@router.get("/review-queue")
async def get_review_queue(
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return all sessions needing doctor review, sorted by severity."""
    offset = (page - 1) * page_size
    q = await db.execute(
        select(ScreeningSession, CombinedResult)
        .join(CombinedResult, CombinedResult.session_id == ScreeningSession.id)
        .outerjoin(DoctorReview, DoctorReview.session_id == ScreeningSession.id)
        .where(
            CombinedResult.referral_needed == True,
            DoctorReview.id.is_(None),  # Not yet reviewed
        )
        .order_by(CombinedResult.severity_grade.desc(), ScreeningSession.completed_at.desc())
        .limit(page_size)
        .offset(offset)
    )
    rows = q.all()

    queue = []
    for sess, combined in rows:
        queue.append({
            "session_id": str(sess.id),
            "patient_id": str(sess.patient_id),
            "completed_at": sess.completed_at.isoformat() if sess.completed_at else None,
            "severity_grade": combined.severity_grade,
            "risk_level": combined.risk_level,
            "overall_risk_score": float(combined.overall_risk_score) if combined.overall_risk_score else None,
            "recommendation": combined.recommendation,
            "referral_letter_url": combined.referral_letter_url,
            "qr_code_url": combined.qr_code_url,
        })

    return standard_response({"queue": queue, "total": len(queue), "page": page}, "Review queue retrieved", device_id=device_id)


@router.post("/submit-verdict/{session_id}")
async def submit_verdict(
    session_id: UUID,
    body: DoctorVerdictRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Doctor submits a verdict on a screening case."""
    doctor_id = UUID(current_user["sub"])

    review = DoctorReview(
        session_id=session_id,
        doctor_id=doctor_id,
        verdict=body.verdict,
        encrypted_notes=encrypt_if_not_none(body.notes),
        encrypted_treatment_plan=encrypt_if_not_none(body.treatment_plan),
        diagnosis_code=body.diagnosis_code,
        priority=body.priority,
        status="reviewed",
        reviewed_at=utc_now(),
    )
    db.add(review)
    await db.flush()

    await audit_service.log_action(
        db, actor_id=doctor_id, actor_type="doctor",
        action="SUBMIT_DOCTOR_VERDICT", resource_type="DoctorReview", resource_id=review.id,
        ip_address=request.client.host, device_id=device_id,
        new_value={"verdict": body.verdict, "priority": body.priority, "session_id": str(session_id)},
    )
    return standard_response({"review_id": str(review.id), "verdict": body.verdict}, "Verdict submitted", device_id=device_id)


@router.get("/stats")
async def get_doctor_stats(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return doctor performance statistics."""
    doctor_id = UUID(current_user["sub"])

    total_q = await db.execute(
        select(func.count()).where(DoctorReview.doctor_id == doctor_id)
    )
    total = total_q.scalar() or 0

    week_ago = utc_now() - timedelta(days=7)
    week_q = await db.execute(
        select(func.count()).where(
            DoctorReview.doctor_id == doctor_id,
            DoctorReview.reviewed_at >= week_ago,
        )
    )
    this_week = week_q.scalar() or 0

    pending_q = await db.execute(
        select(func.count())
        .select_from(CombinedResult)
        .outerjoin(DoctorReview, DoctorReview.session_id == CombinedResult.session_id)
        .where(CombinedResult.referral_needed == True, DoctorReview.id.is_(None))
    )
    pending = pending_q.scalar() or 0

    return standard_response({
        "doctor_id": str(doctor_id),
        "total_reviews": total,
        "reviews_this_week": this_week,
        "pending_in_queue": pending,
    }, "Stats retrieved", device_id=device_id)
