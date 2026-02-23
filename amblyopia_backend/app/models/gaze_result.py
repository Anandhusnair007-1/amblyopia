"""
GazeResult model — stores gaze tracking metrics from screening session.
Detects fixation asymmetry, blink asymmetry, and gaze deviation.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Numeric, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class GazeResult(Base):
    __tablename__ = "gaze_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    session_id = Column(UUID(as_uuid=True), ForeignKey("screening_sessions.id",
                        ondelete="CASCADE"), nullable=False)

    # Gaze coordinates
    left_gaze_x = Column(Numeric(8, 4), nullable=True)
    left_gaze_y = Column(Numeric(8, 4), nullable=True)
    right_gaze_x = Column(Numeric(8, 4), nullable=True)
    right_gaze_y = Column(Numeric(8, 4), nullable=True)

    # Fixation stability (standard deviation of gaze points)
    left_fixation_stability = Column(Numeric(8, 4), nullable=True)
    right_fixation_stability = Column(Numeric(8, 4), nullable=True)
    gaze_asymmetry_score = Column(Numeric(8, 4), nullable=True)

    # Blink metrics
    left_blink_ratio = Column(Numeric(8, 4), nullable=True)
    right_blink_ratio = Column(Numeric(8, 4), nullable=True)
    blink_asymmetry = Column(Numeric(8, 4), nullable=True)
    left_blink_count = Column(Integer, nullable=True)
    right_blink_count = Column(Integer, nullable=True)

    # Session metadata
    frames_analyzed = Column(Integer, nullable=True)
    session_duration_seconds = Column(Integer, nullable=True)
    confidence_score = Column(Numeric(5, 2), nullable=True)

    # symmetric|asymmetry_detected|unable_to_detect
    result = Column(String(30), nullable=True)
    needs_doctor_review = Column(Boolean, default=False, server_default="false")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    session = relationship("ScreeningSession", back_populates="gaze_result")

    def __repr__(self) -> str:
        return f"<GazeResult id={self.id} result={self.result}>"
