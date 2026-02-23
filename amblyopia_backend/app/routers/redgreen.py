"""
Red-Green router — save results, view history.
POST /api/redgreen/result
GET  /api/redgreen/history/{patient_id}
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.redgreen_result import RedgreenResult
from app.models.session import ScreeningSession
from app.schemas.redgreen_result import RedgreenResultCreate
from app.services import audit_service, screening_service
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/redgreen", tags=["redgreen"])


@router.post("/result")
async def save_redgreen_result(
    body: RedgreenResultCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    rg_data = body.model_dump()
    rg = await screening_service.save_redgreen_result(db, body.session_id, rg_data)
    await audit_service.log_action(
        db, actor_id=UUID(current_user["sub"]), actor_type="nurse",
        action="SAVE_REDGREEN_RESULT", resource_type="RedgreenResult", resource_id=rg.id,
        ip_address=request.client.host, device_id=device_id,
    )
    return standard_response({
        "id": str(rg.id),
        "suppression_flag": rg.suppression_flag,
        "binocular_score": rg.binocular_score,
        "confidence_score": float(rg.confidence_score) if rg.confidence_score else None,
        "needs_doctor_review": rg.needs_doctor_review,
    }, "Red-green result saved", device_id=device_id)


@router.get("/history/{patient_id}")
async def get_redgreen_history(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    sessions_q = await db.execute(
        select(ScreeningSession.id).where(ScreeningSession.patient_id == patient_id)
    )
    session_ids = [row[0] for row in sessions_q.all()]

    results = []
    for sid in session_ids:
        rg_q = await db.execute(select(RedgreenResult).where(RedgreenResult.session_id == sid))
        rg = rg_q.scalar_one_or_none()
        if rg:
            results.append({
                "session_id": str(sid),
                "suppression_flag": rg.suppression_flag,
                "binocular_score": rg.binocular_score,
                "asymmetry_ratio": float(rg.asymmetry_ratio) if rg.asymmetry_ratio else None,
                "confidence_score": float(rg.confidence_score) if rg.confidence_score else None,
                "created_at": rg.created_at.isoformat() if rg.created_at else None,
            })

    return standard_response({"history": results, "total": len(results)}, "Red-green history retrieved", device_id=device_id)
