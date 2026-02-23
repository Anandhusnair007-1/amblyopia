"""
NotificationLog model — audit trail for all outbound communications.
Tracks WhatsApp, SMS, push, and email notifications.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class NotificationLog(Base):
    __tablename__ = "notification_log"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    # parent|doctor|nurse|admin
    recipient_type = Column(String(20), nullable=False)
    recipient_id = Column(UUID(as_uuid=True), nullable=True)
    # whatsapp|sms|push|email
    channel = Column(String(20), nullable=False)
    message_template = Column(String(100), nullable=True)
    # sent|failed|pending
    status = Column(String(20), default="pending", server_default="pending")
    sent_at = Column(DateTime(timezone=True), nullable=True)
    session_id = Column(UUID(as_uuid=True),
                        ForeignKey("screening_sessions.id", ondelete="SET NULL"),
                        nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    session = relationship("ScreeningSession", back_populates="notification_logs")

    def __repr__(self) -> str:
        return (f"<NotificationLog id={self.id} "
                f"channel={self.channel} status={self.status}>")
