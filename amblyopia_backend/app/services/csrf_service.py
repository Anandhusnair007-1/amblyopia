"""
CSRF Protection Service
Provides HMAC-SHA256 double-submit cookie pattern for the admin web control panel.

Usage:
  1. GET /api/auth/csrf-token → returns a token
  2. Client stores token and sends as X-CSRF-Token header on state-changing requests
  3. Validate via verify_csrf_token() in relevant endpoints
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
import time

from app.config import settings

_CSRF_TTL_SECONDS = 3600  # 1 hour


def generate_csrf_token(session_id: str) -> str:
    """
    Generate a CSRF token tied to the session_id and a timestamp.
    Format: <timestamp>.<hmac> (URL-safe)
    """
    timestamp = str(int(time.time()))
    raw = f"{session_id}:{timestamp}"
    sig = hmac.new(
        settings.secret_key.encode(),
        raw.encode(),
        hashlib.sha256,
    ).hexdigest()
    return f"{timestamp}.{sig}"


def verify_csrf_token(token: str, session_id: str) -> bool:
    """
    Verify a CSRF token matches the session and hasn't expired.
    Returns True if valid, False otherwise.
    """
    if not token or "." not in token:
        return False
    try:
        timestamp_str, received_sig = token.split(".", 1)
        timestamp = int(timestamp_str)
    except (ValueError, TypeError):
        return False

    # Expiry check
    if int(time.time()) - timestamp > _CSRF_TTL_SECONDS:
        return False

    # Recompute expected signature
    raw = f"{session_id}:{timestamp_str}"
    expected_sig = hmac.new(
        settings.secret_key.encode(),
        raw.encode(),
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected_sig, received_sig)
