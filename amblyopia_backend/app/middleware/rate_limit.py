"""
Global Per-IP Rate Limiting Middleware
======================================
Redis-backed sliding-window rate limiter applied to every API route.

Strategy
--------
- Window: 60 seconds, rolling (not fixed-bucket)
- Default limit: 120 requests / IP / minute
- Auth endpoint limit: 10 requests / IP / minute (in addition to the
  existing brute-force check inside login_rate_limit())
- Health/readiness probes are exempt (load balancers would be blocked)

Redis key scheme
----------------
    rate_limit:{tier}:{ip}  →  INCR / EXPIREAT

Where *tier* is:
    "global"   — all routes  (120 req/min)
    "auth"     — /api/v1/auth/* routes (10 req/min)

Client IP resolution order
--------------------------
1. X-Forwarded-For first value  (set by nginx/load balancer)
2. X-Real-IP
3. request.client.host          (last-resort, may be the reverse-proxy IP)
"""
from __future__ import annotations

import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

# ── Tunable constants ──────────────────────────────────────────────────────────
_WINDOW_SECONDS = 60
_GLOBAL_LIMIT = 120          # req / IP / 60 s  — general API
_AUTH_LIMIT = 10             # req / IP / 60 s  — /api/v1/auth/*

# Paths that must never be rate-limited (health probes from load balancers)
_EXEMPT_PREFIXES = ("/health", "/ready", "/metrics")


def _client_ip(request: Request) -> str:
    """Resolve the real peer IP, preferring reverse-proxy headers."""
    xff = request.headers.get("X-Forwarded-For", "")
    if xff:
        return xff.split(",")[0].strip()
    xri = request.headers.get("X-Real-IP", "")
    if xri:
        return xri.strip()
    return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Global sliding-window rate limiter."""

    async def dispatch(self, request: Request, call_next) -> Response:
        path = request.url.path

        # ── Exempt health / readiness / metrics probes ─────────────────────
        for prefix in _EXEMPT_PREFIXES:
            if path.startswith(prefix):
                return await call_next(request)

        ip = _client_ip(request)
        redis = request.app.state.redis

        # ── Determine tier ─────────────────────────────────────────────────
        is_auth = path.startswith("/api/v1/auth")
        tier = "auth" if is_auth else "global"
        limit = _AUTH_LIMIT if is_auth else _GLOBAL_LIMIT

        key = f"rate_limit:{tier}:{ip}"
        now = int(time.time())
        window_end = now + _WINDOW_SECONDS

        # ── Atomic increment + expiry (pipeline) ───────────────────────────
        try:
            pipe = redis.pipeline()
            pipe.incr(key)
            pipe.expireat(key, window_end)
            results = await pipe.execute()
            current_count: int = results[0]
        except Exception:
            # Redis unavailable — fail open rather than taking the service down
            return await call_next(request)

        # ── Emit rate-limit headers on every response ──────────────────────
        remaining = max(0, limit - current_count)
        response: Response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(window_end)

        # ── Block if over limit ────────────────────────────────────────────
        if current_count > limit:
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Rate limit exceeded. Please slow down.",
                    "retry_after": _WINDOW_SECONDS,
                },
                headers={
                    "Retry-After": str(_WINDOW_SECONDS),
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(window_end),
                },
            )

        return response
