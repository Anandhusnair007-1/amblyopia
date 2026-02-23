"""
SnellenResult schemas — visual acuity test data.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class SnellenResultCreate(BaseModel):
    session_id: UUID
    visual_acuity_right: Optional[str] = None    # e.g. "6/12"
    visual_acuity_left: Optional[str] = None
    visual_acuity_both: Optional[str] = None
    per_letter_results: Optional[Dict[str, Any]] = None
    response_times: Optional[Dict[str, Any]] = None
    hesitation_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    gaze_compliance_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    test_mode: Literal["snellen", "tumbling_e", "lea_symbols"] = "snellen"
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)


class SnellenResultRead(BaseModel):
    id: UUID
    session_id: UUID
    visual_acuity_right: Optional[str]
    visual_acuity_left: Optional[str]
    visual_acuity_both: Optional[str]
    per_letter_results: Optional[Dict[str, Any]]
    response_times: Optional[Dict[str, Any]]
    hesitation_score: Optional[float]
    gaze_compliance_score: Optional[float]
    test_mode: str
    confidence_score: Optional[float]
    needs_doctor_review: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class AcuityTrendEntry(BaseModel):
    session_id: UUID
    date: datetime
    visual_acuity_right: Optional[str]
    visual_acuity_left: Optional[str]
    overall_risk_score: Optional[float]
