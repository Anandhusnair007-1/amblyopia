"""
Global Exception Handlers
Standard error response format:
{
  "error_code": "...",
  "message": "...",
  "timestamp": "...",
  "request_id": "..."
}

Stack traces are NEVER exposed in production.
"""
from __future__ import annotations

import logging
import traceback
from datetime import datetime, timezone

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from app.config import settings

logger = logging.getLogger(__name__)


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "unknown")


def _ts() -> str:
    return datetime.now(timezone.utc).isoformat()


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """Handle FastAPI HTTPExceptions with standard body."""
    logger.warning(
        "HTTP %d on %s — %s [req=%s]",
        exc.status_code, request.url.path, exc.detail, _request_id(request),
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error_code": f"HTTP_{exc.status_code}",
            "message": exc.detail,
            "timestamp": _ts(),
            "request_id": _request_id(request),
        },
        headers=exc.headers or {},
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Handle Pydantic request validation failures (422)."""
    errors = exc.errors()
    # Sanitize field paths for the response
    messages = [
        f"{' → '.join(str(loc) for loc in e['loc'])}: {e['msg']}"
        for e in errors
    ]
    logger.info(
        "Validation error on %s: %s [req=%s]",
        request.url.path, messages, _request_id(request),
    )
    return JSONResponse(
        status_code=422,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": messages,
            "timestamp": _ts(),
            "request_id": _request_id(request),
        },
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catch-all for unexpected exceptions.
    Logs full traceback internally; returns safe message to client.
    """
    tb = traceback.format_exc()
    logger.error(
        "Unhandled exception on %s [req=%s]:\n%s",
        request.url.path, _request_id(request), tb,
    )

    # Never leak stack traces in production
    detail = str(exc) if settings.debug else "An internal server error occurred. Please try again."

    return JSONResponse(
        status_code=500,
        content={
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": detail,
            "timestamp": _ts(),
            "request_id": _request_id(request),
        },
    )
