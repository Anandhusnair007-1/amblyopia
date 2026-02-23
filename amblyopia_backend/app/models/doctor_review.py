"""
DoctorReview model — clinical review of flagged screening sessions.
Doctor notes and treatment plan stored encrypted.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class DoctorReview(Base):
    __tablename__ = "doctor_reviews"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    session_id = Column(UUID(as_uuid=True), ForeignKey("screening_sessions.id",
                        ondelete="CASCADE"), nullable=False)
    combined_result_id = Column(UUID(as_uuid=True),
                                ForeignKey("combined_results.id", ondelete="SET NULL"),
                                nullable=True)
    # Doctor is identified by UUID — no name stored
    doctor_id = Column(UUID(as_uuid=True), nullable=False)

    assigned_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                         server_default=text("now()"))
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    doctor_verdict = Column(String(100), nullable=True)
    # AES-256 encrypted
    doctor_notes = Column(Text, nullable=True)
    final_diagnosis = Column(String(255), nullable=True)
    # AES-256 encrypted
    treatment_plan = Column(Text, nullable=True)
    follow_up_date = Column(DateTime(timezone=True), nullable=True)

    # urgent|high|normal|low
    priority = Column(String(20), default="normal", server_default="normal")
    # pending|in_review|completed
    status = Column(String(20), default="pending", server_default="pending")

    session = relationship("ScreeningSession", back_populates="doctor_reviews")
    combined_result = relationship("CombinedResult", back_populates="doctor_reviews")

    def __repr__(self) -> str:
        return f"<DoctorReview id={self.id} status={self.status} priority={self.priority}>"
