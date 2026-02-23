# Changelog — Amblyopia Care System

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Placeholder for next release features

---

## [1.0.0] — 2025 — *Pilot Ready*

> First production-ready release. Full 9-phase hospital-grade hardening applied.
> Meets DPDP Act 2023 compliance requirements for pilot deployment.

### Added

**Core Backend (Phases 1–7 — previous sessions)**
- Amblyopia screening pipeline: image enhancement (Real-ESRGAN, Zero-DCE, DeblurGAN), gaze detection (YOLO), voice denoising (RNNoise), speech recognition (Whisper)
- FastAPI backend with JWT authentication, RBAC (patient / nurse / doctor / admin)
- PostgreSQL (async SQLAlchemy), Redis JWT revocation, MinIO media storage
- MLflow model registry, Airflow DAG orchestration
- AES-256 PII column encryption at rest
- Comprehensive audit trail middleware (request ID, audit log, security headers)
- Rate limiting middleware (per-tier, Redis-backed)
- 66-test validation suite (`run_pipeline_validation.py`): 66 PASS · 0 FAIL
- Stress test suite (`run_stress_test.py`): 56 PASS · 0 FAIL · 1 WARN (expected)

**Phase 1 — CI/CD**
- `.github/workflows/ci.yml`: 8-job pipeline (lint → test → bandit → trivy-deps → docker-build → trivy-image → sbom-sign → notify-failure)
- `.github/workflows/security.yml`: nightly pip-audit, gitleaks, CodeQL
- `.github/BRANCH_PROTECTION.md`: PR-required, signed commits, no force-push
- `.github/CODEOWNERS`: all paths owned by `@Anandhusnair007-1`

**Phase 2 — Container hardening**
- `docker/Dockerfile`: OCI labels, non-login shell (uid=1000), all build args for traceability
- `docker/docker-compose.prod.yml`: `read_only: true`, `cap_drop: ALL`, `no-new-privileges`, `seccomp`, internal Docker networks
- `docker/seccomp-restricted.json`: custom seccomp allowlist (defaultAction: ERRNO, ~80 allowed syscalls)
- `docker/nginx/nginx.conf`: TLS 1.3 only, HSTS preload, edge rate limit, JSON access logging, `server_tokens off`

**Phase 3 — Observability**
- `app/middleware/metrics.py`: `PrometheusMiddleware` + 11 custom metrics (request rate, latency, ML pipelines, security events)
- `app/main.py`: `/metrics` endpoint registered
- `monitoring/prometheus.yml`: scrape configs for backend, Postgres, Redis, Node, cAdvisor, MLflow, Airflow
- `monitoring/rules/amblyopia.yml`: 12 Prometheus alerting rules (API down, high error rate, disk low, etc.)
- `monitoring/grafana/provisioning/datasources.yml`: Prometheus + Loki + Tempo
- `monitoring/grafana/dashboards/amblyopia.json`: 20-panel operations dashboard (API health, ML latency, infrastructure, Redis, Airflow, security)

**Phase 4 — Backup & DR**
- `scripts/backup.sh`: PostgreSQL + Airflow DB + MLflow + MinIO + logs, AES-256 encrypted, S3 upload, retention enforcement (30d/1y/7y)
- `scripts/restore_drill.sh`: end-to-end DR drill with SHA256 manifest verification, RTO check (< 2h target)

**Phase 5 — Infrastructure security**
- `scripts/setup_server.sh`: UFW (22/80/443 only), fail2ban (SSH + Nginx + API), SSH hardening (no root/password, strong ciphers), sysctl kernel hardening, logrotate, unattended-upgrades, auditd rules

**Phase 6 — MLSecOps**
- `app/services/model_integrity.py`: SHA-256 hash verification, DB registry (`model_hash_records`), manifest write/verify, MLflow integration, `ModelIntegrityError` / `ModelNotRegisteredError` exceptions

**Phase 7 — Drift monitoring**
- `app/services/drift_monitor.py`: 6-metric daily drift detection, 7-day rolling z-score baseline, Slack/DB alert dispatch, Prometheus gauge publication
- `airflow/dags/drift_monitor_dag.py`: `amblyopia_drift_monitor` DAG (daily 06:00 UTC) + `amblyopia_model_integrity_audit` DAG (daily 05:00 UTC)

**Phase 8 — Compliance documentation**
- `docs/compliance/data_flow_diagram.md`
- `docs/compliance/threat_model.md` (STRIDE analysis, 3 attack scenarios)
- `docs/compliance/risk_register.md` (15 risks, DPDP-mapped)
- `docs/compliance/security_controls.md` (DPDP Act 2023 + ISO 27001 mapping)
- `docs/compliance/access_control_policy.md` (RBAC matrix, session policy)
- `docs/compliance/incident_response.md` (6-phase IRP, 72h breach notification)
- `docs/compliance/data_retention_policy.md` (7-year schedule, automated deletion)
- `docs/compliance/key_rotation_policy.md` (rotation procedures for all secrets)

**Phase 9 — Release governance**
- `.github/workflows/release.yml`: auto-release notes on `v*` tag push
- `docs/versioning_policy.md`: semantic versioning rules
- `CHANGELOG.md`: this file

### Changed
- `docker/nginx/nginx.conf`: replaced basic config with full production Nginx config
- `monitoring/prometheus.yml`: extended from 4-job to 8-job scrape config with labels

### Security
- All HIGH/CRITICAL CVEs resolved in base image (Python 3.11-slim)
- Bandit scan: 0 HIGH issues in production code
- gitleaks: 0 secrets detected in commit history
- Trivy image scan: 0 CRITICAL, 0 HIGH in final image

---

## [0.9.0] — 2025 — *Internal Beta*

### Added
- Core ML pipeline integration (7 models)
- Authentication system (JWT + Redis revocation)
- Patient, screening, and doctor workflows
- Basic test suite

### Known Issues
- No observability stack
- No automated backup
- No compliance documentation

---

[Unreleased]: https://github.com/Anandhusnair007-1/amblyopia/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Anandhusnair007-1/amblyopia/releases/tag/v1.0.0
[0.9.0]: https://github.com/Anandhusnair007-1/amblyopia/releases/tag/v0.9.0
