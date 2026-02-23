# Security Controls — Amblyopia Care System

**Document ID:** DPDP-SC-001  
**Version:** 1.0  
**Mapped To:** DPDP Act 2023 | ISO/IEC 27001:2022 | OWASP Top 10  
**Last Updated:** 2025  
**Owner:** Security Engineering  

---

## 1. Mapping to DPDP Act 2023

| DPDP Obligation | Requirement | Control Implemented | Evidence |
|-----------------|-------------|---------------------|----------|
| Section 4 — Lawful Processing | Consent before processing personal data | Consent flag stored in `screenings.consent_obtained` | DB schema, PR review |
| Section 5 — Purpose limitation | Data used only for stated ophthalmology purpose | RBAC prevents cross-purpose access | RBAC matrix, audit logs |
| Section 8 — Data Fiduciary obligations | Ensure accuracy, completeness, security | Input validation (Pydantic), AES encryption at rest | Code review, pen-test |
| Section 9 — Processing children's data | Parental/guardian consent for under-18 | Parent consent field in patient registration | DB schema |
| Section 11 — Right to correction | Patient can request correction | Doctor/nurse can update records; audit trail | API endpoint `/patient/{id}` PATCH |
| Section 13 — Grievance redressal | Contact point for data complaints | `DPDP_CONTACT_EMAIL` in system config | config.py |
| Section 17 — Significant data fiduciary | Enhanced accountability if PII > threshold | Risk register, annual audit, DPO appointment | This document |

---

## 2. Application Security Controls

### Authentication & Authorization

| Control | Implementation | Status |
|---------|---------------|--------|
| JWT RS256 signing | `python-jose`, 24h TTL | ✅ Implemented |
| JWT revocation list | Redis SET with expiry | ✅ Implemented |
| Role-Based Access Control | 4 roles: patient, nurse, doctor, admin | ✅ Implemented |
| Bcrypt password hashing | `passlib[bcrypt]`, cost=12 | ✅ Implemented |
| Rate limiting — login | 10 req/min/IP at Nginx edge | ✅ Implemented |
| Multi-factor authentication | Not implemented (v1.0 scope) | ⬜ Roadmap |

### Data Protection

| Control | Implementation | Status |
|---------|---------------|--------|
| Encryption at rest (PII fields) | AES-256 column encryption | ✅ Implemented |
| Encryption in transit | TLS 1.3, HSTS `max-age=63072000` | ✅ Implemented |
| Media file encryption | MinIO/S3 SSE-KMS | ✅ Implemented |
| Backup encryption | AES-256-CBC + PBKDF2 | ✅ Implemented |
| Data anonymisation (analytics) | Aggregate-only reporting | ✅ Implemented |

### Input Validation

| Control | Implementation | Status |
|---------|---------------|--------|
| Request schema validation | Pydantic v2 models on all endpoints | ✅ Implemented |
| File type validation | MIME type check on upload | ✅ Implemented |
| Maximum upload size | 10 MB via Nginx | ✅ Implemented |
| SQL injection prevention | SQLAlchemy ORM (parameterised) | ✅ Implemented |
| Path traversal prevention | UUID rename on upload, no user-controlled paths | ✅ Implemented |

### Security Headers

| Header | Value | Status |
|--------|-------|--------|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | ✅ |
| `X-Content-Type-Options` | `nosniff` | ✅ |
| `X-Frame-Options` | `DENY` | ✅ |
| `Content-Security-Policy` | `default-src 'self'` (API — no HTML served) | ✅ |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | ✅ |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | ✅ |

---

## 3. Infrastructure Security Controls

| Control | Implementation | Status |
|---------|---------------|--------|
| Firewall (UFW) | Allow 22/80/443 only | ✅ setup_server.sh |
| Intrusion prevention | fail2ban (SSH, Nginx, API auth) | ✅ setup_server.sh |
| SSH hardening | No root, no password auth, key-only | ✅ setup_server.sh |
| Kernel hardening | sysctl — no IP forward, ASLR, ptrace_scope=2 | ✅ setup_server.sh |
| Container isolation | seccomp allowlist, cap_drop ALL, read-only FS | ✅ docker-compose.prod.yml |
| Automatic security updates | unattended-upgrades (security channel) | ✅ setup_server.sh |
| Audit logging | auditd rules for security-sensitive operations | ✅ setup_server.sh |

---

## 4. CI/CD Security Controls

| Control | Implementation | Status |
|---------|---------------|--------|
| Static analysis | ruff + flake8 linting | ✅ ci.yml |
| SAST | bandit (Python security scanner) | ✅ ci.yml |
| Dependency vulnerability scan | pip-audit + trivy (weekly) | ✅ security.yml |
| Container image scan | trivy — fail on CRITICAL/HIGH | ✅ ci.yml |
| Secret scanning | gitleaks (nightly) | ✅ security.yml |
| Code review requirement | CODEOWNERS, 1 required approver | ✅ BRANCH_PROTECTION.md |
| SBOM generation | syft + cosign (keyless OIDC) | ✅ ci.yml |
| CodeQL analysis | Python CodeQL (nightly) | ✅ security.yml |

---

## 5. ML Security Controls

| Control | Implementation | Status |
|---------|---------------|--------|
| Model hash verification | SHA-256 at load (model_integrity.py) | ✅ Implemented |
| Local filesystem manifest | write_manifest() + verify_manifest() | ✅ Implemented |
| MLflow model integrity registration | register_mlflow_model_hash() | ✅ Implemented |
| Daily integrity audit | Airflow DAG: amblyopia_model_integrity_audit | ✅ Implemented |
| Drift monitoring | Daily z-score detection (drift_monitor.py) | ✅ Implemented |
