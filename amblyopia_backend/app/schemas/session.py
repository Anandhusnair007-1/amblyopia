"""
Session schemas — start and complete a screening session.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class SessionStart(BaseModel):
    patient_id: UUID
    nurse_id: UUID
    village_id: UUID
    device_id: str
    gps_lat: Optional[float] = None
    gps_lng: Optional[float] = None
    lighting_condition: Literal["good", "poor", "very_poor"] = "good"
    battery_level: Optional[int] = Field(None, ge=0, le=100)
    internet_available: bool = False


class SessionRead(BaseModel):
    id: UUID
    patient_id: UUID
    nurse_id: Optional[UUID]
    village_id: Optional[UUID]
    device_id: Optional[str]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    lighting_condition: Optional[str]
    battery_level: Optional[int]
    internet_available: bool
    sync_status: str

    model_config = {"from_attributes": True}


class SessionComplete(BaseModel):
    """Payload to complete a session — all test results bundled."""
    session_id: UUID
    # Optional because patient may not complete all tests
    gaze_result: Optional[dict] = None
    redgreen_result: Optional[dict] = None
    snellen_result: Optional[dict] = None
