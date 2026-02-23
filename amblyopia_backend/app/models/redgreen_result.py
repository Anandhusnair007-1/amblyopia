"""
RedgreenResult model — stores red-green dichoptic test results.
Measures binocular suppression and pupil asymmetry.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Numeric, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class RedgreenResult(Base):
    __tablename__ = "redgreen_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    session_id = Column(UUID(as_uuid=True), ForeignKey("screening_sessions.id",
                        ondelete="CASCADE"), nullable=False)

    # Pupil measurements
    left_pupil_diameter = Column(Numeric(6, 3), nullable=True)     # mm
    right_pupil_diameter = Column(Numeric(6, 3), nullable=True)    # mm
    asymmetry_ratio = Column(Numeric(6, 4), nullable=True)

    # Suppression detection
    suppression_flag = Column(Boolean, default=False, server_default="false")
    # left|right|equal
    dominant_eye = Column(String(10), nullable=True)
    # 1=suppressed, 2=normal, 3=excellent
    binocular_score = Column(Integer, nullable=True)

    # Pupil constriction (light response)
    constriction_speed_left = Column(Numeric(8, 4), nullable=True)   # mm/s
    constriction_speed_right = Column(Numeric(8, 4), nullable=True)
    constriction_amount_left = Column(Numeric(6, 3), nullable=True)  # mm
    constriction_amount_right = Column(Numeric(6, 3), nullable=True)

    result = Column(String(50), nullable=True)
    confidence_score = Column(Numeric(5, 2), nullable=True)
    needs_doctor_review = Column(Boolean, default=False, server_default="false")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    session = relationship("ScreeningSession", back_populates="redgreen_result")

    def __repr__(self) -> str:
        return (f"<RedgreenResult id={self.id} "
                f"suppression={self.suppression_flag} binocular={self.binocular_score}>")
