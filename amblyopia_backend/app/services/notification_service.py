"""
Amblyopia Care System — Notification Service
Sends WhatsApp, SMS, and Push notifications via Twilio and Firebase.
All notifications logged to notification_log table.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.notification_log import NotificationLog
from app.utils.helpers import utc_now

logger = logging.getLogger(__name__)

# Notification message templates (multi-language support)
TEMPLATES = {
    "result_normal_english": (
        "✅ Screening Result for your child:\n"
        "No signs of amblyopia detected.\n"
        "Continue annual eye check-ups.\n"
        "— {hospital_name}"
    ),
    "result_referral_english": (
        "⚠️ IMPORTANT: Screening Result\n"
        "Eye condition detected. Please visit {hospital_name} immediately.\n"
        "Bring this QR code: {qr_url}\n"
        "— Aravind Eye Care"
    ),
    "result_normal_tamil": (
        "✅ உங்கள் குழந்தையின் ஸ்க்ரீனிங் முடிவு:\n"
        "கண் பிரச்சனை ஏதும் இல்லை.\n"
        "ஆண்டுதோறும் கண் பரிசோதனை செய்யுங்கள்.\n"
        "— {hospital_name}"
    ),
    "doctor_urgent_alert": (
        "🚨 URGENT: New critical case requires immediate review.\n"
        "Session ID: {session_id}\n"
        "Severity: Grade 3 — Refer immediately\n"
        "Login to review queue now."
    ),
}


async def _log_notification(
    db: AsyncSession,
    recipient_type: str,
    recipient_id: Optional[UUID],
    channel: str,
    template: str,
    send_status: str,
    session_id: Optional[UUID],
) -> NotificationLog:
    entry = NotificationLog(
        recipient_type=recipient_type,
        recipient_id=recipient_id,
        channel=channel,
        message_template=template,
        status=send_status,
        sent_at=utc_now() if send_status == "sent" else None,
        session_id=session_id,
    )
    db.add(entry)
    await db.flush()
    return entry


async def send_parent_whatsapp(
    db: AsyncSession,
    session_id: UUID,
    phone_number: str,
    language: str,
    referral_needed: bool,
    qr_url: Optional[str] = None,
) -> bool:
    """
    Send WhatsApp result notification to parent via Twilio.
    Falls back to log-only if Twilio is not configured.
    """
    template_key = f"result_{'referral' if referral_needed else 'normal'}_{language}"
    template = TEMPLATES.get(template_key, TEMPLATES["result_normal_english"])
    message = template.format(
        hospital_name=settings.hospital_name,
        qr_url=qr_url or "N/A",
        session_id=str(session_id),
    )

    send_status = "failed"
    try:
        if settings.twilio_account_sid and settings.twilio_auth_token:
            from twilio.rest import Client
            client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
            msg = client.messages.create(
                body=message,
                from_=settings.twilio_whatsapp_number,
                to=f"whatsapp:{phone_number}",
            )
            send_status = "sent"
            logger.info("WhatsApp sent: %s", msg.sid)
        else:
            logger.warning("Twilio not configured — notification skipped (log only)")
            send_status = "pending"
    except Exception as exc:
        logger.error("WhatsApp send failed: %s", exc)

    await _log_notification(
        db, "parent", None, "whatsapp", template_key, send_status, session_id
    )
    return send_status == "sent"


async def send_doctor_alert(
    db: AsyncSession,
    session_id: UUID,
    doctor_id: UUID,
    priority: str,
) -> bool:
    """Send urgent case alert push notification to duty doctor."""
    message = TEMPLATES["doctor_urgent_alert"].format(session_id=str(session_id))

    send_status = "failed"
    try:
        if settings.firebase_credentials_path:
            import firebase_admin
            from firebase_admin import messaging
            if not firebase_admin._apps:
                import firebase_admin.credentials as fb_creds
                cred = fb_creds.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)

            notification = messaging.Message(
                notification=messaging.Notification(
                    title=f"🚨 {priority.upper()} Case",
                    body=message[:200],
                ),
                topic=f"doctor_{str(doctor_id)}",
            )
            messaging.send(notification)
            send_status = "sent"
        else:
            logger.warning("Firebase not configured — doctor alert skipped")
            send_status = "pending"
    except Exception as exc:
        logger.error("Doctor push failed: %s", exc)

    await _log_notification(db, "doctor", doctor_id, "push", "doctor_urgent_alert", send_status, session_id)
    return send_status == "sent"


async def send_nurse_push(
    db: AsyncSession,
    nurse_id: UUID,
    message_type: str,
    extra: dict = None,
) -> bool:
    """Send push notification to a nurse's device."""
    send_status = "pending"
    try:
        if settings.firebase_credentials_path:
            import firebase_admin
            from firebase_admin import messaging
            if not firebase_admin._apps:
                import firebase_admin.credentials as fb_creds
                cred = fb_creds.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)

            notification = messaging.Message(
                notification=messaging.Notification(title="Amblyopia Care", body=message_type),
                topic=f"nurse_{str(nurse_id)}",
            )
            messaging.send(notification)
            send_status = "sent"
    except Exception as exc:
        logger.error("Nurse push failed: %s", exc)

    await _log_notification(db, "nurse", nurse_id, "push", message_type, send_status, None)
    return send_status == "sent"


async def send_sms_fallback(
    db: AsyncSession,
    phone_number: str,
    session_id: UUID,
    message: str,
) -> bool:
    """Send SMS fallback when WhatsApp fails."""
    send_status = "failed"
    try:
        if settings.twilio_account_sid and settings.twilio_auth_token:
            from twilio.rest import Client
            client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
            client.messages.create(
                body=message[:160],
                from_=settings.twilio_sms_number,
                to=phone_number,
            )
            send_status = "sent"
    except Exception as exc:
        logger.error("SMS fallback failed: %s", exc)

    await _log_notification(db, "parent", None, "sms", "sms_fallback", send_status, session_id)
    return send_status == "sent"
