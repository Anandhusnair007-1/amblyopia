from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from database import Base


def utcnow():
    return datetime.now(timezone.utc)


class SyncedSession(Base):
    __tablename__ = "synced_sessions"

    id = Column(Integer, primary_key=True)
    hashed_session_id = Column(String(128), unique=True, nullable=False)
    device_id = Column(String(128), nullable=False)
    test_date = Column(DateTime(timezone=True), nullable=False)
    age_group = Column(String(32), nullable=False)
    payload_json = Column(Text, nullable=False)
    label = Column(Integer, nullable=True)
    doctor_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)

    prediction = relationship("PredictionRecord", uselist=False, back_populates="session")
    images = relationship("ImageRecord", back_populates="session")


class PredictionRecord(Base):
    __tablename__ = "prediction_records"

    id = Column(Integer, primary_key=True)
    session_id = Column(Integer, ForeignKey("synced_sessions.id"), nullable=False, unique=True)
    risk_score = Column(Float, nullable=False)
    risk_level = Column(String(32), nullable=False)
    model_version = Column(String(32), nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    session = relationship("SyncedSession", back_populates="prediction")


class ImageRecord(Base):
    __tablename__ = "image_records"

    id = Column(Integer, primary_key=True)
    session_id = Column(Integer, ForeignKey("synced_sessions.id"), nullable=False)
    image_type = Column(String(32), nullable=False)
    object_path = Column(String(512), nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    session = relationship("SyncedSession", back_populates="images")


class ModelRegistry(Base):
    __tablename__ = "model_registry"
    __table_args__ = (UniqueConstraint("version", name="uq_model_registry_version"),)

    id = Column(Integer, primary_key=True)
    version = Column(String(32), nullable=False)
    storage_path = Column(String(512), nullable=False)
    checksum = Column(String(128), nullable=False)
    auroc = Column(Float, nullable=False)
    sensitivity = Column(Float, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)


class TrainingRun(Base):
    __tablename__ = "training_runs"

    id = Column(Integer, primary_key=True)
    started_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    samples_used = Column(Integer, default=0, nullable=False)
    triggered = Column(Boolean, default=False, nullable=False)
    status = Column(String(32), default="pending", nullable=False)
    auroc = Column(Float, nullable=True)
    sensitivity = Column(Float, nullable=True)


class DoctorUser(Base):
    __tablename__ = "doctor_users"

    id = Column(Integer, primary_key=True)
    username = Column(String(128), unique=True, nullable=False)
    password_hash = Column(String(256), nullable=False)
    full_name = Column(String(128), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
