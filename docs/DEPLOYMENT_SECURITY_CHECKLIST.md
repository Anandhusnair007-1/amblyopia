# Deployment And Security Checklist

Use this checklist before staging, doctor demo, controlled pilot, and any later public release decision.

## Transport And App Boundary

- [ ] HTTPS enforced for frontend and backend.
- [ ] HTTP redirects to HTTPS.
- [ ] CORS restricted to approved staging/production origins.
- [ ] Cookies/tokens never exposed in logs.
- [ ] Staging and production use separate domains, databases, storage, secrets, and analytics.

## Authentication And Session Security

- [ ] JWT secret is strong and environment-specific.
- [ ] JWT/session expiry confirmed for patient and staff roles.
- [ ] Token expiry and invalid-token handling tested.
- [ ] Demo OTP disabled in production.
- [ ] Seed doctor/admin accounts disabled or rotated for staging/production.
- [ ] Rate limiting enabled for OTP/login and sensitive routes.

## RBAC And Data Isolation

- [ ] Patient cannot access another patient record or session.
- [ ] Patient cannot access raw AI details or doctor-only fields.
- [ ] Doctor access is scoped to hospital/camp rules.
- [ ] Admin-only routes are protected.
- [ ] Patching plan creation is doctor-only.
- [ ] Report export permissions are enforced.

## Database And Secrets

- [ ] MongoDB network access restricted.
- [ ] MongoDB credentials stored only in secret manager or protected env vars.
- [ ] Database backups encrypted.
- [ ] PII encryption key configured outside source control.
- [ ] Key rotation process documented.
- [ ] Production logs do not include raw PII or raw medical image payloads.

## Audit Logging

- [ ] Login and failed-login events logged.
- [ ] Consent save events logged.
- [ ] Result save events logged.
- [ ] Doctor diagnosis/action events logged.
- [ ] Patching plan and patching log events logged.
- [ ] Report export/download events logged.
- [ ] Admin changes logged.
- [ ] Audit logs are retained according to policy.

## Offline Data Handling

- [ ] Offline queue stores minimized payload only.
- [ ] Offline payload excludes raw images and raw AI class/confidence details.
- [ ] Offline conflict handling tested.
- [ ] Client-side encryption decision documented before controlled pilot.
- [ ] Device-loss guidance prepared for pilot sites.

## Error Logging And Monitoring

- [ ] Error monitoring configured for staging.
- [ ] PII scrubbing enabled before sending errors to external services.
- [ ] Stack traces hidden from users.
- [ ] Health/version endpoints available.
- [ ] Incident response contact list created.

## Dependency And Build Review

- [ ] Backend dependency vulnerability scan completed.
- [ ] Frontend dependency vulnerability scan completed.
- [ ] Frontend build succeeds.
- [ ] ESLint plugin warning reviewed.
- [ ] MediaPipe source-map warning reviewed.
- [ ] Large bundle warning reviewed.

## Staging Environment Variables

- [ ] `ENV=staging`
- [ ] `MONGO_URL`
- [ ] `DB_NAME`
- [ ] `JWT_SECRET`
- [ ] `CORS_ORIGINS`
- [ ] `PII_SECRET_KEY` or equivalent encryption key
- [ ] `DATASET_VERSION`
- [ ] `AMBYO_QUALITY_MODEL_VERSION`
- [ ] `AMBYO_DEVIATION_MODEL_VERSION`
- [ ] `SENTRY_DSN` or approved monitoring DSN
- [ ] `ENABLE_DEMO_OTP=false`
- [ ] `ENABLE_SEED_DOCTOR=false`

