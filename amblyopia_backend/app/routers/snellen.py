"""
Snellen router — save results, view history, acuity trend.
POST /api/snellen/result
GET  /api/snellen/history/{patient_id}
GET  /api/snellen/acuity-trend/{patient_id}
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.session import ScreeningSession
from app.models.snellen_result import SnellenResult
from app.schemas.snellen_result import SnellenResultCreate
from app.services import audit_service, screening_service
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/snellen", tags=["snellen"])


@router.post("/result")
async def save_snellen_result(
    body: SnellenResultCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    sn_data = body.model_dump()
    sn = await screening_service.save_snellen_result(db, body.session_id, sn_data)
    await audit_service.log_action(
        db, actor_id=UUID(current_user["sub"]), actor_type="nurse",
        action="SAVE_SNELLEN_RESULT", resource_type="SnellenResult", resource_id=sn.id,
        ip_address=request.client.host, device_id=device_id,
    )
    return standard_response({
        "id": str(sn.id),
        "visual_acuity_right": sn.visual_acuity_right,
        "visual_acuity_left": sn.visual_acuity_left,
        "hesitation_score": float(sn.hesitation_score) if sn.hesitation_score else None,
        "confidence_score": float(sn.confidence_score) if sn.confidence_score else None,
        "needs_doctor_review": sn.needs_doctor_review,
    }, "Snellen result saved", device_id=device_id)


@router.get("/history/{patient_id}")
async def get_snellen_history(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    sessions_q = await db.execute(
        select(ScreeningSession.id, ScreeningSession.started_at)
        .where(ScreeningSession.patient_id == patient_id)
        .order_by(ScreeningSession.started_at.asc())
    )
    rows = sessions_q.all()

    results = []
    for sid, started_at in rows:
        sn_q = await db.execute(select(SnellenResult).where(SnellenResult.session_id == sid))
        sn = sn_q.scalar_one_or_none()
        if sn:
            results.append({
                "session_id": str(sid),
                "screening_date": started_at.isoformat() if started_at else None,
                "visual_acuity_right": sn.visual_acuity_right,
                "visual_acuity_left": sn.visual_acuity_left,
                "hesitation_score": float(sn.hesitation_score) if sn.hesitation_score else None,
                "confidence_score": float(sn.confidence_score) if sn.confidence_score else None,
                "created_at": sn.created_at.isoformat() if sn.created_at else None,
            })

    return standard_response({"history": results, "total": len(results)}, "Snellen history retrieved", device_id=device_id)


@router.get("/acuity-trend/{patient_id}")
async def get_acuity_trend(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    sessions_q = await db.execute(
        select(ScreeningSession.id, ScreeningSession.started_at)
        .where(ScreeningSession.patient_id == patient_id)
        .order_by(ScreeningSession.started_at.asc())
    )
    rows = sessions_q.all()

    trend = []
    for i, (sid, started_at) in enumerate(rows):
        sn_q = await db.execute(select(SnellenResult).where(SnellenResult.session_id == sid))
        sn = sn_q.scalar_one_or_none()
        if sn:
            trend.append({
                "session_number": i + 1,
                "date": started_at.isoformat() if started_at else None,
                "visual_acuity_right": sn.visual_acuity_right,
                "visual_acuity_left": sn.visual_acuity_left,
            })

    return standard_response({"trend": trend, "patient_id": str(patient_id)}, "Acuity trend retrieved", device_id=device_id)
