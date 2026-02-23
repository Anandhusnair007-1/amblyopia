"""
Dashboard router — admin overview, analytics, pilot dashboard.
GET /api/dashboard/overview
GET /api/dashboard/analytics
GET /api/dashboard/pilot-dashboard
"""
from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_doctor, get_device_id, rate_limit
from app.models.combined_result import CombinedResult
from app.models.nurse import Nurse
from app.models.patient import Patient
from app.models.session import ScreeningSession
from app.models.village import Village
from app.services.village_heatmap_service import get_coverage_stats
from app.utils.helpers import standard_response, utc_now

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/overview")
async def get_overview(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """High-level counts: patients, sessions, villages, nurses."""
    patients_q = await db.execute(select(func.count()).select_from(Patient).where(Patient.is_active))
    sessions_q = await db.execute(select(func.count()).select_from(ScreeningSession))
    villages_q = await db.execute(select(func.count()).select_from(Village))
    nurses_q = await db.execute(select(func.count()).select_from(Nurse).where(Nurse.is_active))
    referrals_q = await db.execute(
        select(func.count()).select_from(CombinedResult).where(CombinedResult.referral_needed)
    )

    coverage = await get_coverage_stats(db)

    return standard_response({
        "total_patients": patients_q.scalar(),
        "total_sessions": sessions_q.scalar(),
        "total_villages": villages_q.scalar(),
        "active_nurses": nurses_q.scalar(),
        "total_referrals": referrals_q.scalar(),
        "coverage": coverage,
    }, "Overview retrieved", device_id=device_id)


@router.get("/analytics")
async def get_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Distribution of severity grades across all screenings."""
    grade_q = await db.execute(
        select(CombinedResult.severity_grade, func.count())
        .group_by(CombinedResult.severity_grade)
    )
    grades = {row[0]: row[1] for row in grade_q.all()}

    risk_q = await db.execute(
        select(CombinedResult.risk_level, func.count())
        .group_by(CombinedResult.risk_level)
    )
    risk_levels = {row[0]: row[1] for row in risk_q.all()}

    # Monthly session trend (last 6 months)
    monthly = []
    for i in range(5, -1, -1):
        start = utc_now().replace(day=1) - timedelta(days=i * 30)
        end = start + timedelta(days=30)
        count_q = await db.execute(
            select(func.count()).where(
                ScreeningSession.started_at >= start,
                ScreeningSession.started_at < end,
            )
        )
        monthly.append({
            "month": start.strftime("%Y-%m"),
            "sessions": count_q.scalar() or 0,
        })

    return standard_response({
        "grade_distribution": grades,
        "risk_level_distribution": risk_levels,
        "monthly_session_trend": monthly,
    }, "Analytics retrieved", device_id=device_id)


@router.get("/pilot-dashboard")
async def pilot_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Aravind pilot dashboard: all critical metrics in one payload."""
    # Recent 7-day stats
    week_ago = utc_now() - timedelta(days=7)
    week_sessions_q = await db.execute(
        select(func.count()).where(ScreeningSession.started_at >= week_ago)
    )
    week_referrals_q = await db.execute(
        select(func.count()).select_from(CombinedResult)
        .join(ScreeningSession, ScreeningSession.id == CombinedResult.session_id)
        .where(CombinedResult.referral_needed, ScreeningSession.started_at >= week_ago)
    )
    coverage = await get_coverage_stats(db)

    nurse_q = await db.execute(
        select(Nurse).where(Nurse.is_active)
        .order_by(Nurse.performance_score.desc())
        .limit(5)
    )
    top_nurses = [
        {"id": str(n.id), "performance_score": float(n.performance_score or 0), "total_screenings": n.total_screenings}
        for n in nurse_q.scalars().all()
    ]

    return standard_response({
        "week_sessions": week_sessions_q.scalar(),
        "week_referrals": week_referrals_q.scalar(),
        "coverage": coverage,
        "top_nurses": top_nurses,
    }, "Pilot dashboard retrieved", device_id=device_id)

@router.get("/screening-trends")
async def get_screening_trends(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return stats for the KPI cards in the dashboard."""
    # Total screenings
    total_q = await db.execute(select(func.count()).select_from(ScreeningSession))
    total = total_q.scalar() or 0
    
    # Critical cases
    critical_q = await db.execute(
        select(func.count()).select_from(CombinedResult).where(CombinedResult.severity_grade == 3)
    )
    critical = critical_q.scalar() or 0
    
    # Pending reviews
    from app.models.doctor_review import DoctorReview
    pending_q = await db.execute(
        select(func.count())
        .select_from(CombinedResult)
        .outerjoin(DoctorReview, DoctorReview.session_id == CombinedResult.session_id)
        .where(CombinedResult.referral_needed, DoctorReview.id.is_(None))
    )
    pending = pending_q.scalar() or 0
    
    # Village coverage status
    villages_q = await db.execute(select(func.count()).select_from(Village))
    total_villages = villages_q.scalar() or 0
    
    return standard_response({
        "total_screenings": total,
        "critical_cases": critical,
        "pending_reviews": pending,
        "village_coverage": f"3/{total_villages}" if total_villages > 0 else "0/0",
        "week_growth": 12, # Placeholder or calculate
    }, "Screening trends retrieved", device_id=device_id)


@router.get("/village-heatmap")
async def get_village_heatmap(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return detailed village coverage status."""
    from app.services.village_heatmap_service import get_full_heatmap
    heatmap = await get_full_heatmap(db)
    return standard_response({"heatmap": heatmap}, "Village heatmap retrieved", device_id=device_id)


@router.get("/nurse-performance")
async def get_nurse_performance(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Return top performing nurses for the dashboard table."""
    result = await db.execute(
        select(Nurse).where(Nurse.is_active).order_by(Nurse.performance_score.desc()).limit(10)
    )
    nurses = result.scalars().all()
    data = [{
        "nurse_id": str(n.id),
        "total_screenings": n.total_screenings,
        "villages": len(n.assigned_villages or []),
        "quality": f"{int(n.performance_score or 0)}%",
        "last_active": n.last_active.strftime("%Y-%m-%d") if n.last_active else "Never",
    } for n in nurses]
    return standard_response({"nurses": data}, "Nurse performance retrieved", device_id=device_id)


@router.get("/research-export")
async def export_research_data(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_doctor),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Export anonymized screening data for research."""
    # Simplified export: return top 100 sessions as JSON
    q = await db.execute(select(ScreeningSession).limit(100))
    sessions = q.scalars().all()
    data = [{"id": str(s.id), "started_at": s.started_at.isoformat()} for s in sessions]
    return standard_response({"export": data}, "Research data exported", device_id=device_id)
