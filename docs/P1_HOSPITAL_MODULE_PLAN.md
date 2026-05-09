# P1 hospital module plan (AmbyoAI)

Scope: operational and governance features for hospital deployment **after** the current screening baseline is frozen. Order balances risk reduction vs delivery effort.

---

## 1. PII encryption at rest

**Why:** MongoDB stores patient names, phones, guardian data; regulatory and hospital IT policies expect encryption at rest and key management.

**Backend schema:** No document shape change if using application-layer Fernet (already partially present); optional fields for `encryption_key_version`, `rotated_at`.

**API:** Key rotation admin-only; no patient-facing change.

**Frontend:** None beyond disclosure/consent copy updates if needed.

**Security risks:** Key leakage, weak rotation, backup plaintext.

**Implementation order:** **2** (after rate limiting; alongside backup policy).

---

## 2. Hospital admin portal

**Why:** Hospitals need self-service for sites, branding, user provisioning, audit visibility—without developer access to Mongo.

**Backend schema:** `hospitals` extended (`settings`, `contact`, `status`); `users` linked with `hospital_id`, `permissions[]`.

**API:** CRUD hospitals (admin); read scoped hospital config (hospital_admin); audit export.

**Frontend:** `/admin/hospital` dashboard, user list, session statistics (aggregated).

**Security risks:** Privilege escalation, cross-hospital data leaks—enforce **strict** `hospital_id` scoping on every query.

**Implementation order:** **4** (after roles model).

---

## 3. Camp management

**Why:** Outreach camps are core to Aravind-style delivery; sessions must be attributable to camp + hospital.

**Backend schema:** `camps` already exists—extend with `status`, `lead_staff_id`, `expected_volume`, `closed_at`.

**API:** Camp lifecycle (plan → active → closed); list sessions by `camp_id`; reports export.

**Frontend:** Camp list/create/edit; assign sessions (optional QR/camp code).

**Security risks:** Camp mis-assignment conflates analytics; need immutable session→camp link at creation.

**Implementation order:** **5** (after admin portal MVP).

---

## 4. Staff / optometrist roles

**Why:** Not every user is a senior ophthalmologist; fine-grained permissions reduce error and support delegation.

**Backend schema:** `users.role` extended: `optometrist`, `screener`, `hospital_admin`, `read_only`; `permissions` object or bitmask.

**API:** Middleware `require_permission("review_session")`; session review endpoints restricted.

**Frontend:** Role-based menus; hide diagnosis actions for screeners.

**Security risks:** Misconfigured roles exposing PII or diagnosis features.

**Implementation order:** **3** (before full admin portal features).

---

## 5. Urgent referral workflow

**Why:** Screening must trigger **actionable** escalation—SMS/email/pager per hospital policy.

**Backend schema:** `referral_tasks` (`session_id`, `urgency`, `status`, `assigned_to`, `created_at`, `acknowledged_at`); optional webhooks table.

**API:** Create task on `risk_level == urgent`; acknowledge; list open referrals.

**Frontend:** Doctor/nurse queue; patient-facing “what to do next” consistent with triage (no unsupervised diagnosis).

**Security risks:** Notification PHI leakage; missed escalations if queue not monitored.

**Implementation order:** **6** (after roles + audit confidence).

---

## 6. Follow-up tracking

**Why:** Amblyopia care is longitudinal; hospitals need recall and outcome capture.

**Backend schema:** `follow_ups` (`patient_id`, `due_date`, `status`, `outcome`, `linked_session_id`).

**API:** CRUD follow-ups; reminders (integration with hospital scheduling optional).

**Frontend:** Patient timeline; doctor task list.

**Security risks:** Stale reminders causing inappropriate urgency messaging.

**Implementation order:** **7** (after referral workflow MVP).

---

## 7. OTP / login rate limiting

**Why:** Brute-force OTP and credential stuffing against doctor accounts.

**Backend schema:** None required (in-memory window); optional `auth_attempts` collection for forensics.

**API:** **Implemented:** `429` on `/api/auth/patient/request-otp`, `/api/auth/patient/verify-otp`, `/api/auth/doctor/login` with env-tuned limits; audit on limit + failed login/OTP.

**Frontend:** Display friendly “too many attempts” message on `429`.

**Security risks:** IP-based limits weak behind NAT; prefer Redis + user-aware keys at scale.

**Implementation order:** **1** (done as first P1 slice).

---

## 8. Automated backups

**Why:** Ransomware, operator error, and compliance require recoverable Mongo snapshots.

**Backend schema:** N/A (operations).

**API:** Optional health check reporting last backup timestamp (from object storage manifest).

**Frontend:** Admin ops dashboard only.

**Security risks:** Unencrypted backups = PHI exposure; test restores rarely practiced.

**Implementation order:** **8** (parallel with encryption governance).

---

## Suggested implementation sequence

1. **OTP/login rate limiting** ✅ (first code slice)  
2. **PII encryption key governance** (rotation runbook + env)  
3. **Roles & permissions**  
4. **Hospital admin portal (minimal)**  
5. **Camp management enhancements**  
6. **Urgent referral workflow**  
7. **Follow-up tracking**  
8. **Automated backups + DR drill**

---

*This plan is architectural and does not replace hospital IT security review.*
