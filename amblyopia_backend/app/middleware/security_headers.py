"""
Security Headers Middleware — Helmet-style
==========================================
Adds HTTP security headers to every response.
Headers are tuned for a mobile-first medical API served over HTTPS in production.

Includes:
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 0  (modern browsers ignore this; CSP handles XSS)
- Strict-Transport-Security (HTTPS only)
- Referrer-Policy: strict-origin-when-cross-origin
- Permissions-Policy: disables browser APIs unnecessary for this API
- Content-Security-Policy: strict — API responses should never be rendered
- Cache-Control: no-store on all responses (prevents caching PHI)
- X-Request-ID passthrough (already set by RequestIDMiddleware)
"""
from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.config import settings

# Paths that serve Swagger UI — relax CSP so the UI can load its assets
_DOCS_PATHS = {"/docs", "/redoc", "/openapi.json"}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add Helmet-style security headers to every HTTP response."""

    async def dispatch(self, request: Request, call_next) -> Response:
        response: Response = await call_next(request)

        is_docs = request.url.path in _DOCS_PATHS

        # ── Prevent MIME-type sniffing ────────────────────────────────────────
        response.headers["X-Content-Type-Options"] = "nosniff"

        # ── Prevent framing (clickjacking) ────────────────────────────────────
        response.headers["X-Frame-Options"] = "DENY"

        # ── Disable legacy XSS filter (CSP supersedes it) ────────────────────
        response.headers["X-XSS-Protection"] = "0"

        # ── HSTS — production HTTPS only ─────────────────────────────────────
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains; preload"
            )

        # ── Referrer policy ───────────────────────────────────────────────────
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        # ── Permissions policy — disable unused browser APIs ─────────────────
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=(), "
            "payment=(), usb=(), interest-cohort=()"
        )

        # ── Content Security Policy ───────────────────────────────────────────
        if is_docs and settings.debug:
            # Swagger UI needs inline scripts and CDN assets
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "img-src 'self' data: https://fastapi.tiangolo.com; "
                "connect-src 'self';"
            )
        else:
            # Pure API responses — nothing should be rendered
            response.headers["Content-Security-Policy"] = (
                "default-src 'none'; frame-ancestors 'none';"
            )

        # ── Cache control — never cache API responses (PHI protection) ────────
        if request.url.path not in {"/health", "/ready"}:
            response.headers["Cache-Control"] = "no-store, max-age=0"
            response.headers["Pragma"] = "no-cache"

        # ── Remove server fingerprint ─────────────────────────────────────────
        response.headers.pop("Server", None)
        response.headers.pop("X-Powered-By", None)

        return response
