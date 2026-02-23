"""
================================================================
Prometheus Metrics Middleware — Amblyopia Care System
================================================================
Exposes /metrics endpoint (Prometheus text format).

Collected metrics:
  http_requests_total            — requests by method/path/status
  http_request_duration_seconds  — request latency histogram
  image_pipeline_duration_seconds— full_pipeline() latency
  voice_pipeline_duration_seconds— process_audio() latency
  scoring_duration_seconds       — scoring engine latency
  rate_limit_triggers_total      — 429 events by tier
  jwt_revocation_checks_total    — JWT blacklist checks
  mlflow_model_version           — current production model version
  active_requests                — in-flight request gauge
================================================================
"""
from __future__ import annotations

import time
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.routing import Match

try:
    from prometheus_client import (
        Counter, Gauge, Histogram, Info,
        CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST,
        REGISTRY,
    )
    _PROM_AVAILABLE = True
except ImportError:
    _PROM_AVAILABLE = False

# ── Metric definitions ─────────────────────────────────────────────────────

if _PROM_AVAILABLE:
    HTTP_REQUESTS_TOTAL = Counter(
        "http_requests_total",
        "Total HTTP requests",
        ["method", "path", "status_code"],
    )
    HTTP_REQUEST_DURATION = Histogram(
        "http_request_duration_seconds",
        "HTTP request latency",
        ["method", "path"],
        buckets=[0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
    )
    ACTIVE_REQUESTS = Gauge(
        "active_requests",
        "Number of in-flight HTTP requests",
    )
    IMAGE_PIPELINE_DURATION = Histogram(
        "image_pipeline_duration_seconds",
        "full_pipeline() latency",
        buckets=[0.1, 0.25, 0.5, 1.0, 2.0, 5.0],
    )
    VOICE_PIPELINE_DURATION = Histogram(
        "voice_pipeline_duration_seconds",
        "process_audio() latency",
        buckets=[0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0],
    )
    SCORING_DURATION = Histogram(
        "scoring_duration_seconds",
        "Scoring engine latency",
        buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5],
    )
    RATE_LIMIT_TRIGGERS = Counter(
        "rate_limit_triggers_total",
        "Number of 429 rate-limit events",
        ["tier"],
    )
    JWT_REVOCATION_CHECKS = Counter(
        "jwt_revocation_checks_total",
        "JWT blacklist lookups",
        ["result"],   # "hit" | "miss"
    )
    MLFLOW_MODEL_VERSION = Gauge(
        "mlflow_model_version",
        "Current MLflow production model version",
    )
    PDF_GENERATION_DURATION = Histogram(
        "pdf_generation_duration_seconds",
        "Referral letter PDF generation latency",
        buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.0],
    )
    NOTIFICATION_SENT = Counter(
        "notification_sent_total",
        "Outbound notifications",
        ["channel", "status"],  # channel: whatsapp/sms; status: sent/failed
    )


# ── Helper functions (called by service code) ──────────────────────────────

def record_image_pipeline(duration_s: float) -> None:
    if _PROM_AVAILABLE:
        IMAGE_PIPELINE_DURATION.observe(duration_s)


def record_voice_pipeline(duration_s: float) -> None:
    if _PROM_AVAILABLE:
        VOICE_PIPELINE_DURATION.observe(duration_s)


def record_scoring(duration_s: float) -> None:
    if _PROM_AVAILABLE:
        SCORING_DURATION.observe(duration_s)


def record_rate_limit(tier: str = "global") -> None:
    if _PROM_AVAILABLE:
        RATE_LIMIT_TRIGGERS.labels(tier=tier).inc()


def record_jwt_check(hit: bool) -> None:
    if _PROM_AVAILABLE:
        JWT_REVOCATION_CHECKS.labels(result="hit" if hit else "miss").inc()


def record_mlflow_version(version: int) -> None:
    if _PROM_AVAILABLE:
        MLFLOW_MODEL_VERSION.set(version)


def record_pdf_generation(duration_s: float) -> None:
    if _PROM_AVAILABLE:
        PDF_GENERATION_DURATION.observe(duration_s)


def record_notification(channel: str, success: bool) -> None:
    if _PROM_AVAILABLE:
        NOTIFICATION_SENT.labels(
            channel=channel,
            status="sent" if success else "failed"
        ).inc()


# ── Middleware ─────────────────────────────────────────────────────────────

class PrometheusMiddleware(BaseHTTPMiddleware):
    """
    Wraps every request to record:
      - http_requests_total
      - http_request_duration_seconds
      - active_requests gauge
    Skips /metrics itself to avoid recursion.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if not _PROM_AVAILABLE:
            return await call_next(request)

        # Normalise path — collapse IDs to reduce cardinality
        path = self._normalise_path(request)

        if path == "/metrics":
            return await call_next(request)

        ACTIVE_REQUESTS.inc()
        start = time.perf_counter()
        status_code = 500

        try:
            response   = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            duration = time.perf_counter() - start
            ACTIVE_REQUESTS.dec()
            HTTP_REQUEST_DURATION.labels(
                method=request.method, path=path
            ).observe(duration)
            HTTP_REQUESTS_TOTAL.labels(
                method=request.method,
                path=path,
                status_code=str(status_code),
            ).inc()
            # Track 429 separately for alerting
            if status_code == 429:
                tier = "auth" if "/auth" in path else "global"
                record_rate_limit(tier)

    @staticmethod
    def _normalise_path(request: Request) -> str:
        """Replace UUID/numeric segments with placeholders to keep metric cardinality low."""
        import re
        path = request.url.path
        # Replace UUIDs
        path = re.sub(
            r"/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            "/{uuid}", path, flags=re.IGNORECASE
        )
        # Replace bare integers
        path = re.sub(r"/\d+", "/{id}", path)
        return path


# ── /metrics endpoint handler ──────────────────────────────────────────────

async def metrics_endpoint(request: Request) -> Response:
    """Mount at /metrics. Returns Prometheus text exposition format."""
    if not _PROM_AVAILABLE:
        return Response(
            content="# prometheus_client not installed\n",
            media_type="text/plain",
            status_code=503,
        )
    return Response(
        content=generate_latest(REGISTRY),
        media_type=CONTENT_TYPE_LATEST,
    )
