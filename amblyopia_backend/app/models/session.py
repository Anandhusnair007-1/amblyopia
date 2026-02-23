"""
ScreeningSession model — top-level record for each screening encounter.
Links patient, nurse, village and tracks device, GPS, and sync status.
"""
from __future__ import annotations

import uuid

from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey, Integer, Numeric, String, Text, text
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class ScreeningSession(Base):
    __tablename__ = "screening_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    patient_id = Column(UUID(as_uuid=True), ForeignKey("patients.id", ondelete="CASCADE"),
                        nullable=False)
    nurse_id = Column(UUID(as_uuid=True), ForeignKey("nurses.id", ondelete="SET NULL"),
                      nullable=True)
    village_id = Column(UUID(as_uuid=True), ForeignKey("villages.id", ondelete="SET NULL"),
                        nullable=True)
    device_id = Column(String(255), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    gps_lat = Column(Numeric(10, 7), nullable=True)
    gps_lng = Column(Numeric(10, 7), nullable=True)
    # good|poor|very_poor
    lighting_condition = Column(String(20), nullable=True)
    battery_level = Column(Integer, nullable=True)         # percentage 0-100
    internet_available = Column(Boolean, default=False)
    # pending|synced|failed
    sync_status = Column(String(20), default="pending", server_default="pending")
    # AES-256 encrypted
    session_notes = Column(Text, nullable=True)

    # Relationships
    patient = relationship("Patient", back_populates="sessions", lazy="select")
    nurse = relationship("Nurse", back_populates="sessions", lazy="select")
    village = relationship("Village", back_populates="sessions", lazy="select")
    gaze_result = relationship("GazeResult", back_populates="session",
                               uselist=False, lazy="select")
    redgreen_result = relationship("RedgreenResult", back_populates="session",
                                   uselist=False, lazy="select")
    snellen_result = relationship("SnellenResult", back_populates="session",
                                  uselist=False, lazy="select")
    combined_result = relationship("CombinedResult", back_populates="session",
                                   uselist=False, lazy="select")
    doctor_reviews = relationship("DoctorReview", back_populates="session",
                                  lazy="select")
    notification_logs = relationship("NotificationLog", back_populates="session",
                                     lazy="select")

    def __repr__(self) -> str:
        return f"<ScreeningSession id={self.id} sync={self.sync_status}>"
