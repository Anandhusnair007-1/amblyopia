# Amblyopia Care System

A full-stack clinical screening platform for early detection and management of amblyopia (lazy eye) — combining computer vision, voice AI, automated scoring, and clinical reporting.

---

## Architecture

```
amblyopia/
├── amblyopia_backend/     FastAPI · PostgreSQL · Redis · MLflow · Airflow
└── amblyopia_app/         Flutter (iOS · Android · Web · Desktop)
```

### Backend Stack

| Layer | Technology |
|---|---|
| API | FastAPI + Uvicorn |
| Database | PostgreSQL + SQLAlchemy (async) |
| Cache / Rate-limit | Redis |
| ML Tracking | MLflow |
| Orchestration | Apache Airflow |
| Image Enhancement | Real-ESRGAN · Zero-DCE · DeblurGAN |
| Gaze / Vision AI | YOLOv8 |
| Voice AI | OpenAI Whisper + RNNoise |
| Notifications | Twilio WhatsApp |
| Storage | MinIO (S3-compatible) |
| Containerisation | Docker / docker-compose |

---

## Quick Start (Backend)

```bash
cd amblyopia_backend

# 1. Copy environment template
cp .env.example .env
# ↳ Fill in DB, Redis, Twilio, MinIO, MLflow credentials

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run migrations
alembic upgrade head

# 4. Start server
uvicorn app.main:app --reload
```

Or with Docker:
```bash
cd amblyopia_backend/docker
docker-compose up --build
```

---

## Validation & Stress Test

```bash
# Pipeline validation (real models, 66 checks)
python3 run_pipeline_validation.py

# Stress test (7 phases, clinical-pilot readiness)
python3 run_stress_test.py --stability-minutes 2
```

**Latest results (v1.0.0-pilot-ready):**

| Suite | PASS | FAIL | WARN |
|---|---|---|---|
| `run_pipeline_validation.py` | 66 | 0 | 0 |
| `run_stress_test.py` | 56 | 0 | 1* |

*WARN: Whisper in-process RSS ~3.6 GB — not a concern in production (isolated GPU worker).

---

## Security

- JWT authentication with JTI blacklist (Redis)
- CSRF protection (HMAC + TTL)
- Global rate limit: 120 req/IP/60 s · Auth limit: 10 req/IP/60 s
- Security headers: CSP · HSTS · X-Frame-Options · Referrer-Policy · Permissions-Policy
- CORS: explicit allow-list (no wildcard)

---

## Release

| Tag | Status | Date |
|---|---|---|
| `v1.0.0-pilot-ready` | ✅ Frozen for clinical pilot | 2026-02-23 |

---

## License

Proprietary — Amrita Vishwa Vidyapeetham. All rights reserved.
