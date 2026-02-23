"""
AuditTrail model — tamper-proof immutable log of all system actions.
No DELETE operations allowed per DPDP Act 2023 compliance.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, String, text
from sqlalchemy.dialects.postgresql import JSONB, UUID

from app.database import Base


class AuditTrail(Base):
    __tablename__ = "audit_trail"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))

    # Who performed the action
    actor_id = Column(UUID(as_uuid=True), nullable=True)
    # nurse|doctor|admin|system
    actor_type = Column(String(20), nullable=False)

    # What they did
    action = Column(String(100), nullable=False)       # e.g. "CREATE_SESSION"
    resource_type = Column(String(50), nullable=True)  # e.g. "ScreeningSession"
    resource_id = Column(UUID(as_uuid=True), nullable=True)

    # Context
    ip_address = Column(String(45), nullable=True)      # IPv4 or IPv6
    device_id = Column(String(255), nullable=True)

    # Before/after values for changes (safely stored as JSONB)
    old_value = Column(JSONB, nullable=True)
    new_value = Column(JSONB, nullable=True)

    timestamp = Column(DateTime(timezone=True), default=datetime.utcnow,
                       server_default=text("now()"), nullable=False)

    def __repr__(self) -> str:
        return (f"<AuditTrail id={self.id} "
                f"actor={self.actor_type} action={self.action}>")
