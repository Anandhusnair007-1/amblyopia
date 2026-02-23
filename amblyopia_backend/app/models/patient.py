"""
Patient model — stores de-identified patient records.
No names, no photos. UUID only, per DPDP Act 2023.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Patient(Base):
    __tablename__ = "patients"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    # AES-256 encrypted face encoding for longitudinal tracking — no photo stored
    face_vector = Column(String, nullable=True)
    age_group = Column(String(20), nullable=False)   # infant|child|adult|elderly
    village_id = Column(UUID(as_uuid=True), ForeignKey("villages.id", ondelete="SET NULL"),
                        nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))
    last_screened_at = Column(DateTime(timezone=True), nullable=True)
    total_screenings = Column(Integer, default=0, server_default="0")
    is_active = Column(Boolean, default=True, server_default="true")

    # Relationships
    village = relationship("Village", back_populates="patients", lazy="select")
    sessions = relationship("ScreeningSession", back_populates="patient",
                            cascade="all, delete-orphan", lazy="select")

    def __repr__(self) -> str:
        return f"<Patient id={self.id} age_group={self.age_group}>"
