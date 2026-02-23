"""
RetrainingJob model — tracks weekly Airflow-triggered model retraining runs.
Records old/new model accuracy comparison and deployment decisions.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Numeric, ForeignKey, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class RetrainingJob(Base):
    __tablename__ = "retraining_jobs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    triggered_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                          server_default=text("now()"))
    # scheduled|manual
    trigger_type = Column(String(20), default="scheduled", server_default="scheduled")
    new_data_count = Column(Integer, nullable=True)

    previous_model_id = Column(UUID(as_uuid=True),
                                ForeignKey("ml_models.id", ondelete="SET NULL"),
                                nullable=True)
    new_model_id = Column(UUID(as_uuid=True),
                          ForeignKey("ml_models.id", ondelete="SET NULL"),
                          nullable=True)

    old_accuracy = Column(Numeric(5, 4), nullable=True)
    new_accuracy = Column(Numeric(5, 4), nullable=True)

    # pending|running|passed|failed|deployed|rolled_back
    status = Column(String(20), default="pending", server_default="pending")
    approved_auto = Column(Boolean, nullable=True)
    failure_reason = Column(Text, nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    previous_model = relationship(
        "MLModel",
        foreign_keys=[previous_model_id],
        back_populates="retraining_jobs_as_prev",
    )
    new_model = relationship(
        "MLModel",
        foreign_keys=[new_model_id],
        back_populates="retraining_jobs_as_new",
    )

    def __repr__(self) -> str:
        return (f"<RetrainingJob id={self.id} "
                f"status={self.status} trigger={self.trigger_type}>")
