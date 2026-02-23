"""
MLModel model — tracks trained model versions with performance metrics.
Active model is loaded by ml_wrapper_service for inference.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, Numeric, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class MLModel(Base):
    __tablename__ = "ml_models"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
                server_default=text("gen_random_uuid()"))
    version = Column(String(50), nullable=False, unique=True)  # e.g. "v1.0.0"

    # Model performance metrics
    accuracy_score = Column(Numeric(5, 4), nullable=True)
    precision_score = Column(Numeric(5, 4), nullable=True)
    recall_score = Column(Numeric(5, 4), nullable=True)
    f1_score = Column(Numeric(5, 4), nullable=True)

    # Training metadata
    training_date = Column(DateTime(timezone=True), nullable=True)
    dataset_size = Column(Integer, nullable=True)
    new_cases_used = Column(Integer, nullable=True)

    # training|testing|active|rejected|rolled_back
    status = Column(String(20), default="training", server_default="training")
    deployed_at = Column(DateTime(timezone=True), nullable=True)

    # MinIO path to TFLite model file
    tflite_file_path = Column(String(500), nullable=True)
    model_size_mb = Column(Numeric(8, 2), nullable=True)

    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow,
                        server_default=text("now()"))

    # Relationships
    retraining_jobs_as_prev = relationship(
        "RetrainingJob",
        foreign_keys="RetrainingJob.previous_model_id",
        back_populates="previous_model",
        lazy="select",
    )
    retraining_jobs_as_new = relationship(
        "RetrainingJob",
        foreign_keys="RetrainingJob.new_model_id",
        back_populates="new_model",
        lazy="select",
    )

    def __repr__(self) -> str:
        return f"<MLModel version={self.version} status={self.status} f1={self.f1_score}>"
