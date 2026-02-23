"""
Amblyopia Care System — Dependencies Module
FastAPI dependency injection for auth, DB sessions, Redis, and rate limiting.
"""
from __future__ import annotations

import asyncio
import time
from typing import Optional
from uuid import UUID

import redis.asyncio as aioredis
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db

security = HTTPBearer()

# ── Redis Pool ───────────────────────────────────────────────────────────────
_redis_pool: Optional[aioredis.Redis] = None
_last_redis_loop: Optional[asyncio.AbstractEventLoop] = None


async def get_redis() -> aioredis.Redis:
    """Return shared Redis connection, ensuring it's for the current loop."""
    global _redis_pool, _last_redis_loop
    
    try:
        current_loop = asyncio.get_running_loop()
    except RuntimeError:
        current_loop = None

    # Check if pool exists and is still functional in this loop
    if _redis_pool is not None and _last_redis_loop == current_loop:
        try:
            # Simple ping to verify loop connectivity
            await _redis_pool.ping()
        except Exception:
            # If ping fails, reset pool
            _redis_pool = None

    if _redis_pool is None or _last_redis_loop != current_loop:
        _redis_pool = aioredis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
        _last_redis_loop = current_loop
    return _redis_pool


# ── JWT Auth ─────────────────────────────────────────────────────────────────
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
) -> dict:
    """Validate JWT token and return the current user payload."""
    from app.utils.security import decode_access_token, get_jti

    token = credentials.credentials

    # Extract JTI and check the JTI-based blacklist written by logout/rotation.
    # NOTE: auth_service writes `jti_blacklist:{jti}`, so we MUST key by JTI —
    # NOT by the full token string (old `blacklist:{token}` key was never matched).
    jti = get_jti(token)
    if jti:
        is_blacklisted = await redis.get(f"jti_blacklist:{jti}")
        if is_blacklisted:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has been revoked",
            )

    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    return payload


async def get_current_nurse(
    current_user: dict = Depends(get_current_user),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Ensure the current user is a nurse with matching device_id."""
    from app.models.nurse import Nurse

    if current_user.get("role") not in ("nurse", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Nurse access required",
        )

    nurse_id = current_user.get("sub")
    device_id = current_user.get("device_id")

    # Validate device binding
    result = await db.execute(select(Nurse).where(Nurse.id == UUID(nurse_id)))
    nurse = result.scalar_one_or_none()
    if nurse is None or not nurse.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nurse account not found or inactive",
        )

    if nurse.device_id and nurse.device_id != device_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Device not authorized for this account",
        )

    current_user["nurse"] = nurse
    return current_user


async def get_current_doctor(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Ensure the current user is a doctor."""
    if current_user.get("role") not in ("doctor", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctor access required",
        )
    return current_user


async def get_current_admin(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Ensure the current user is an admin."""
    if current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user


# ── Rate Limiting ────────────────────────────────────────────────────────────
async def rate_limit(
    request: Request,
    redis: aioredis.Redis = Depends(get_redis),
) -> None:
    """Sliding-window rate limiter: 100 requests/minute per IP."""
    client_ip = request.client.host if request.client else "unknown"
    key = f"rate:{client_ip}"
    current_minute = int(time.time() // 60)
    window_key = f"{key}:{current_minute}"

    count = await redis.incr(window_key)
    if count == 1:
        await redis.expire(window_key, 60)

    if count > settings.rate_limit_per_minute:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Maximum 100 requests per minute.",
        )


# ── Device ID Extractor ──────────────────────────────────────────────────────
def get_device_id(request: Request) -> str:
    """Extract device_id from request headers or default."""
    return request.headers.get("X-Device-ID", "unknown")


# ── Login-Specific Rate Limiter ───────────────────────────────────────────────
async def login_rate_limit(
    body_phone: str,
    request: Request,
    redis: aioredis.Redis = Depends(get_redis),
) -> None:
    """
    Per-nurse brute-force protection:
      max 10 login attempts per phone number per 5-minute window.
    Raises HTTP 429 on breach; key expires automatically.
    """
    from app.services.encryption_service import hash_phone
    phone_hash = hash_phone(body_phone)
    key = f"login_attempts:{phone_hash}"
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, settings.login_rate_window_seconds)
    if count > settings.login_max_attempts:
        retry_after = await redis.ttl(key)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"Too many login attempts. Try again in {retry_after} seconds."
            ),
            headers={"Retry-After": str(max(retry_after, 0))},
        )


async def clear_login_attempts(phone_number: str, redis: aioredis.Redis) -> None:
    """Clear brute-force counter on successful login."""
    from app.services.encryption_service import hash_phone
    phone_hash = hash_phone(phone_number)
    await redis.delete(f"login_attempts:{phone_hash}")
