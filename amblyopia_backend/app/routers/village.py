"""
Village router — heatmap status, coverage data.
GET /api/village/all
GET /api/village/heatmap-data
GET /api/village/{village_id}
PUT /api/village/{village_id}/update-status
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.village import Village
from app.services.village_heatmap_service import (
    calculate_village_status,
    get_coverage_stats,
    get_full_heatmap,
)
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/village", tags=["village"])


@router.post("/create")
async def create_village(
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    _rl: None = Depends(rate_limit),
):
    """Create a new village."""
    v = Village(
        name=body.get("name"),
        district=body.get("district"),
        state=body.get("state"),
        lat=body.get("lat"),
        lng=body.get("lng"),
        estimated_population=body.get("estimated_population"),
        children_under_7=body.get("children_under_7"),
    )
    db.add(v)
    await db.flush()
    return standard_response({
        "id": str(v.id), "name": v.name
    }, "Village created", device_id="unknown")


@router.get("/all")
async def get_all_villages(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    result = await db.execute(select(Village))
    villages = result.scalars().all()
    data = [{
        "id": str(v.id), "name": v.name, "district": v.district,
        "state": v.state, "screening_status": v.screening_status,
        "estimated_population": v.estimated_population,
        "last_screened_date": v.last_screened_date.isoformat() if v.last_screened_date else None,
    } for v in villages]
    return standard_response({"villages": data, "total": len(data)}, "Villages retrieved", device_id=device_id)


@router.get("/heatmap-data")
async def get_heatmap_data(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    heatmap = await get_full_heatmap(db)
    stats = await get_coverage_stats(db)
    return standard_response({"heatmap": heatmap, "stats": stats}, "Heatmap data retrieved", device_id=device_id)


@router.get("/{village_id}")
async def get_village(
    village_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    result = await db.execute(select(Village).where(Village.id == village_id))
    v = result.scalar_one_or_none()
    if not v:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Village not found")
    data = {
        "id": str(v.id), "name": v.name, "district": v.district,
        "state": v.state, "lat": float(v.lat) if v.lat else None,
        "lng": float(v.lng) if v.lng else None,
        "screening_status": v.screening_status,
        "estimated_population": v.estimated_population,
        "children_under_7": v.children_under_7,
        "assigned_nurse_id": str(v.assigned_nurse_id) if v.assigned_nurse_id else None,
        "last_screened_date": v.last_screened_date.isoformat() if v.last_screened_date else None,
    }
    return standard_response(data, "Village retrieved", device_id=device_id)


@router.put("/{village_id}/update-status")
async def update_village_status(
    village_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    result = await calculate_village_status(db, village_id)
    return standard_response(result, "Village status updated", device_id=device_id)
