"""
Screening router — start/complete sessions, reports, history.
POST /api/screening/start
POST /api/screening/complete
GET  /api/screening/report/{session_id}
GET  /api/screening/history/{patient_id}
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.combined_result import CombinedResult
from app.models.session import ScreeningSession
from app.schemas.session import SessionComplete, SessionStart
from app.services import screening_service
from app.services.notification_service import send_doctor_alert
from app.services.pdf_service import generate_referral_letter
from app.services.qr_service import generate_session_qr, get_qr_bytes
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/screening", tags=["screening"])


@router.post("/start")
async def start_session(
    body: SessionStart,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    session = await screening_service.start_session(
        db=db,
        patient_id=body.patient_id,
        nurse_id=body.nurse_id,
        village_id=body.village_id,
        device_id=body.device_id,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        lighting_condition=body.lighting_condition,
        battery_level=body.battery_level,
        internet_available=body.internet_available,
        actor_ip=request.client.host,
    )
    return standard_response({"session_id": str(session.id)}, "Session started", device_id=device_id)


@router.post("/complete")
async def complete_session(
    body: SessionComplete,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    # Save individual test results if provided
    if body.gaze_result:
        body.gaze_result["session_id"] = str(body.session_id)
        await screening_service.save_gaze_result(db, body.session_id, body.gaze_result)
    if body.redgreen_result:
        body.redgreen_result["session_id"] = str(body.session_id)
        await screening_service.save_redgreen_result(db, body.session_id, body.redgreen_result)
    if body.snellen_result:
        body.snellen_result["session_id"] = str(body.session_id)
        await screening_service.save_snellen_result(db, body.session_id, body.snellen_result)

    combined = await screening_service.complete_session(
        db, body.session_id, UUID(current_user["sub"]), device_id, request.client.host
    )

    # Generate QR and PDF for referral cases
    qr_url = None
    pdf_url = None
    if combined.referral_needed:
        qr_url = await generate_session_qr(body.session_id)
        qr_bytes = get_qr_bytes(body.session_id)
        pdf_url = await generate_referral_letter(db, body.session_id, qr_bytes)
        # Update combined result with URLs
        combined.qr_code_url = qr_url
        combined.referral_letter_url = pdf_url
        await db.flush()

        # Alert doctor if grade 3
        if combined.severity_grade == 3:
            await send_doctor_alert(db, body.session_id, UUID(current_user["sub"]), "urgent")

    return standard_response({
        "session_id": str(body.session_id),
        "severity_grade": combined.severity_grade,
        "risk_level": combined.risk_level,
        "overall_risk_score": float(combined.overall_risk_score) if combined.overall_risk_score else None,
        "recommendation": combined.recommendation,
        "referral_needed": combined.referral_needed,
        "referral_letter_url": pdf_url,
        "qr_code_url": qr_url,
    }, "Session completed", device_id=device_id)


@router.get("/report/{session_id}")
async def get_session_report(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    report = await screening_service.get_session_report(db, session_id)
    return standard_response(report, "Report retrieved", device_id=device_id)


@router.get("/history/{patient_id}")
async def get_session_history(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    from app.services.patient_service import get_patient_history
    history = await get_patient_history(db, patient_id)
    return standard_response(history, "Screening history retrieved", device_id=device_id)
