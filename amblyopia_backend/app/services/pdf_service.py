"""
Amblyopia Care System — PDF Service
Generates referral letters using ReportLab. Uploads to MinIO.
"""
from __future__ import annotations

import io
import logging
from datetime import datetime
from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.combined_result import CombinedResult
from app.models.session import ScreeningSession

logger = logging.getLogger(__name__)

GRADE_COLORS = {0: (0, 128, 0), 1: (200, 150, 0), 2: (200, 80, 0), 3: (180, 0, 0)}


async def generate_referral_letter(
    db: AsyncSession,
    session_id: UUID,
    qr_code_bytes: Optional[bytes] = None,
) -> Optional[str]:
    """
    Generate a referral PDF for a session and upload to MinIO.
    Returns the MinIO URL of the uploaded PDF.
    """
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.enums import TA_CENTER

        sess_q = await db.execute(select(ScreeningSession).where(ScreeningSession.id == session_id))
        session = sess_q.scalar_one_or_none()
        if not session:
            return None

        cr_q = await db.execute(select(CombinedResult).where(CombinedResult.session_id == session_id))
        combined = cr_q.scalar_one_or_none()
        if not combined:
            return None

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=20*mm, bottomMargin=20*mm)
        styles = getSampleStyleSheet()
        story = []

        # Header
        header_style = ParagraphStyle("header", fontSize=16, alignment=TA_CENTER, spaceAfter=4)
        sub_style = ParagraphStyle("sub", fontSize=11, alignment=TA_CENTER, spaceAfter=2)

        story.append(Paragraph(f"<b>{settings.hospital_name}</b>", header_style))
        story.append(Paragraph("Amblyopia Care System — Referral Letter", sub_style))
        story.append(Paragraph(f"Generated: {datetime.utcnow().strftime('%d %b %Y, %H:%M UTC')}", sub_style))
        story.append(Spacer(1, 10*mm))

        # Patient info table
        grade = combined.severity_grade or 0
        risk_color = colors.Color(*[c / 255 for c in GRADE_COLORS.get(grade, (0, 0, 0))])

        data = [
            ["Patient UUID", str(session.patient_id)],
            ["Session ID", str(session_id)],
            ["Village ID", str(session.village_id) if session.village_id else "N/A"],
            ["Screening Date", session.started_at.strftime("%d %b %Y") if session.started_at else "N/A"],
            ["Device ID", session.device_id or "N/A"],
            ["Lighting", session.lighting_condition or "N/A"],
        ]
        tbl = Table(data, colWidths=[60*mm, 110*mm])
        tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, -1), colors.lightgrey),
            ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]))
        story.append(tbl)
        story.append(Spacer(1, 8*mm))

        # Scores
        score_data = [
            ["Test", "Score (0-100)", "Status"],
            ["Gaze Analysis", f"{combined.gaze_score:.1f}" if combined.gaze_score else "N/A", ""],
            ["Red-Green Test", f"{combined.redgreen_score:.1f}" if combined.redgreen_score else "N/A", ""],
            ["Snellen Acuity", f"{combined.snellen_score:.1f}" if combined.snellen_score else "N/A", ""],
            ["COMBINED RISK", f"{combined.overall_risk_score:.1f}" if combined.overall_risk_score else "N/A",
             combined.risk_level.upper() if combined.risk_level else ""],
        ]
        stbl = Table(score_data, colWidths=[70*mm, 50*mm, 50*mm])
        stbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2C3E50")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, -1), (-1, -1), risk_color),
            ("TEXTCOLOR", (0, -1), (-1, -1), colors.white),
            ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ]))
        story.append(stbl)
        story.append(Spacer(1, 8*mm))

        # Severity
        grade_text = {
            0: "Grade 0 — NORMAL",
            1: "Grade 1 — MILD",
            2: "Grade 2 — MODERATE",
            3: "Grade 3 — SEVERE/URGENT",
        }.get(grade, "Unknown")
        story.append(Paragraph(f"<b>Severity: {grade_text}</b>", styles["Normal"]))
        story.append(Spacer(1, 4*mm))
        story.append(Paragraph(f"<b>Recommendation:</b> {combined.recommendation or 'See doctor immediately.'}", styles["Normal"]))
        story.append(Spacer(1, 8*mm))

        # QR code placeholder
        if qr_code_bytes:
            qr_img = RLImage(io.BytesIO(qr_code_bytes), width=40*mm, height=40*mm)
            story.append(qr_img)

        story.append(Spacer(1, 5*mm))
        story.append(Paragraph(
            "This referral was generated by the Aravind Eye Hospital Amblyopia Care System. "
            "Patient data is de-identified per DPDP Act 2023.",
            ParagraphStyle("footer", fontSize=8, textColor=colors.grey)
        ))

        doc.build(story)
        pdf_bytes = buffer.getvalue()

        # Upload to MinIO
        object_name = f"referrals/{session_id}.pdf"
        url = await _upload_to_minio(pdf_bytes, object_name, "application/pdf")
        return url

    except Exception as exc:
        logger.error("PDF generation failed: %s", exc)
        return None


async def _upload_to_minio(data: bytes, object_name: str, content_type: str) -> Optional[str]:
    """Upload bytes to MinIO and return the object URL."""
    try:
        from minio import Minio
        from minio.error import S3Error

        client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )
        bucket = settings.minio_bucket
        if not client.bucket_exists(bucket):
            client.make_bucket(bucket, location=settings.minio_region)

        client.put_object(
            bucket, object_name, io.BytesIO(data), length=len(data),
            content_type=content_type,
        )
        return f"http://{settings.minio_endpoint}/{bucket}/{object_name}"
    except Exception as exc:
        logger.error("MinIO upload failed: %s", exc)
        return None
