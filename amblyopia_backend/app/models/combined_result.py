"""
CombinedResult model — aggregate risk score from all three screening tests.
One record per session. Drives the referral decision.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Numeric, ForeignKey, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class CombinedResult(Base):
    __tablename__ = "combined_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    # Unique — one combined result per session
    session_id = Column(UUID(as_uuid=True), ForeignKey("screening_sessions.id",
                        ondelete="CASCADE"), nullable=False, unique=True)

    # Individual weighted scores (0-100)
    gaze_score = Column(Numeric(5, 2), nullable=True)
    redgreen_score = Column(Numeric(5, 2), nullable=True)
    snellen_score = Column(Numeric(5, 2), nullable=True)

    # Combined: gaze*0.40 + redgreen*0.30 + snellen*0.30
    overall_risk_score = Column(Numeric(5, 2), nullable=True)

    # Severity: 0=Normal, 1=Mild, 2=Moderate, 3=Severe
    severity_grade = Column(Integer, nullable=True)
    # low|medium|high|critical
    risk_level = Column(String(20), nullable=True)

    recommendation = Column(Text, nullable=True)
    referral_needed = Column(Boolean, default=False, server_default="false")
    referral_letter_url = Column(String(500), nullable=True)  # MinIO URL
    qr_code_url = Column(String(500), nullable=True)          # MinIO URL
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    # Relationships
    session = relationship("ScreeningSession", back_populates="combined_result")
    doctor_reviews = relationship("DoctorReview", back_populates="combined_result",
                                  lazy="select")

    def __repr__(self) -> str:
        return (f"<CombinedResult id={self.id} "
                f"risk={self.overall_risk_score} grade={self.severity_grade}>")
