"""
Nurse router — profile, villages, device specs, performance stats.
GET /api/nurse/profile
GET /api/nurse/assigned-villages
PUT /api/nurse/update-device-specs
GET /api/nurse/performance-stats
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.models.nurse import Nurse
from app.models.session import ScreeningSession
from app.models.village import Village
from app.schemas.nurse import UpdateDeviceSpecsRequest
from app.services import audit_service
from app.utils.helpers import standard_response, utc_now

router = APIRouter(prefix="/api/nurse", tags=["nurse"])


@router.get("/profile")
async def get_profile(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    nurse: Nurse = current_user["nurse"]
    data = {
        "id": str(nurse.id),
        "device_id": nurse.device_id,
        "device_specs": nurse.device_specs,
        "performance_score": float(nurse.performance_score or 0),
        "total_screenings": nurse.total_screenings,
        "language_preference": nurse.language_preference,
        "last_active": nurse.last_active.isoformat() if nurse.last_active else None,
        "assigned_villages": [str(v) for v in (nurse.assigned_villages or [])],
    }
    return standard_response(data, "Profile retrieved", device_id=device_id)


@router.get("/assigned-villages")
async def get_assigned_villages(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    nurse: Nurse = current_user["nurse"]
    village_ids = nurse.assigned_villages or []

    if not village_ids:
        return standard_response({"villages": [], "total": 0}, "No villages assigned", device_id=device_id)

    result = await db.execute(select(Village).where(Village.id.in_(village_ids)))
    villages = result.scalars().all()

    data = [{
        "id": str(v.id),
        "name": v.name,
        "district": v.district,
        "state": v.state,
        "screening_status": v.screening_status,
        "last_screened_date": v.last_screened_date.isoformat() if v.last_screened_date else None,
        "estimated_population": v.estimated_population,
    } for v in villages]

    return standard_response({"villages": data, "total": len(data)}, "Villages retrieved", device_id=device_id)


@router.put("/update-device-specs")
async def update_device_specs(
    body: UpdateDeviceSpecsRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    nurse: Nurse = current_user["nurse"]
    nurse.device_specs = {
        "camera_mp": body.camera_mp,
        "ram_gb": body.ram_gb,
        "os_version": body.os_version,
        "android_version": body.android_version,
        "updated_at": utc_now().isoformat(),
    }
    await db.flush()
    await audit_service.log_action(
        db, actor_id=nurse.id, actor_type="nurse",
        action="UPDATE_DEVICE_SPECS", resource_type="Nurse", resource_id=nurse.id,
        ip_address=request.client.host, device_id=device_id,
        new_value=nurse.device_specs,
    )
    return standard_response({"updated": True}, "Device specs updated", device_id=device_id)


@router.get("/performance-stats")
async def get_performance_stats(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    nurse: Nurse = current_user["nurse"]
    from datetime import timedelta

    # Screenings this week
    week_ago = utc_now() - timedelta(days=7)
    week_q = await db.execute(
        select(func.count()).where(
            ScreeningSession.nurse_id == nurse.id,
            ScreeningSession.started_at >= week_ago,
        )
    )
    screenings_week = week_q.scalar() or 0

    # Villages covered this month
    month_ago = utc_now() - timedelta(days=30)
    vill_q = await db.execute(
        select(func.count(ScreeningSession.village_id.distinct())).where(
            ScreeningSession.nurse_id == nurse.id,
            ScreeningSession.started_at >= month_ago,
        )
    )
    villages_covered = vill_q.scalar() or 0

    data = {
        "nurse_id": str(nurse.id),
        "total_screenings": nurse.total_screenings,
        "screenings_this_week": screenings_week,
        "performance_score": float(nurse.performance_score or 0),
        "villages_covered_this_month": villages_covered,
        "language_preference": nurse.language_preference,
    }
    return standard_response(data, "Performance stats retrieved", device_id=device_id)
