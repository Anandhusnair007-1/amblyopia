"""
Village model — geographic screening coverage unit.
Heatmap status (green/yellow/red) drives dashboard map.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Column, DateTime, ForeignKey, Integer, Numeric, String, text
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Village(Base):
    __tablename__ = "villages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    name = Column(String(255), nullable=False)
    district = Column(String(100), nullable=True)
    state = Column(String(100), nullable=True)
    lat = Column(Numeric(10, 7), nullable=True)
    lng = Column(Numeric(10, 7), nullable=True)
    last_screened_date = Column(DateTime(timezone=True), nullable=True)
    # green=<30 days, yellow=30-90 days, red=>90 days or never
    screening_status = Column(String(10), default="red", server_default="red")
    estimated_population = Column(Integer, nullable=True)
    children_under_7 = Column(Integer, nullable=True)
    assigned_nurse_id = Column(UUID(as_uuid=True),
                               ForeignKey("nurses.id", ondelete="SET NULL"),
                               nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    # Relationships
    patients = relationship("Patient", back_populates="village", lazy="select")
    sessions = relationship("ScreeningSession", back_populates="village",
                            lazy="select")
    assigned_nurse = relationship("Nurse", foreign_keys=[assigned_nurse_id],
                                  lazy="select")

    def __repr__(self) -> str:
        return f"<Village id={self.id} name={self.name} status={self.screening_status}>"
