"""
Amblyopia Care System — Auth Service
Handles nurse and doctor authentication, token lifecycle.
- JTI stored in Redis for granular token revocation.
- Brute-force counter cleared on successful login.
- Refresh token rotation: old refresh token invalidated on each use.
"""
from __future__ import annotations

from datetime import timedelta
from typing import Optional
from uuid import UUID

import redis.asyncio as aioredis
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.nurse import Nurse
from app.services.encryption_service import decrypt, hash_phone
from app.utils.helpers import utc_now
from app.utils.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    get_jti,
    verify_password,
)


async def authenticate_nurse(
    db: AsyncSession,
    phone_number: str,
    password: str,
    device_id: str,
    redis: aioredis.Redis = None,
) -> dict:
    """
    Authenticate a nurse by phone hash + password.
    Validates device binding on subsequent logins.
    Clears brute-force counter on success.
    Returns token pair + nurse profile.
    """
    phone_hash = hash_phone(phone_number)

    result = await db.execute(
        select(Nurse).where(Nurse.phone_number == phone_hash, Nurse.is_active == True)
    )
    nurse = result.scalar_one_or_none()

    if nurse is None or not verify_password(password, nurse.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password",
        )

    # Device binding check
    if nurse.device_id and nurse.device_id != device_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is bound to a different device. Contact admin.",
        )

    # First login — bind device
    if not nurse.device_id:
        nurse.device_id = device_id
        await db.flush()

    # Update last_active
    nurse.last_active = utc_now()
    await db.flush()

    # Clear brute-force counter on success
    if redis is not None:
        from app.dependencies import clear_login_attempts
        await clear_login_attempts(phone_number, redis)

    token_data = {
        "sub": str(nurse.id),
        "role": "nurse",
        "device_id": device_id,
    }
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    # Store refresh JTI in Redis for rotation tracking
    if redis is not None:
        rt_jti = get_jti(refresh_token)
        if rt_jti:
            ttl = settings.refresh_token_expire_days * 86400
            await redis.setex(f"rt_jti:{str(nurse.id)}:{rt_jti}", ttl, "valid")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.access_token_expire_minutes * 60,
        "nurse_profile": {
            "id": str(nurse.id),
            "device_id": nurse.device_id,
            "language_preference": nurse.language_preference,
            "total_screenings": nurse.total_screenings,
            "performance_score": float(nurse.performance_score or 0),
            "assigned_villages": [str(v) for v in (nurse.assigned_villages or [])],
        },
    }


async def authenticate_doctor(
    hospital_id: str,
    password: str,
) -> dict:
    """
    Authenticate a doctor by hospital_id and password.
    NOTE: Replace with hospital LDAP/SSO in production.
    """
    if not hospital_id or not password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="hospital_id and password are required",
        )

    doctor_uuid = "00000000-0000-0000-0000-" + hospital_id.replace("-", "").zfill(12)[:12]

    token_data = {
        "sub": doctor_uuid,
        "role": "doctor",
        "hospital_id": hospital_id,
        "device_id": "hospital-system",
    }
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.access_token_expire_minutes * 60,
        "doctor_profile": {
            "doctor_id": doctor_uuid,
            "hospital_id": hospital_id,
            "role": "doctor",
        },
    }


async def refresh_access_token(
    refresh_token: str,
    redis: aioredis.Redis,
) -> dict:
    """
    Validate refresh token and issue new access + refresh token pair.
    Old refresh token is blacklisted immediately (rotation).
    """
    # Check blacklist by full token
    is_blacklisted = await redis.get(f"blacklist:{refresh_token}")
    if is_blacklisted:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked",
        )

    payload = decode_refresh_token(refresh_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # Check JTI is still valid (not rotated away)
    rt_jti = payload.get("jti")
    user_id = payload.get("sub")
    if rt_jti and user_id:
        jti_key = f"rt_jti:{user_id}:{rt_jti}"
        jti_valid = await redis.get(jti_key)
        if jti_valid is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token has been rotated or revoked",
            )
        # Invalidate old JTI immediately
        await redis.delete(jti_key)

    # Blacklist the raw old refresh token
    old_rt_ttl = settings.refresh_token_expire_days * 86400
    await redis.setex(f"blacklist:{refresh_token}", old_rt_ttl, "1")

    # Issue new token pair
    new_token_data = {
        "sub": payload["sub"],
        "role": payload.get("role"),
        "device_id": payload.get("device_id"),
    }
    new_access = create_access_token(new_token_data)
    new_refresh = create_refresh_token(new_token_data)

    # Register new refresh JTI
    new_rt_jti = get_jti(new_refresh)
    if new_rt_jti and user_id:
        await redis.setex(
            f"rt_jti:{user_id}:{new_rt_jti}",
            settings.refresh_token_expire_days * 86400,
            "valid",
        )

    return {
        "access_token": new_access,
        "refresh_token": new_refresh,
        "token_type": "bearer",
        "expires_in": settings.access_token_expire_minutes * 60,
    }


async def logout(
    access_token: str,
    refresh_token: str,
    redis: aioredis.Redis,
) -> None:
    """
    Blacklist both tokens by JTI in Redis.
    JTI-based blacklisting is O(1) and compact.
    """
    at_ttl = settings.access_token_expire_minutes * 60
    rt_ttl = settings.refresh_token_expire_days * 86400

    # Blacklist by JTI
    at_jti = get_jti(access_token)
    rt_jti = get_jti(refresh_token)

    if at_jti:
        await redis.setex(f"jti_blacklist:{at_jti}", at_ttl, "1")
    # Also blacklist full token for backward compat (existing sessions)
    await redis.setex(f"blacklist:{access_token}", at_ttl, "1")

    if rt_jti:
        await redis.setex(f"jti_blacklist:{rt_jti}", rt_ttl, "1")
    await redis.setex(f"blacklist:{refresh_token}", rt_ttl, "1")
