"""
Audit Trail Middleware
Automatically logs every mutating request (POST/PUT/DELETE/PATCH) to the
audit_trail table. Reads user identity from the validated JWT payload stored
in request.state after authentication.

Non-blocking: exceptions in logging do NOT affect the response.
"""
from __future__ import annotations

import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)

_AUDIT_METHODS = {"POST", "PUT", "DELETE", "PATCH"}
_SKIP_PATHS = {"/health", "/ready", "/metrics", "/docs", "/openapi.json", "/redoc"}


class AuditTrailMiddleware(BaseHTTPMiddleware):
    """
    Intercepts mutating HTTP requests and writes an audit entry.
    Works with the async DB session — creates its own session per request
    to avoid interfering with the router's session lifecycle.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.perf_counter()
        response: Response = await call_next(request)
        elapsed_ms = int((time.perf_counter() - start) * 1000)

        if request.method not in _AUDIT_METHODS:
            return response
        if request.url.path in _SKIP_PATHS:
            return response

        # Fire-and-forget audit log — never blocks the response
        try:
            await _write_audit(request, response.status_code, elapsed_ms)
        except Exception as exc:
            logger.warning("Audit trail write failed: %s", exc)

        return response


async def _write_audit(request: Request, status_code: int, elapsed_ms: int) -> None:
    """Write a single audit row inside its own DB session."""
    from app.database import AsyncSessionLocal  # lazy import to avoid circular
    from app.services.audit_service import log_action

    user_payload: dict = getattr(request.state, "user_payload", {})
    actor_id = user_payload.get("sub")
    actor_type = user_payload.get("role", "unknown")
    request_id = getattr(request.state, "request_id", None)

    resource_type = request.url.path.split("/")[3] if len(request.url.path.split("/")) > 3 else "unknown"

    async with AsyncSessionLocal() as db:
        await log_action(
            db,
            actor_id=actor_id,
            actor_type=actor_type,
            action=f"HTTP_{request.method}",
            resource_type=resource_type,
            resource_id=None,
            ip_address=request.client.host if request.client else "unknown",
            device_id=request.headers.get("X-Device-ID", "unknown"),
            new_value={
                "path": request.url.path,
                "status_code": status_code,
                "elapsed_ms": elapsed_ms,
                "request_id": request_id,
            },
        )
