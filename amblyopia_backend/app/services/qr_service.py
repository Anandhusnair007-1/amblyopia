"""
Amblyopia Care System — QR Code Service
Generates QR codes containing session data URLs. Uploads to MinIO.
"""
from __future__ import annotations

import io
import logging
from typing import Optional
from uuid import UUID

from app.config import settings

logger = logging.getLogger(__name__)


def _generate_qr_bytes(data: str) -> bytes:
    """Generate a QR code PNG in memory."""
    import qrcode
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


async def generate_session_qr(session_id: UUID) -> Optional[str]:
    """
    Generate a QR code linking to the session report URL.
    Upload to MinIO and return the URL.
    """
    try:
        from minio import Minio

        report_url = (
            f"https://{settings.hospital_domain}/report/{session_id}"
        )
        qr_bytes = _generate_qr_bytes(report_url)

        client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )
        bucket = settings.minio_bucket
        if not client.bucket_exists(bucket):
            client.make_bucket(bucket, location=settings.minio_region)

        object_name = f"qrcodes/{session_id}.png"
        client.put_object(
            bucket, object_name, io.BytesIO(qr_bytes), length=len(qr_bytes),
            content_type="image/png",
        )
        url = f"http://{settings.minio_endpoint}/{bucket}/{object_name}"
        logger.info("QR code uploaded: %s", url)
        return url
    except Exception as exc:
        logger.error("QR code generation failed: %s", exc)
        return None


def get_qr_bytes(session_id: UUID) -> bytes:
    """Return raw QR code bytes (used when embedding in PDF)."""
    report_url = f"https://{settings.hospital_domain}/report/{session_id}"
    return _generate_qr_bytes(report_url)
