"""
Amblyopia Care System — FastAPI Application Entry Point
All routers registered here. Startup and shutdown lifecycle hooks.
"""
from __future__ import annotations

import logging
import logging.config
import json
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import settings
from app.database import engine  # type: ignore
from app.middleware.request_id import RequestIDMiddleware
from app.middleware.audit_log import AuditTrailMiddleware
from app.middleware.security_headers import SecurityHeadersMiddleware
from app.middleware.rate_limit import RateLimitMiddleware
from app.middleware.metrics import PrometheusMiddleware, metrics_endpoint
from app.middleware.exception_handlers import (
    http_exception_handler,
    validation_exception_handler,
    unhandled_exception_handler,
)
from app.routers import (
    auth,
    dashboard,
    doctor,
    gaze,
    notifications,
    nurse,
    patient,
    redgreen,
    screening,
    snellen,
    sync,
    village,
    control_panel,
)

# ── Logging setup ─────────────────────────────────────────────────────────────

def _configure_logging() -> None:
    """Configure JSON logging in production, plain text in development."""
    log_level = settings.log_level.upper()

    if settings.log_json:
        # JSON format for production log aggregation (ELK / Cloud Logging)
        fmt = json.dumps({
            "time": "%(asctime)s",
            "level": "%(levelname)s",
            "logger": "%(name)s",
            "message": "%(message)s",
        })
        fmt = '{"time":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","msg":"%(message)s"}'
        logging.basicConfig(level=log_level, format=fmt)
    else:
        logging.basicConfig(
            level=log_level,
            format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        )


_configure_logging()
logger = logging.getLogger(__name__)


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: connect DB, init Sentry, warm-up MLflow model. Shutdown: dispose engine."""
    logger.info("Starting Amblyopia Care System API (env=%s)...", settings.environment)

    # Ensure engine and session factory are created in the current event loop
    global engine
    from app import database
    database.engine = database.create_engine_instance()
    database.AsyncSessionLocal = database.create_session_factory(database.engine)
    engine = database.engine

    # Sentry error tracking
    if settings.sentry_dsn:
        try:
            import sentry_sdk
            sentry_sdk.init(
                dsn=settings.sentry_dsn,
                environment=settings.environment,
                traces_sample_rate=0.1,
            )
            logger.info("Sentry initialized")
        except Exception as exc:
            logger.warning("Sentry init failed: %s", exc)

    # Pre-warm MLflow production model
    try:
        from app.services.mlflow_model_service import warm_up_production_model
        await warm_up_production_model()
    except Exception as exc:
        logger.warning("MLflow warm-up skipped: %s", exc)

    yield

    # Shutdown
    await engine.dispose()
    logger.info("Database engine disposed")


# ── App Instance ───────────────────────────────────────────────────────────────

app = FastAPI(
    title="Amblyopia Care System API",
    description=(
        "Medical-grade AI-powered amblyopia screening for rural India. "
        "Built for Aravind Eye Hospital. DPDP Act 2023 compliant."
    ),
    version="1.0.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    openapi_url="/openapi.json" if settings.debug else None,
    lifespan=lifespan,
)


# ── Middleware (order matters — outermost first) ───────────────────────────────
# 1. Request ID — must be first so all other middleware can read request_id
app.add_middleware(RequestIDMiddleware)

# 2. CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "X-Device-ID",
        "X-Request-ID",
        "X-CSRF-Token",
    ],
)

# 3. Audit trail for mutating requests
app.add_middleware(AuditTrailMiddleware)

# 4. Global per-IP sliding-window rate limiting (Redis-backed)
app.add_middleware(RateLimitMiddleware)

# 5. Helmet-style security headers on every response
app.add_middleware(SecurityHeadersMiddleware)

# 6. Prometheus metrics — outermost HTTP observer (must be last)
app.add_middleware(PrometheusMiddleware)


# ── Exception Handlers ────────────────────────────────────────────────────────

app.add_exception_handler(StarletteHTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, unhandled_exception_handler)


# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(auth.router)
app.include_router(patient.router)
app.include_router(nurse.router)
app.include_router(village.router)
app.include_router(screening.router)
app.include_router(gaze.router)
app.include_router(redgreen.router)
app.include_router(snellen.router)
app.include_router(sync.router)
app.include_router(doctor.router)
app.include_router(dashboard.router)
app.include_router(notifications.router)
app.include_router(control_panel.router)


# ── Health & Readiness Probes ─────────────────────────────────────────────────

@app.get("/health", tags=["system"])
async def health_check():
    """Liveness probe — returns healthy if process is running."""
    return {
        "status": "healthy",
        "service": "Amblyopia Care System API",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": settings.environment,
    }


@app.get("/ready", tags=["system"])
async def readiness_check():
    """
    Readiness probe — verifies DB + Redis are reachable before
    load-balancer routes traffic to this instance.
    """
    checks: dict = {}

    # DB check
    try:
        from app.database import AsyncSessionLocal
        from sqlalchemy import text
        async with AsyncSessionLocal() as db:
            await db.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as exc:
        checks["database"] = f"error: {exc}"

    # Redis check
    try:
        from app.dependencies import get_redis
        redis = await get_redis()
        await redis.ping()
        checks["redis"] = "ok"
    except Exception as exc:
        checks["redis"] = f"error: {exc}"

    all_ok = all(v == "ok" for v in checks.values())
    return JSONResponse(
        status_code=200 if all_ok else 503,
        content={
            "status": "ready" if all_ok else "not_ready",
            "checks": checks,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    )


@app.get("/metrics", include_in_schema=False)
async def metrics(request: Request):
    """Prometheus metrics scrape endpoint."""
    return await metrics_endpoint(request)


@app.get("/", tags=["system"])
async def root():
    return {
        "message": "Amblyopia Care System API",
        "docs": "/docs" if settings.debug else "disabled in production",
        "health": "/health",
        "ready": "/ready",
    }
