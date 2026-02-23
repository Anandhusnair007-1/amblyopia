# ================================================================
#  Amblyopia Care System — Hardened Production Dockerfile
#  DevSecOps hardening:
#    - Non-root user uid=1000, no shell (/sbin/nologin)
#    - No write access at runtime (tmpfs overlaid by compose)
#    - Minimal runtime packages — no gcc, no build tools
#    - OCI labels for SBOM / cosign supply-chain traceability
# ================================================================

# ── Stage 1: dependency builder ───────────────────────────────
FROM python:3.11.7-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: production image ──────────────────────────────────
FROM python:3.11.7-slim

SHELL ["/bin/sh", "-eo", "pipefail", "-c"]

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    WEB_CONCURRENCY=4 \
    LOG_FORMAT=json

WORKDIR /app

# Runtime-only deps — absolutely minimal, no dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsndfile1 \
    ffmpeg \
    libpq5 \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Non-root user — no login shell
RUN useradd -m -u 1000 -g 0 -s /sbin/nologin appuser

# Python packages from builder stage
COPY --from=builder /install /usr/local

# App source — owned by appuser
COPY --chown=appuser:appuser . .

# Pre-create writable dirs (tmpfs mounts overlay these at runtime)
RUN mkdir -p /app/logs /app/tmp /app/mlruns && \
    chown -R appuser:root /app/logs /app/tmp /app/mlruns && \
    chmod -R 775 /app/logs /app/tmp /app/mlruns

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:8000/ready || exit 1

# OCI labels for SBOM / supply-chain traceability
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG VERSION=unknown

LABEL org.opencontainers.image.title="amblyopia-backend" \
      org.opencontainers.image.description="Amblyopia Care System — FastAPI backend" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/Anandhusnair007-1/amblyopia" \
      org.opencontainers.image.licenses="Proprietary" \
      maintainer="anandhusnair@am.amrita.edu"

CMD ["sh", "-c", \
     "gunicorn app.main:app \
       --bind 0.0.0.0:8000 \
       --worker-class uvicorn.workers.UvicornWorker \
       --workers ${WEB_CONCURRENCY:-4} \
       --timeout 120 \
       --graceful-timeout 30 \
       --keep-alive 5 \
       --access-logfile - \
       --error-logfile - \
       --log-level info"]
