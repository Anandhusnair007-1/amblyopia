"""
Village schemas — geographic data and heatmap status.
"""
from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel


ScreeningStatus = Literal["green", "yellow", "red"]


class VillageRead(BaseModel):
    id: UUID
    name: str
    district: Optional[str]
    state: Optional[str]
    lat: Optional[float]
    lng: Optional[float]
    last_screened_date: Optional[datetime]
    screening_status: str
    estimated_population: Optional[int]
    children_under_7: Optional[int]
    assigned_nurse_id: Optional[UUID]

    model_config = {"from_attributes": True}


class VillageHeatmapEntry(BaseModel):
    id: UUID
    name: str
    lat: Optional[float]
    lng: Optional[float]
    screening_status: str
    last_screened_date: Optional[datetime]
    district: Optional[str]
    state: Optional[str]

    model_config = {"from_attributes": True}


class VillageStatusUpdate(BaseModel):
    """Returned after recalculating a village's heatmap status."""
    village_id: UUID
    old_status: str
    new_status: str
    last_screened_date: Optional[datetime]
    days_since_screening: Optional[int]
