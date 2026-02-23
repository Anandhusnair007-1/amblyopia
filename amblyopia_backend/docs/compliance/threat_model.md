# Threat Model — Amblyopia Care System

**Document ID:** DPDP-TM-001  
**Version:** 1.0  
**Methodology:** STRIDE  
**Last Updated:** 2025  
**Owner:** Security Engineering  

---

## 1. System Boundary

**In scope:** FastAPI backend, PostgreSQL, Redis, MinIO, MLflow, Airflow, Nginx, Flutter mobile app.  
**Out of scope:** Hospital network infrastructure, mobile device OS security.

---

## 2. Trust Zones

| Zone | Components | Trust Level |
|------|-----------|-------------|
| Zone 0 — Internet | Mobile app clients, internet traffic | Untrusted |
| Zone 1 — Edge | Nginx + TLS termination | Semi-trusted |
| Zone 2 — Application | FastAPI (uid=1000, read-only FS) | Trusted |
| Zone 3 — Data | PostgreSQL, Redis, MinIO, MLflow | Highly trusted |
| Zone 4 — ML/AI | Airflow + ML pipeline containers | Trusted |

---

## 3. STRIDE Analysis

### S — Spoofing

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| S-01 | Attacker forges JWT token | Auth endpoint | RS256 JWT, 24h TTL, revocation list in Redis | LOW |
| S-02 | Attacker impersonates nurse account | Patient access | RBAC enforced, per-endpoint role check | LOW |
| S-03 | Stolen device re-uses cached credentials | Mobile API | JWT expiry, forced re-auth on role change | MEDIUM |

### T — Tampering

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| T-01 | Tampered ML model weights at runtime | MLflow artifacts | SHA-256 hash verification at load (model_integrity.py) | LOW |
| T-02 | DBrecord manipulation | PostgreSQL | Audit trail middleware, immutable audit_logs table | LOW |
| T-03 | Man-in-the-middle on API calls | API traffic | TLS 1.3 mandatory, HSTS preload | LOW |
| T-04 | Container image tampered in registry | ghcr.io image | cosign keyless OIDC signing, trivy image scan in CI | LOW |

### R — Repudiation

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| R-01 | Doctor denies accessing patient record | Audit logs | Immutable audit_logs with JWT sub + timestamp | LOW |
| R-02 | System denies sending notification | Notification logs | audit_logs captures all outbound notification events | LOW |

### I — Information Disclosure

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| I-01 | Patient PII leaked in API error response | Error handlers | Custom exception handlers with sanitised messages | LOW |
| I-02 | PII in application logs | Log files | Log lines scrubbed of patient fields; no PII in JSON logs | MEDIUM |
| I-03 | DB credentials leaked | .env file | .gitignore covers .env; secrets via Docker secrets in prod | LOW |
| I-04 | S3 bucket misconfigured as public | Backup bucket | Bucket policy enforces private + SSE-KMS | LOW |
| I-05 | Biometric image accessible via direct URL | MinIO | Pre-signed URL (15 min TTL), auth required | LOW |

### D — Denial of Service

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| D-01 | Flood of auth requests | /auth/login | Rate limit 10 req/min/IP @ Nginx edge | LOW |
| D-02 | Large image upload exhausts disk | POST /screening | `client_max_body_size 10m` in Nginx | LOW |
| D-03 | Slow-loris attack | Nginx | `keepalive_timeout 65`, worker connection limits | LOW |
| D-04 | ML pipeline starvation | Airflow workers | Resource quotas on containers (docker-compose limits) | MEDIUM |

### E — Elevation of Privilege

| ID | Threat | Asset | Current Control | Residual Risk |
|----|--------|-------|-----------------|---------------|
| E-01 | Container escape to host | Docker daemon | seccomp allowlist, cap_drop ALL, no-new-privileges | LOW |
| E-02 | SQL injection → DB admin | PostgreSQL | SQLAlchemy ORM parameterised queries only | LOW |
| E-03 | Path traversal in file upload | File storage | Filename sanitisation, UUID rename on upload | LOW |
| E-04 | SSRF — backend calls attacker URL | HTTP client | Outbound calls to known endpoints only; no user-supplied URLs | LOW |

---

## 4. Attack Scenarios (Top 3)

### AS-1: Credential Stuffing on Login Endpoint
- **Path:** Internet → Nginx → `/api/v1/auth/login`
- **Impact:** Unauthorised access to patient records
- **Controls:** fail2ban (10 retries → 1h ban), rate limit 10 req/min, bcrypt password hashing
- **Residual Risk:** LOW

### AS-2: Insider Threat — Nurse Exports Patient List
- **Path:** Authenticated nurse → `/api/v1/patient/list` (all records)
- **Impact:** Bulk PII exfiltration
- **Controls:** Role-based filtering (nurse sees only assigned village), audit trail, anomaly detection  
- **Residual Risk:** MEDIUM (no automated bulk-export alert yet)

### AS-3: Supply Chain — Poisoned ML Model Pushed to MLflow
- **Path:** Compromised MLflow → model promotion → attacker model loaded
- **Impact:** Biased/adversarial predictions; misdiagnosis
- **Controls:** SHA-256 verification at load, model hash DB, cosign SBOM
- **Residual Risk:** LOW

---

## 5. Accepted Risks

| ID | Risk | Reason Accepted |
|----|------|-----------------|
| AR-01 | Insider bulk export (MEDIUM) | Mitigated by audit logs; full DLP out of scope for v1.0 |
| AR-02 | Mobile device compromise | Outside system boundary; user education mitigant |
