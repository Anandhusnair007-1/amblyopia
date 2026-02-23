# Data Flow Diagram — Amblyopia Care System

**Document ID:** DPDP-DFD-001  
**Version:** 1.0  
**Classification:** Internal / Compliance  
**Last Updated:** 2025  
**Owner:** Platform Engineering  

---

## 1. System Context

The Amblyopia Care System collects patient screening data (images, voice recordings, gaze test results) at rural eye-care camps, processes it through ML pipelines, and provides diagnostic support to qualified doctors.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL ENTITIES                                │
│                                                                          │
│  [Patient / Guardian]  ──►  [Flutter Mobile App]  ──►  [FastAPI Backend] │
│  [Doctor / Nurse]      ──►  [Flutter Mobile App]  ──►  [FastAPI Backend] │
│  [Admin]               ──►  [Control Panel UI  ]  ──►  [FastAPI Backend] │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow — Patient Screening

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Level 1 — Patient Screening Data Flow                                      │
│                                                                             │
│  [Patient] ──(biometric media)──► [Flutter App]                            │
│                  │                                                          │
│                  ▼ HTTPS TLS 1.3 (JSON + multipart)                        │
│           [Nginx Edge (TLS termination)]                                    │
│                  │                                                          │
│                  ▼                                                          │
│           [FastAPI Backend]                                                 │
│            │         │          │            │                             │
│            ▼         ▼          ▼            ▼                             │
│       [PostgreSQL] [Redis]  [MLflow]    [MinIO / S3]                       │
│       (PII store)  (JWT     (model      (media                             │
│                    cache)   registry)   storage)                           │
│            │                    │                                          │
│            └────────────────────┘                                          │
│                       │                                                     │
│                       ▼                                                     │
│               [Airflow DAG scheduler]                                      │
│                       │                                                     │
│                       ▼                                                     │
│               [ML Pipelines]                                               │
│         (Real-ESRGAN / Zero-DCE / YOLO /                                   │
│          DeblurGAN / Whisper / RNNoise)                                    │
│                       │                                                     │
│                       ▼                                                     │
│               [Risk Score + Report]                                         │
│                       │                                                     │
│                       ▼                                                     │
│               [Doctor Dashboard]                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Stores

| Store         | Contains                                         | Encryption          | Location        |
|---------------|--------------------------------------------------|---------------------|-----------------|
| PostgreSQL    | Patient PII, screening results, audit logs       | AES-256 at-rest     | Docker container|
| Redis         | JWT revocation list, session cache               | None (volatile)     | Docker container|
| MinIO / S3    | Images, voice recordings, PDF reports          | AES-256-SSE         | Object storage  |
| MLflow        | Model artifacts, experiment metrics              | None (internal)     | Docker container|
| Airflow       | DAG metadata, task logs                          | None (internal)     | Docker container|

---

## 4. PII Data Elements

| Field                  | Category           | Sensitivity | Encrypted |
|------------------------|--------------------|-------------|-----------|
| `encrypted_name`       | Identity           | HIGH        | Yes (AES) |
| `date_of_birth`        | Identity           | MEDIUM      | No        |
| `phone_number`         | Contact            | HIGH        | Yes (AES) |
| `village_id`           | Location           | LOW         | No        |
| `retinal_image`        | Biometric          | CRITICAL    | Yes (SSE) |
| `voice_recording`      | Biometric          | CRITICAL    | Yes (SSE) |
| `risk_score`           | Medical (non-PII)  | MEDIUM      | No        |

---

## 5. Data Transfer Boundaries

| Boundary                        | Protocol        | Controls                             |
|---------------------------------|-----------------|--------------------------------------|
| App → Backend                   | HTTPS (TLS 1.3) | Certificate pinning (mobile), HSTS   |
| Backend → PostgreSQL            | TCP (internal)  | Docker internal network, no exposure |
| Backend → Redis                 | TCP (internal)  | Docker internal network              |
| Backend → MinIO                 | S3 API (TLS)    | IAM policy, bucket policy            |
| Backend → MLflow                | HTTP (internal) | Docker internal network              |
| Backup → S3                     | HTTPS           | AES-256 client-side encrypt + SSE-KMS|
| Hospital IT integration (future)| HL7 FHIR / TLS  | Mutual TLS, OAuth2                   |

---

## 6. Third-Party Data Transfers

Currently **nil** — no patient PII is transferred to third-party services.  
MLflow, MinIO, and Airflow are all self-hosted.

---

## 7. Data Flows Excluded from Processing

- Payment data: not collected
- Government ID (Aadhaar): not collected
- Financial data: not collected
