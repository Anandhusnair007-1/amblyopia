"""
Auth router — nurse login, doctor login, token refresh, logout.
POST /api/auth/nurse-login
POST /api/auth/doctor-login
POST /api/auth/refresh-token
POST /api/auth/logout
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, get_device_id, get_redis, rate_limit
from app.schemas.auth import (
    DoctorLoginRequest,
    LogoutRequest,
    NurseLoginRequest,
    RefreshTokenRequest,
)
from app.services import audit_service
from app.services import auth_service
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/nurse-login")
async def nurse_login(
    body: NurseLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    redis=Depends(get_redis),
    _rl: None = Depends(rate_limit),
):
    """
    Nurse login with per-phone brute-force protection.
    10 attempts per 5-minute window enforced via Redis counter.
    """
    # Per-phone brute-force check
    from app.dependencies import login_rate_limit
    await login_rate_limit(body.phone_number, request, redis)

    result = await auth_service.authenticate_nurse(
        db, body.phone_number, body.password, body.device_id, redis
    )
    await audit_service.log_action(
        db, actor_id=None, actor_type="nurse",
        action="NURSE_LOGIN", resource_type="Nurse",
        ip_address=request.client.host if request.client else "unknown",
        device_id=body.device_id,
        new_value={"device_id": body.device_id},
    )
    return standard_response(result, "Login successful", device_id=body.device_id)


@router.post("/doctor-login")
async def doctor_login(
    body: DoctorLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    _rl: None = Depends(rate_limit),
):
    result = await auth_service.authenticate_doctor(body.hospital_id, body.password)
    await audit_service.log_action(
        db, actor_id=None, actor_type="doctor",
        action="DOCTOR_LOGIN", resource_type="Doctor",
        ip_address=request.client.host if request.client else "unknown",
        device_id="hospital-system",
    )
    return standard_response(result, "Login successful", device_id="hospital-system")


@router.post("/refresh-token")
async def refresh_token(
    body: RefreshTokenRequest,
    request: Request,
    redis=Depends(get_redis),
    _rl: None = Depends(rate_limit),
):
    """Rotate refresh token — old token is immediately invalidated."""
    result = await auth_service.refresh_access_token(body.refresh_token, redis)
    return standard_response(result, "Token refreshed", device_id="unknown")


@router.post("/logout")
async def logout(
    body: LogoutRequest,
    request: Request,
    current_user: dict = Depends(get_current_user),
    redis=Depends(get_redis),
    db: AsyncSession = Depends(get_db),
    device_id: str = Depends(get_device_id),
):
    auth_header = request.headers.get("Authorization", "")
    access_token = auth_header.replace("Bearer ", "").strip()

    await auth_service.logout(access_token, body.refresh_token, redis)
    await audit_service.log_action(
        db, actor_id=None, actor_type=current_user.get("role", "unknown"),
        action="LOGOUT", ip_address=request.client.host if request.client else "unknown",
        device_id=device_id,
    )
    return standard_response({}, "Logged out successfully", device_id=device_id)
