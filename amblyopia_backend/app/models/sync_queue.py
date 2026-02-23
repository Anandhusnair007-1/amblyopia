"""
SyncQueue model — stores encrypted offline screening data pending sync.
Handles deduplication and retry logic for disconnected nurses.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class SyncQueue(Base):
    __tablename__ = "sync_queue"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    device_id = Column(String(255), nullable=False)
    nurse_id = Column(UUID(as_uuid=True), ForeignKey("nurses.id", ondelete="SET NULL"),
                      nullable=True)

    # gaze_result|redgreen_result|snellen_result|combined_result|session
    payload_type = Column(String(30), nullable=False)
    # AES-256 encrypted JSON payload
    payload_encrypted = Column(Text, nullable=False)

    # pending|processing|synced|failed
    sync_status = Column(String(20), default="pending", server_default="pending")
    retry_count = Column(Integer, default=0, server_default="0")
    created_offline_at = Column(DateTime(timezone=True), nullable=False)
    synced_at = Column(DateTime(timezone=True), nullable=True)
    failure_reason = Column(Text, nullable=True)

    nurse = relationship("Nurse", back_populates="sync_queue")

    def __repr__(self) -> str:
        return (f"<SyncQueue id={self.id} "
                f"type={self.payload_type} status={self.sync_status}>")
