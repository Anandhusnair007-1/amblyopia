"""
GazeResult schemas — input and output for gaze tracking data.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class GazeResultCreate(BaseModel):
    session_id: UUID
    left_gaze_x: Optional[float] = None
    left_gaze_y: Optional[float] = None
    right_gaze_x: Optional[float] = None
    right_gaze_y: Optional[float] = None
    left_fixation_stability: Optional[float] = None
    right_fixation_stability: Optional[float] = None
    gaze_asymmetry_score: Optional[float] = None
    left_blink_ratio: Optional[float] = None
    right_blink_ratio: Optional[float] = None
    blink_asymmetry: Optional[float] = None
    left_blink_count: Optional[int] = None
    right_blink_count: Optional[int] = None
    frames_analyzed: Optional[int] = None
    session_duration_seconds: Optional[int] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    result: Optional[Literal[
        "symmetric", "asymmetry_detected", "unable_to_detect"
    ]] = None


class GazeResultRead(BaseModel):
    id: UUID
    session_id: UUID
    left_gaze_x: Optional[float]
    left_gaze_y: Optional[float]
    right_gaze_x: Optional[float]
    right_gaze_y: Optional[float]
    left_fixation_stability: Optional[float]
    right_fixation_stability: Optional[float]
    gaze_asymmetry_score: Optional[float]
    left_blink_ratio: Optional[float]
    right_blink_ratio: Optional[float]
    blink_asymmetry: Optional[float]
    frames_analyzed: Optional[int]
    session_duration_seconds: Optional[int]
    confidence_score: Optional[float]
    result: Optional[str]
    needs_doctor_review: bool
    created_at: datetime

    model_config = {"from_attributes": True}
