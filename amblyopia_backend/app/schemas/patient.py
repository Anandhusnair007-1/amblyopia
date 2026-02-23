"""
Patient schemas — create, read, and update patient records.
All patient identifiers are UUIDs. No PII stored.
"""
from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


AgeGroup = Literal["infant", "child", "adult", "elderly"]


class PatientCreate(BaseModel):
    age_group: AgeGroup
    village_id: UUID
    # Encrypted face vector string
    face_vector: Optional[str] = None


class PatientRead(BaseModel):
    id: UUID
    age_group: str
    village_id: Optional[UUID]
    created_at: datetime
    last_screened_at: Optional[datetime]
    total_screenings: int
    is_active: bool

    model_config = {"from_attributes": True}


class PatientHistoryEntry(BaseModel):
    session_id: UUID
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    severity_grade: Optional[int]
    risk_level: Optional[str]
    overall_risk_score: Optional[float]
    referral_needed: Optional[bool]

    model_config = {"from_attributes": True}


class PatientHistoryResponse(BaseModel):
    patient: PatientRead
    sessions: List[PatientHistoryEntry]
    total: int


class UpdateFaceVectorRequest(BaseModel):
    face_vector: str = Field(..., description="New AES-256 encrypted face vector")


class StandardResponse(BaseModel):
    success: bool = True
    data: dict
    message: str
    timestamp: str
    device_id: str
