"""
Gaze router — save gaze results, view history, analyze.
POST /api/gaze/result
GET  /api/gaze/history/{patient_id}
GET  /api/gaze/analyze/{session_id}
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.gaze_result import GazeResult
from app.models.session import ScreeningSession
from app.schemas.gaze_result import GazeResultCreate
from app.services import audit_service, screening_service
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/gaze", tags=["gaze"])


@router.post("/result")
async def save_gaze_result(
    body: GazeResultCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    gaze_data = body.model_dump()
    gr = await screening_service.save_gaze_result(db, body.session_id, gaze_data)
    await audit_service.log_action(
        db, actor_id=UUID(current_user["sub"]), actor_type="nurse",
        action="SAVE_GAZE_RESULT", resource_type="GazeResult", resource_id=gr.id,
        ip_address=request.client.host, device_id=device_id,
    )
    return standard_response({
        "id": str(gr.id), "result": gr.result,
        "needs_doctor_review": gr.needs_doctor_review,
        "confidence_score": float(gr.confidence_score) if gr.confidence_score else None,
    }, "Gaze result saved", device_id=device_id)


@router.get("/history/{patient_id}")
async def get_gaze_history(
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
        gr_q = await db.execute(select(GazeResult).where(GazeResult.session_id == sid))
        gr = gr_q.scalar_one_or_none()
        if gr:
            results.append({
                "session_id": str(sid),
                "result": gr.result,
                "gaze_asymmetry_score": float(gr.gaze_asymmetry_score) if gr.gaze_asymmetry_score else None,
                "confidence_score": float(gr.confidence_score) if gr.confidence_score else None,
                "created_at": gr.created_at.isoformat() if gr.created_at else None,
            })

    return standard_response({"history": results, "total": len(results)}, "Gaze history retrieved", device_id=device_id)


@router.get("/analyze/{session_id}")
async def analyze_gaze(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    gr_q = await db.execute(select(GazeResult).where(GazeResult.session_id == session_id))
    gr = gr_q.scalar_one_or_none()
    if not gr:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Gaze result not found for this session")

    analysis = {
        "session_id": str(session_id),
        "result": gr.result,
        "left_gaze": {"x": float(gr.left_gaze_x or 0), "y": float(gr.left_gaze_y or 0)},
        "right_gaze": {"x": float(gr.right_gaze_x or 0), "y": float(gr.right_gaze_y or 0)},
        "fixation": {
            "left_stability": float(gr.left_fixation_stability or 0),
            "right_stability": float(gr.right_fixation_stability or 0),
            "asymmetry_score": float(gr.gaze_asymmetry_score or 0),
        },
        "blink": {
            "left_count": gr.left_blink_count,
            "right_count": gr.right_blink_count,
            "asymmetry": float(gr.blink_asymmetry or 0),
        },
        "frames_analyzed": gr.frames_analyzed,
        "duration_seconds": gr.session_duration_seconds,
        "confidence_score": float(gr.confidence_score or 0),
        "needs_doctor_review": gr.needs_doctor_review,
    }
    return standard_response(analysis, "Gaze analysis retrieved", device_id=device_id)
