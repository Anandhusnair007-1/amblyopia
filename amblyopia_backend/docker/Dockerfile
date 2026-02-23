# ── Stage 1: dependency builder ───────────────────────────────────────────────
FROM python:3.11.7-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: production image ─────────────────────────────────────────────────
FROM python:3.11.7-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
# Gunicorn worker count: 2 * CPU + 1 (overrideable via WEB_CONCURRENCY env var)
ENV WEB_CONCURRENCY=4

WORKDIR /app

# Runtime system dependencies only — no gcc, no libpq-dev, no build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsndfile1 \
    ffmpeg \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Non-root user created before COPY so --chown works without an extra layer
RUN useradd -m -u 1000 -s /bin/sh appuser

# Copy pre-built Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy application code — owned directly by appuser (no separate chown layer)
COPY --chown=appuser:appuser . .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:8000/ready || exit 1

# Gunicorn + UvicornWorker for production
# WEB_CONCURRENCY env allows overriding worker count at runtime
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
