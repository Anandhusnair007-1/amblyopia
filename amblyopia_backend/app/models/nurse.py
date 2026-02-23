"""
Nurse model — stores nurse accounts with device binding.
Phone number stored encrypted. Device bound to prevent sharing.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean, Column, DateTime, Numeric, Integer, String, text
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Nurse(Base):
    __tablename__ = "nurses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    # AES-256 encrypted phone number
    phone_number = Column(String, nullable=False, unique=True)
    password_hash = Column(String, nullable=False)
    # Array of village UUIDs this nurse is assigned to
    assigned_villages = Column(ARRAY(UUID(as_uuid=True)), default=list,
                               server_default="{}")
    # Device binding — nurse can only login from registered device
    device_id = Column(String, nullable=True)
    device_specs = Column(JSONB, nullable=True)          # camera_mp, ram, os, android version
    performance_score = Column(Numeric(5, 2), default=0.0, server_default="0.0")
    total_screenings = Column(Integer, default=0, server_default="0")
    language_preference = Column(String(20), default="english", server_default="english")
    last_active = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, default=True, server_default="true")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    # Relationships
    sessions = relationship("ScreeningSession", back_populates="nurse",
                            lazy="select")
    sync_queue = relationship("SyncQueue", back_populates="nurse", lazy="select")

    def __repr__(self) -> str:
        return f"<Nurse id={self.id} device={self.device_id}>"
