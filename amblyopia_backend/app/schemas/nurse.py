"""
Nurse schemas — profile, performance, device specs.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class NurseProfile(BaseModel):
    id: UUID
    assigned_villages: List[UUID]
    device_id: Optional[str]
    device_specs: Optional[Dict[str, Any]]
    performance_score: float
    total_screenings: int
    language_preference: str
    last_active: Optional[datetime]
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UpdateDeviceSpecsRequest(BaseModel):
    camera_mp: float = Field(..., description="Camera resolution in megapixels")
    ram_gb: float = Field(..., description="Available RAM in GB")
    os_version: str = Field(..., description="Operating system version string")
    android_version: Optional[str] = None


class NursePerformanceStats(BaseModel):
    nurse_id: UUID
    screenings_this_week: int
    screenings_this_month: int
    quality_score: float
    villages_covered: int
    ranking: int
    total_screenings: int
    average_session_duration_minutes: Optional[float]


class AssignedVillage(BaseModel):
    id: UUID
    name: str
    district: Optional[str]
    state: Optional[str]
    screening_status: str
    last_screened_date: Optional[datetime]
    estimated_population: Optional[int]

    model_config = {"from_attributes": True}
