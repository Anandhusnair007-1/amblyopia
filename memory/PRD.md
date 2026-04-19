# AmbyoAI — Product Requirements Document

## Original Problem Statement
AmbyoAI: India's first browser-based pediatric amblyopia (lazy eye) screening PWA built for Aravind Eye Hospital, Coimbatore. Hospital-grade, enterprise-level medical design. Zero equipment, zero installation, works offline.

## User Decision (Phase 1)
Two portals only: **Patient** (self-service) and **Doctor** (clinical review). Patient sees a simple, friendly report. Doctor sees full medical report with clinical thresholds, severity-graded findings, per-test raw data, and diagnosis form. Six clinical tests: Visual Acuity, Gaze Detection, Hirschberg, Prism Diopter, Titmus Stereo, Red Reflex. Clinical fallback classifier (TFLite model to arrive later). Languages: English + Tamil + Malayalam.

## Architecture
- **Frontend**: React 19 (CRA) + TailwindCSS + shadcn/ui + Framer Motion + Zustand + Dexie (offline) + jsPDF + @mediapipe/tasks-vision
- **Backend**: FastAPI + MongoDB (motor) + JWT (HS256) + bcrypt
- **PWA**: manifest.json + service worker (cache-first assets / network-first API) + SVG icons

## User Personas
1. **Patient / Guardian** — signs in on a personal phone, runs a 3-minute self-screening, gets a plain-language result and PDF.
2. **Doctor** — hospital ophthalmologist who reviews all submitted screenings, reads detailed clinical metrics, writes diagnosis/treatment, downloads medical PDF + urgent referral letter.

## Core Requirements (static)
- 4-toggle informed consent before any screening
- 6-test flow with 3-2-1 countdown, distance pill (MediaPipe face bounding box), progress bar
- Clinical thresholds: gaze > 20Δ urgent; hirschberg > 4 mm urgent; red reflex white/absent urgent; VA ≥ 6/24 urgent
- Role-enforced API (patient cannot read other patients; patient prediction excludes `medical_findings`)
- PDF report (cover / summary / per-test detail / doctor review)
- Urgent referral letter for risk=urgent (Aravind branches selectable)
- Offline PWA (service worker + IndexedDB queue)

## Implemented (v2.0.0 — Feb 2026)
- Landing page with dual portal cards (Patient / Doctor)
- Patient OTP auth (phone + demo OTP 1234) with pending→registered token upgrade
- Patient register form, consent, session, 6 tests, simple results + PDF
- Doctor email/password auth (seeded `doctor@aravind.in` / `aravind2026`)
- Doctor dashboard (stats, risk filter, name search, patient list)
- Doctor patient detail (profile + session history)
- Doctor medical report (score ring, severity-graded medical findings, per-test raw data expandable, diagnosis form, PDF + referral letter)
- Backend (28/28 tests green) — all classifier cases (urgent / normal) validated
- Frontend (23/24 flows green) — navigation, auth, role guards, forms, PDF buttons
- Seeded: Aravind hospital + Dr. Meera Sundaram + 6 TEST_-prefixed demo patients (incl. urgent cases)
- i18n scaffolding (EN / TA / ML) on LoginScreen, ConsentScreen, TestRunner

## Known Issues / Tech Debt
- Language switcher labels appear on all pages but v2 page strings are hardcoded English (only LoginScreen/Consent/TestRunner re-render on lang change). Non-blocking.
- JWT_SECRET uses dev fallback — must be set via env in production.
- `pin_login` flow removed (v1 worker portal deprecated).
- No rate limit on doctor login endpoint.
- Playwright automated clicks on the preview URL can be intercepted by the dev visual-edits plugin — verified via testing agent instead.

## Prioritized Backlog
### P0 (next)
- Wire up t() calls in v2 portal pages (Landing, PatientLogin, DoctorLogin, PatientHome, PatientRegister, DoctorDashboard, DoctorPatientDetail, DoctorReport, PatientResults)
- TFLite → TF.js model integration when user provides `ambyo_model.json`

### P1
- Test history on doctor-side timeline view (compare across sessions)
- Urgent-case SMS / email alert to doctor (Resend or Twilio)
- Admin portal (hospital management, camps)

### P2
- Super admin portal
- Doctor 2FA
- Audit log viewer UI
- Background-sync offline queue UI
- Full 9-test flow (add Lang, Ishihara, Suppression)

## Test Credentials
See `/app/memory/test_credentials.md`:
- Doctor: doctor@aravind.in / aravind2026
- Patient OTP: 1234 (any 10-digit phone)

## v2.1 (Feb 2026) — UX Overhaul
- **Audio guidance system**: Web Speech Synthesis TTS narrates every test intro + feedback in EN/TA/ML. Multilingual NARRATION map for each test. Global AudioToggle (mute/unmute) persists in localStorage. Countdown speaks "Three… two… one… GO".
- **Face positioning overlay (FaceGuide)**: Pulsing oval with 4 colour states (green good / red too-close / amber too-far / grey no-face), corner crop marks, quantified arrow ("Move back 8 cm"), target-range hint. Appears as positioning gate before every camera test.
- **Auto-start**: Test begins automatically when user holds the good-distance zone for 1.2 seconds. Manual "Start now" bypass button available.
- **Individual test mode**: PatientHome features 6 quick-test cards alongside the full-screening CTA. `?quick=1` URL param ends session after single test.
- **Countdown overlay**: Spring-animated 3-2-1 with gradient text and TTS.
- **TestStage**: Shared camera + face-gate + countdown wrapper used by all 6 tests — consistent UX with minimal per-test boilerplate.
- **TestRunner**: Glass-morphism top bar (audio toggle, offline, lang switcher, exit, skip), ambient glow orbs, smoother route transitions.
- Pinned MediaPipe tasks-vision@0.10.14 CDN (0.10.22 wasm 404s).
- Test results: Backend 28/28 PASS, Frontend 100% v2.1 flows verified.
