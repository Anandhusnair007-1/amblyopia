"""
RedgreenResult schemas — dichoptic test input/output.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class RedgreenResultCreate(BaseModel):
    session_id: UUID
    left_pupil_diameter: Optional[float] = None
    right_pupil_diameter: Optional[float] = None
    asymmetry_ratio: Optional[float] = None
    suppression_flag: bool = False
    dominant_eye: Optional[Literal["left", "right", "equal"]] = None
    binocular_score: Optional[int] = Field(None, ge=1, le=3)
    constriction_speed_left: Optional[float] = None
    constriction_speed_right: Optional[float] = None
    constriction_amount_left: Optional[float] = None
    constriction_amount_right: Optional[float] = None
    result: Optional[str] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)


class RedgreenResultRead(BaseModel):
    id: UUID
    session_id: UUID
    left_pupil_diameter: Optional[float]
    right_pupil_diameter: Optional[float]
    asymmetry_ratio: Optional[float]
    suppression_flag: bool
    dominant_eye: Optional[str]
    binocular_score: Optional[int]
    constriction_speed_left: Optional[float]
    constriction_speed_right: Optional[float]
    constriction_amount_left: Optional[float]
    constriction_amount_right: Optional[float]
    result: Optional[str]
    confidence_score: Optional[float]
    needs_doctor_review: bool
    created_at: datetime

    model_config = {"from_attributes": True}
