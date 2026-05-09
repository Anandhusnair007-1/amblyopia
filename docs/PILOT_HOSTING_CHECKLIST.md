# Pilot hosting checklist — AmbyoAI

Use before exposing a controlled pilot or demo. Do **not** treat this as full regulatory compliance.

## Build & tests

- [ ] Frontend production build succeeds (`yarn build` or `npm run build`).
- [ ] Backend focused tests pass:
  ```bash
  cd backend
  python3 -m pytest tests/test_p1_2_hospital.py tests/test_ai_gate_validation.py tests/test_rate_limit_unit.py tests/test_pii_crypto.py tests/test_ai_gate_static.py tests/test_ai_response_policy.py -q
  ```

## Data & PII

- [ ] PII migration dry-run reviewed (`python3 scripts/migrate_encrypt_pii.py --dry-run` / `--verbose`).
- [ ] Migration applied on pilot DB if upgrading legacy data (`--apply`).
- [ ] MongoDB: name / phone / DOB stored as encrypted structures where applicable; `phone_hash` present for lookups.
- [ ] Audit logs sampled: **no** raw phone numbers or full patient names in detail payloads.

## Production configuration

- [ ] `ENV=production` on the API host.
- [ ] `JWT_SECRET` is long, random, **not** the repo default.
- [ ] `PII_ENCRYPTION_KEY` (valid Fernet) and `PII_LOOKUP_SECRET` set.
- [ ] `CORS_ORIGINS` lists **only** real app origins (no `*`).
- [ ] `ENABLE_DEMO_OTP=false` (explicit); demo OTP disabled in production behavior.
- [ ] `ENABLE_SEED_DOCTOR=false` on shared/staging/production databases.
- [ ] HTTPS enabled for browser-facing URLs.

## Infrastructure

- [ ] MongoDB not publicly reachable without auth/TLS (prefer Atlas or secured self-hosted).
- [ ] Backup script tested (`scripts/backup_mongodb.sh`); archive stored securely.
- [ ] Restore tested on a **copy** of data (`scripts/restore_mongodb.sh`).
- [ ] Optional: `SENTRY_DSN` configured for error visibility.

## Smoke — production startup

- [ ] API starts with safe env and fails with wildcard CORS when `ENV=production`.
- [ ] API fails startup if PII secrets missing (when `ENV=production`).

## Functional — patient

- [ ] Patient OTP request / verify (rate limits acceptable).
- [ ] Registration completes; consent captured.
- [ ] Screening test flow runs; **patient-safe** messages only (no clinician-only deviation detail).
- [ ] Patient **cannot** see XT/ET or similar deviation labels — only approved patient-facing copy.

## Functional — doctor / AI gate

- [ ] Doctor (or authorized clinical role) login works.
- [ ] Doctor dashboard loads scoped patients/sessions as designed.
- [ ] AI gate / screening responses: **doctor** can see clinical/AI insight fields where intended.
- [ ] Review session/report flows work for pilot scope.

## Functional — admin / ops (if enabled)

- [ ] `/admin` (or deployed equivalent) reachable for hospital_admin / super_admin as designed.
- [ ] Camps / staff / referrals / follow-ups align with hospital scope (no cross-hospital leakage).

## Audit

- [ ] Audit logging enabled for sensitive actions (admin mutations, referrals, etc.).

---

**Sign-off**

| Field | Value |
|-------|--------|
| Date | |
| Environment | |
| Notes | |
