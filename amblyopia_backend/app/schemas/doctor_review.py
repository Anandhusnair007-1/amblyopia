"""
DoctorReview schemas — review queue and verdict submission.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class DoctorVerdictRequest(BaseModel):
    doctor_verdict: str = Field(..., description="Doctor's clinical verdict")
    doctor_notes: Optional[str] = None     # Will be encrypted before storage
    final_diagnosis: Optional[str] = None
    treatment_plan: Optional[str] = None   # Will be encrypted before storage
    follow_up_date: Optional[datetime] = None


class DoctorReviewRead(BaseModel):
    id: UUID
    session_id: UUID
    combined_result_id: Optional[UUID]
    doctor_id: UUID
    assigned_at: datetime
    reviewed_at: Optional[datetime]
    doctor_verdict: Optional[str]
    final_diagnosis: Optional[str]
    follow_up_date: Optional[datetime]
    priority: str
    status: str

    model_config = {"from_attributes": True}


class DoctorStatsResponse(BaseModel):
    reviews_completed_today: int
    reviews_completed_this_week: int
    pending_reviews: int
    average_review_time_minutes: Optional[float]
    urgent_pending: int
    high_pending: int
