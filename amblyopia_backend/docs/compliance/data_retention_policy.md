# Data Retention Policy — Amblyopia Care System

**Document ID:** DPDP-DRP-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Platform Engineering  
**Regulatory Basis:** DPDP Act 2023 Section 8(7) — data must not be retained longer than necessary  

---

## 1. Retention Schedule

| Data Category                  | Retention Period | Basis                              | Deletion Method           |
|--------------------------------|------------------|------------------------------------|---------------------------|
| Patient screening records      | 7 years          | DPDP Act + medical record standards| Cryptographic erasure + DB purge |
| Patient PII (name, contact)    | 7 years          | DPDP Act Section 8(7)              | Encrypted field overwrite |
| Audit logs                     | 3 years          | Regulatory best practice           | Automated S3 lifecycle rule |
| Application logs               | 30 days (rolling)| Operational integrity              | logrotate rotate 30       |
| Backup archives (daily)        | 30 days          | Operational backup policy          | S3 lifecycle expiry       |
| Backup archives (weekly)       | 1 year           | DR / audit support                 | S3 lifecycle expiry       |
| Backup archives (monthly)      | 7 years          | DPDP Act                           | S3 lifecycle expiry       |
| ML model artifacts (MLflow)    | Indefinite*      | Model governance / reproducibility | Manual review             |
| Drift monitoring snapshots     | 2 years          | ML governance                      | DB purge script           |
| JWT revocation records (Redis) | 24 hours (TTL)   | Session security                   | Automatic Redis expiry    |
| User account (inactive)        | 3 years inactive | DPDP Act, contractual              | Admin-initiated deletion  |
| Consent records                | 7 years          | DPDP Act Section 4                 | Must not be deleted early |
| PDF diagnostic reports         | 7 years          | Medical record standard            | Encrypted MinIO + lifecycle|

*MLflow model artifacts: retained for reproducibility. PHI never stored in model artifacts.

---

## 2. Legal Basis for Retention

| Retention basis | Data categories covered |
|-----------------|------------------------|
| DPDP Act 2023 (purpose limitation) | All personal data |
| Indian Medical Council Act (medical records) | Screening results, reports |
| Limitation Act 1963 (civil liability horizon) | Audit logs, consent |
| Contractual (hospital agreements) | Patient records |

---

## 3. Data Deletion Procedures

### 3.1 Automated Deletion

**S3 / MinIO lifecycle rules** (configure via `aws s3api put-bucket-lifecycle-configuration`):

```json
{
  "Rules": [
    {
      "ID": "delete-daily-backups-30d",
      "Prefix": "daily/",
      "Status": "Enabled",
      "Expiration": {"Days": 30}
    },
    {
      "ID": "delete-weekly-backups-1y",
      "Prefix": "weekly/",
      "Status": "Enabled",
      "Expiration": {"Days": 365}
    },
    {
      "ID": "delete-app-logs-30d",
      "Prefix": "logs/",
      "Status": "Enabled",
      "Expiration": {"Days": 30}
    }
  ]
}
```

### 3.2 Database Purge (manual, triggered by admin)

```sql
-- Purge inactive accounts (> 3 years inactive, role=patient)
DELETE FROM users
WHERE last_login < NOW() - INTERVAL '3 years'
  AND role = 'patient'
  AND id NOT IN (SELECT DISTINCT patient_id FROM screenings);

-- Anonymise old screenings (> 7 years)
UPDATE screenings
SET notes = NULL,
    raw_image_path = NULL,
    voice_path = NULL
WHERE created_at < NOW() - INTERVAL '7 years';
```

### 3.3 Right to Erasure (DPDP Act Section 11)

Steps for processing a data subject erasure request:

1. Verify identity of requestor
2. Check for legal hold (active medical treatment, litigation)
3. If no legal hold: anonymise PII fields, delete media objects, insert erasure record
4. Acknowledge within 30 days
5. Log action in `audit_logs`

---

## 4. Data Minimisation

The system collects only data directly necessary for screening:

| Not collected | Reason |
|---------------|--------|
| Aadhaar / National ID | Not required |
| Financial information | Not relevant |
| Full address (only village) | Village sufficient |
| Email address | SMS/in-app notification sufficient |
| Continuous location tracking | Session-only camp location |

---

## 5. Review

This policy is reviewed annually and immediately following any:
- DPDP Act amendment
- Significant architecture change
- Data breach incident
