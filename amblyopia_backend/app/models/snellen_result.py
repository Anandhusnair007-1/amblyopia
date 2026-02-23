"""
SnellenResult model — stores visual acuity test results.
Supports standard Snellen, Tumbling-E, and LEA Symbols variants.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Numeric, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from app.database import Base


class SnellenResult(Base):
    __tablename__ = "snellen_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    session_id = Column(UUID(as_uuid=True), ForeignKey("screening_sessions.id",
                        ondelete="CASCADE"), nullable=False)

    # Visual acuity fractions e.g. "6/12", "6/6", "6/60"
    visual_acuity_right = Column(String(10), nullable=True)
    visual_acuity_left = Column(String(10), nullable=True)
    visual_acuity_both = Column(String(10), nullable=True)

    # Per-letter correctness: {"row_1": [T,F,T,T,F], ...}
    per_letter_results = Column(JSONB, nullable=True)
    # Response times in ms per letter: {"row_1": [450, 380, 920, ...], ...}
    response_times = Column(JSONB, nullable=True)

    # Behavioral indicators
    hesitation_score = Column(Numeric(5, 2), nullable=True)      # 0.0 to 1.0
    gaze_compliance_score = Column(Numeric(5, 2), nullable=True)  # 0.0 to 1.0

    # snellen|tumbling_e|lea_symbols
    test_mode = Column(String(20), default="snellen")

    confidence_score = Column(Numeric(5, 2), nullable=True)
    needs_doctor_review = Column(Boolean, default=False, server_default="false")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    session = relationship("ScreeningSession", back_populates="snellen_result")

    def __repr__(self) -> str:
        return (f"<SnellenResult id={self.id} "
                f"R={self.visual_acuity_right} L={self.visual_acuity_left}>")
