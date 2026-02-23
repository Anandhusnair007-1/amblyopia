# Risk Register — Amblyopia Care System

**Document ID:** DPDP-RR-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Security Engineering  
**Review Frequency:** Quarterly  

---

## 1. Risk Scoring Matrix

| Likelihood \ Impact | Low (1) | Medium (2) | High (3) | Critical (4) |
|--------------------|---------|------------|----------|--------------|
| **Unlikely (1)**   | 1       | 2          | 3        | 4            |
| **Possible (2)**   | 2       | 4          | 6        | 8            |
| **Likely (3)**     | 3       | 6          | 9        | 12           |
| **Near-certain(4)**| 4       | 8          | 12       | 16           |

**Risk appetite:** Score ≤ 4 = Accepted | 5–8 = Mitigate | ≥ 9 = Immediate action

---

## 2. Risk Register

| ID     | Category       | Risk Description                                       | L | I | Score | Status    | Owner          | Mitigations                                          | Residual |
|--------|----------------|--------------------------------------------------------|---|---|-------|-----------|----------------|------------------------------------------------------|----------|
| R-001  | Data Privacy   | Patient PII leaked via API error messages              | 2 | 4 | 8     | Mitigated | Backend Dev    | Custom exception handlers, no stack traces in prod   | 2        |
| R-002  | Data Privacy   | Unencrypted PII in application logs                    | 2 | 3 | 6     | Mitigated | Backend Dev    | Log scrubbing middleware, JSON logging without PII   | 3        |
| R-003  | Security       | Brute-force attack on patient login                    | 3 | 3 | 9     | Mitigated | DevSecOps      | fail2ban, rate-limiting, bcrypt                      | 2        |
| R-004  | Security       | Compromised ML model weights (supply chain)            | 1 | 4 | 4     | Mitigated | MLOps          | SHA-256 hash verification, SBOM, cosign              | 1        |
| R-005  | Security       | SQL injection attack                                   | 1 | 4 | 4     | Mitigated | Backend Dev    | ORM parameterised queries, bandit scanner in CI      | 1        |
| R-006  | Security       | Container escape to host                               | 1 | 4 | 4     | Mitigated | DevSecOps      | seccomp, cap_drop ALL, no-new-privileges             | 1        |
| R-007  | Availability   | Database server failure                                | 2 | 4 | 8     | Mitigated | Platform       | Daily encrypted backups, DR drill, RTO <2h           | 3        |
| R-008  | Availability   | ML pipeline saturation during camp day                 | 2 | 2 | 4     | Accepted   | MLOps          | Airflow worker concurrency limits, queue monitoring  | 4        |
| R-009  | Compliance     | DPDP Act violation — unrecorded consent                | 2 | 4 | 8     | Mitigated | Product        | Consent recorded at screening creation (DB)          | 2        |
| R-010  | Compliance     | Data retention breach — records kept > 7 years         | 1 | 3 | 3     | Accepted   | Platform       | Data retention policy, purge schedule in roadmap     | 3        |
| R-011  | Insider threat | Nurse exports all patient records                      | 2 | 3 | 6     | Partial    | Platform       | RBAC village scoping, audit logs, no bulk export UI  | 4        |
| R-012  | ML Quality     | Model drift degrades prediction accuracy               | 2 | 3 | 6     | Mitigated | MLOps          | Daily drift monitor DAG, z-score alerting            | 2        |
| R-013  | Physical       | Mobile device lost with cached session                 | 2 | 2 | 4     | Accepted   | Product        | JWT expiry 24h, remote wipe (MDM future)             | 4        |
| R-014  | Third-Party    | S3/MinIO bucket publicly accessible                    | 1 | 4 | 4     | Mitigated | Platform       | Bucket policy private, SSE-KMS, pre-signed URLs      | 1        |
| R-015  | Availability   | Git/GitHub compromise — malicious CI pipeline          | 1 | 3 | 3     | Mitigated | DevSecOps      | CODEOWNERS, branch protection, signed commits        | 1        |

---

## 3. Risk Treatment Summary

| Treatment  | Count | Description                                    |
|------------|-------|------------------------------------------------|
| Mitigated  | 11    | Control implemented and verified               |
| Partial    | 1     | Control partially implemented (R-011)          |
| Accepted   | 3     | Risk within appetite; monitored                |

---

## 4. Review Schedule

| Next review | Trigger events                                      |
|-------------|-----------------------------------------------------|
| Quarterly   | Scheduled                                           |
| On-demand   | Security incident, major architecture change, audit |
