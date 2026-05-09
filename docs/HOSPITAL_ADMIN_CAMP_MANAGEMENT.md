# P1.2 — Hospital admin and camp management

## Roles

| Role | Scope |
|------|--------|
| `super_admin` | All hospitals; only role that can `POST /api/admin/hospitals` |
| `hospital_admin` | Same as legacy `admin` for API purposes — own `hospital_id` for branches, camps, staff, devices |
| `admin` | Legacy seeded role; treated like `hospital_admin` for `ADMIN_API_ROLES` |
| `doctor` | Clinical review, diagnoses, referrals PATCH, patient list scoped by `hospital_id` |
| `optometrist` | Screening, sessions, results; sees AI deviation insights; **cannot** POST `/api/doctor/diagnoses` |
| `field_worker` | Registration / consent / sessions for patients in same hospital; **no** `medical_findings` on predictions; **no** AI deviation insights |
| `patient` | Own data only |

Staff authenticate via `POST /api/auth/doctor/login` (email/password). JWT includes `hospital_id`, `branch_id`, `camp_ids` when present.

## MongoDB collections

| Collection | Purpose |
|------------|---------|
| `hospitals` | `id`, `name`, `location`, `address`, `contact`, `status`, `created_at` |
| `branches` | `id`, `hospital_id`, `name`, `location`, `status`, `created_at` |
| `camps` | `id`, `hospital_id`, `branch_id`, `name`, `location`, `start_date`, `end_date`, `status`, `created_by`, `created_at` |
| `staff_users` | `id`, `user_id`, `hospital_id`, `branch_id`, `camp_ids`, `name` (encrypted), `email`, `role`, `active`, `created_at`, `last_login` |
| `devices` | `id`, `hospital_id`, `branch_id`, `camp_id`, `device_label`, `device_type`, `assigned_to`, `status`, `last_seen_at`, `created_at` |
| `referrals` | Auto-created when `complete_session` yields `risk_level == urgent`; `urgency`, `status`, `doctor_review_required`, `hospital_id`, `camp_id`, … |
| `follow_ups` | Listed by `hospital_id`; PATCH for status / due_date / outcome |

Existing: `users` (credentials + role), `patients`, `test_sessions`, `audit_logs`, …

## API summary

**Admin (requires `hospital_admin`, `admin`, or `super_admin`):**

- `POST /api/admin/hospitals` — super_admin only  
- `GET /api/admin/hospitals` — scoped list for non–super-admin  
- `GET|POST /api/admin/branches`  
- `GET|POST /api/admin/camps`, `PATCH /api/admin/camps/{camp_id}`  
- `GET|POST /api/admin/staff`, `PATCH /api/admin/staff/{staff_id}` (`staff_id` = `users.id`)  
- `GET|POST /api/admin/devices`, `PATCH /api/admin/devices/{device_id}`  

**Referrals / follow-ups**

- `GET /api/referrals`, `PATCH /api/referrals/{referral_id}` — doctors + hospital admins (+ super); optometrist read-only on `GET`  
- `GET /api/followups`, `PATCH /api/followups/{followup_id}` — doctors + hospital admins (+ super)  

**Sessions**

- `POST /api/sessions` accepts optional `hospital_id`, `branch_id`, `camp_id`, `device_id`; stores `created_by`, `created_by_role`, `created_role`.

## Security model

- Admin mutations audited (`camp.create`, `staff.create`, `referral.patch`, …).  
- PII: staff `name` stored encrypted in `staff_users`; JWT still carries plaintext `name` on `users` for compatibility.  
- `field_worker` does not receive `ai_deviation_insights` or `medical_findings` on `GET /api/sessions/{id}`.  
- Patients cannot call admin routes.  
- Hospital scope: non–super-admin requests are filtered by `hospital_id` on patients, camps, referrals, follow-ups.

## Urgent referral workflow

1. Patient or staff completes session → `classify_risk` unchanged.  
2. If `risk_level == urgent`, server inserts `referrals` with `status=new`, `urgency=urgent`, `doctor_review_required=true`, and audits `referral.created`.  
3. Doctor or hospital admin updates referral via `PATCH /api/referrals/{id}` (`status`, `assigned_to`, `notes`).

## Follow-up workflow

- `follow_ups` documents are listed by `hospital_id`; creation from UI/API can be extended later.  
- `PATCH /api/followups/{id}` updates `status`, `due_date`, `outcome`.

## Remaining gaps

- No automatic `follow_ups` row on referral (manual or future hook).  
- Doctor patient search by name remains exact full-name hash match (P1.1).  
- Redis rate limits, MFA, backups (P1.3+).  
- Frontend admin pages are minimal tables (see `/admin/*`).

## Frontend (minimal admin UI)

Routes (JWT must include a role allowed by `ProtectedRoute`):

| Path | Purpose |
|------|---------|
| `/admin` | Overview + hospital list |
| `/admin/camps` | List camps, create camp, patch status (nav hidden for non–hospital-admin roles; direct URL still works where API allows) |
| `/admin/staff` | List staff, create staff, activate/deactivate |
| `/admin/referrals` | List referrals; status dropdown for roles allowed to `PATCH` |
| `/admin/followups` | List / patch follow-ups |

Staff sign-in: `/doctor-login`. `super_admin` / `hospital_admin` / `admin` redirect to `/admin`; clinical roles to `/doctor`.

## Commands

```bash
cd backend
pytest tests/test_p1_2_hospital.py tests/test_ai_gate_validation.py tests/test_rate_limit_unit.py tests/test_pii_crypto.py -q
```

`tests/test_ambyoai_v2_backend.py` and `tests/test_v22_smoke.py` are **HTTP integration** tests: set `REACT_APP_BACKEND_URL` (or the env var those files read) to a running backend (for example `http://127.0.0.1:8000`) before running them.

OTP rate limiting is covered by `tests/test_rate_limit_unit.py` at the limiter layer; full HTTP OTP + Motor is left to integration / staging.
