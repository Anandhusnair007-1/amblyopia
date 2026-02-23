"""
Amblyopia Care System — Village Heatmap Service
Calculates green/yellow/red status for each village based on last screening date.
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta
from typing import List, Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.village import Village
from app.utils.helpers import utc_now

GREEN_THRESHOLD_DAYS = 30
YELLOW_THRESHOLD_DAYS = 90


def _calculate_status(last_screened: Optional[datetime]) -> str:
    """Return green/yellow/red based on days since last screening."""
    if last_screened is None:
        return "red"
    if last_screened.tzinfo is None:
        last_screened = last_screened.replace(tzinfo=timezone.utc)
    days_ago = (utc_now() - last_screened).days
    if days_ago < GREEN_THRESHOLD_DAYS:
        return "green"
    elif days_ago < YELLOW_THRESHOLD_DAYS:
        return "yellow"
    return "red"


async def calculate_village_status(
    db: AsyncSession, village_id: UUID
) -> dict:
    """Recalculate and persist a single village's heatmap status."""
    result = await db.execute(select(Village).where(Village.id == village_id))
    village = result.scalar_one_or_none()
    if village is None:
        return {"error": "Village not found"}

    old_status = village.screening_status
    new_status = _calculate_status(village.last_screened_date)

    last = village.last_screened_date
    if last and last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)
    days_since = (utc_now() - last).days if last else None

    village.screening_status = new_status
    await db.flush()

    return {
        "village_id": str(village.id),
        "old_status": old_status,
        "new_status": new_status,
        "last_screened_date": village.last_screened_date.isoformat() if village.last_screened_date else None,
        "days_since_screening": days_since,
    }


async def get_full_heatmap(db: AsyncSession) -> List[dict]:
    """Return all villages with latest calculated status."""
    result = await db.execute(select(Village))
    villages = result.scalars().all()

    heatmap = []
    for v in villages:
        status = _calculate_status(v.last_screened_date)
        if v.screening_status != status:
            v.screening_status = status
        heatmap.append({
            "id": str(v.id),
            "name": v.name,
            "district": v.district,
            "state": v.state,
            "lat": float(v.lat) if v.lat else None,
            "lng": float(v.lng) if v.lng else None,
            "screening_status": status,
            "last_screened_date": v.last_screened_date.isoformat() if v.last_screened_date else None,
        })
    await db.flush()
    return heatmap


async def get_coverage_stats(db: AsyncSession) -> dict:
    """Return counts of green/yellow/red villages and coverage percentage."""
    result = await db.execute(select(Village))
    villages = result.scalars().all()

    green = yellow = red = 0
    for v in villages:
        status = _calculate_status(v.last_screened_date)
        if status == "green":
            green += 1
        elif status == "yellow":
            yellow += 1
        else:
            red += 1

    total = len(villages)
    coverage_pct = round((green / total * 100) if total else 0, 1)

    return {
        "total_villages": total,
        "green": green,
        "yellow": yellow,
        "red": red,
        "coverage_percentage": coverage_pct,
    }
