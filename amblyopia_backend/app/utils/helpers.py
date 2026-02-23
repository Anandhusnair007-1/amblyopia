"""
Amblyopia Care System — Helpers
Common response formatting, datetime utilities, India timezone support.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID

import pytz

INDIA_TZ = pytz.timezone("Asia/Kolkata")


def now_india() -> datetime:
    """Return current datetime in IST."""
    return datetime.now(INDIA_TZ)


def utc_now() -> datetime:
    """Return current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)


def format_iso(dt: Optional[datetime]) -> Optional[str]:
    """Format a datetime to ISO 8601 string, or None."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = pytz.utc.localize(dt)
    return dt.astimezone(INDIA_TZ).isoformat()


def standard_response(
    data: Any,
    message: str = "Success",
    success: bool = True,
    device_id: str = "unknown",
) -> dict:
    """Build the standard API response envelope."""
    return {
        "success": success,
        "data": data,
        "message": message,
        "timestamp": now_india().isoformat(),
        "device_id": device_id,
    }


def error_response(message: str, device_id: str = "unknown") -> dict:
    """Build a standard error response envelope."""
    return {
        "success": False,
        "data": {},
        "message": message,
        "timestamp": now_india().isoformat(),
        "device_id": device_id,
    }


def uuid_to_str(val: Any) -> Optional[str]:
    """Convert UUID to string safely."""
    if val is None:
        return None
    return str(val)
