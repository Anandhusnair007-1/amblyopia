"""
CombinedResult schemas — aggregate risk scores and referral decisions.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel


RiskLevel = Literal["low", "medium", "high", "critical"]


class CombinedResultRead(BaseModel):
    id: UUID
    session_id: UUID
    gaze_score: Optional[float]
    redgreen_score: Optional[float]
    snellen_score: Optional[float]
    overall_risk_score: Optional[float]
    severity_grade: Optional[int]
    risk_level: Optional[str]
    recommendation: Optional[str]
    referral_needed: bool
    referral_letter_url: Optional[str]
    qr_code_url: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
