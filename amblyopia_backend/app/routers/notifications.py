"""
Notifications router — query notification history, resend.
GET  /api/notifications/history/{session_id}
POST /api/notifications/resend/{session_id}
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_doctor, get_device_id, rate_limit
from app.models.combined_result import CombinedResult
from app.models.notification_log import NotificationLog
from app.models.session import ScreeningSession
from app.services.notification_service import send_parent_whatsapp
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("/history/{session_id}")
async def get_notification_history(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return all notifications sent for a session."""
    q = await db.execute(
        select(NotificationLog).where(NotificationLog.session_id == session_id)
        .order_by(NotificationLog.sent_at.desc())
    )
    logs = q.scalars().all()

    data = [{
        "id": str(log.id),
        "channel": log.channel,
        "recipient_type": log.recipient_type,
        "message_template": log.message_template,
        "status": log.status,
        "sent_at": log.sent_at.isoformat() if log.sent_at else None,
    } for log in logs]

    return standard_response({"notifications": data, "total": len(data)}, "Notification history retrieved", device_id=device_id)


@router.post("/resend/{session_id}")
async def resend_notification(
    session_id: UUID,
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Resend result notification to parent."""
    phone_number = body.get("phone_number")
    language = body.get("language", "english")

    if not phone_number:
        raise HTTPException(status_code=400, detail="phone_number is required")

    # Get combined result so we know if referral needed
    cr_q = await db.execute(select(CombinedResult).where(CombinedResult.session_id == session_id))
    combined = cr_q.scalar_one_or_none()
    if not combined:
        raise HTTPException(status_code=404, detail="No results found for this session")

    sent = await send_parent_whatsapp(
        db, session_id, phone_number, language,
        combined.referral_needed, combined.qr_code_url
    )

    return standard_response({"sent": sent, "channel": "whatsapp"}, "Notification sent" if sent else "Notification queued", device_id=device_id)
