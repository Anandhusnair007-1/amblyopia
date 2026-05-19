# AmbyoAI — Pediatric Amblyopia Screening/Support Prototype

AmbyoAI is a browser-based lazy eye / amblyopia screening and support prototype for supervised internal demo, doctor review, staging preparation, and clinical validation planning.

This project is not a diagnostic medical device. It does not diagnose lazy eye, prescribe glasses, determine patching treatment, or replace an ophthalmologist. Clinical validation is required before public medical claims.

Release `v0.1-clinical-demo` is intended for internal demo and doctor review only.

## Highlights

- **Two portals**: Patient (phone + OTP) and Doctor (email + password)
- **Screening/support modules**: Visual acuity estimate, gaze/fixation proxy, Hirschberg/alignment proxy, prism/alignment proxy, depth/stereo proxy, red reflex safety flow
- **Age-based routing**: Test flow adapts to infant / child / adult / senior bands
- **Audio guidance**: Multilingual TTS narration (English / தமிழ் / മലയാളം)
- **Face positioning overlay**: Pulsing oval with quantified distance guidance ("Move back 8 cm")
- **Clinical safety rules**: Backend age/test enforcement, incomplete/unreliable states, urgent review routing, and patient-safe AI output
- **Doctor review reports**: Severity-graded screening findings, doctor-only details, PDF export, audit logging, and referral workflow support
- **Enterprise UI**: Glass-morphism, Framer Motion animations, dark test-runner theme, light clinical portals
- **Progressive Web App**: Installable, offline-capable, service worker + minimized IndexedDB queue

## Stack

| Layer | Tech |
|-------|------|
| Frontend | React 19 (CRA) · TailwindCSS · shadcn/ui · Framer Motion · Zustand · Dexie · jsPDF · @mediapipe/tasks-vision |
| Backend  | FastAPI · MongoDB (motor) · JWT (HS256) · bcrypt |
| Audio    | Web Speech Synthesis API (TTS) · Web Speech Recognition (STT) |
| Camera   | WebRTC · MediaPipe Face Landmarker (468 landmarks, iris tracking) |

## Project structure

```
/app
├─ backend/             FastAPI + MongoDB server
│  ├─ server.py         All /api routes (auth, patient, doctor, sessions, classifier)
│  ├─ requirements.txt
│  └─ tests/            pytest suite
├─ frontend/
│  ├─ public/           manifest.json, service worker, icons
│  └─ src/
│     ├─ portals/       Landing, PatientLogin, DoctorLogin, PatientHome, DoctorDashboard, DoctorReport, …
│     ├─ tests/         TestRunner, TestStage, 6 individual test components
│     ├─ components/ambyo/  DistancePill, FaceGuide, ScoreRing, UrgentBanner, AudioToggle, CountdownOverlay, MicIndicator, RiskBadge, OfflineBadge, LanguageSwitcher, TestProgressBar
│     ├─ core/
│     │   ├─ auth/      Zustand store + ProtectedRoute
│     │   ├─ audio/     AudioGuide (TTS + narration scripts)
│     │   ├─ camera/    WebRTCCamera, MediaPipeSetup, DistanceCalculator
│     │   ├─ voice/     SpeechEngine, MultilingualParser (STT)
│     │   ├─ offline/   Dexie IndexedDB schema
│     │   └─ i18n/      EN / TA / ML translations
│     └─ reports/       PDFGenerator (jsPDF) + ReferralLetter
├─ memory/              PRD, test credentials
└─ test_reports/        JSON testing history (iterations 1-4)
```

## Getting started (local development)

```bash
# 1. Backend
cd backend
pip install -r requirements.txt
# Set env vars:
export MONGO_URL="mongodb://localhost:27017"
export DB_NAME="ambyoai"
export JWT_SECRET="change-this-in-production"
export CORS_ORIGINS="http://localhost:3000"
uvicorn server:app --host 0.0.0.0 --port 8001 --reload

# 2. Frontend
cd frontend
yarn install
# Set REACT_APP_BACKEND_URL in frontend/.env
yarn start
```

## Test credentials (auto-seeded)

| Role | Credentials |
|------|-------------|
| **Doctor** | `doctor@aravind.in` / `aravind2026` |
| **Patient OTP** | Demo OTP `1234` (works for any 10-digit phone) |

## Safety Positioning

- Screening/support only.
- Not a final diagnosis.
- Does not prescribe glasses.
- Does not determine patching treatment.
- Does not replace an ophthalmologist or qualified eye-care professional.
- Abnormal, incomplete, unreliable, urgent, or parent-concern cases should be reviewed by an eye-care professional.
- Clinical validation is required before public medical claims.

## Clinical-rule thresholds (screening support)

| Finding | Urgent | Moderate/High | Mild |
|---------|--------|---------------|------|
| Gaze deviation | > 20 Δ | > 10 Δ | > 4 Δ |
| Hirschberg displacement | > 4 mm | > 2 mm | — |
| Visual acuity (Snellen) | ≤ 6/24 | ≤ 6/12 | — |
| Red reflex | leukocoria / absent | dim / media opacity | — |
| Titmus stereo | 0 / n passed | < n passed | partial |

## Tests

- Backend: `cd backend && python3 -m pytest -v`
- Frontend: `cd frontend && npm test -- --watchAll=false`
- Build: `cd frontend && npm run build`

Current v0.1 clinical-demo package result:

- Backend: 65 passed, 37 skipped, 0 failed
- Frontend: 27 passed, 0 failed
- Build: succeeded with documented warnings

## License

Private prototype.

## Roadmap

- [ ] TFLite → TF.js model integration (`public/models/ambyo_model.json`)
- [ ] Full EN / TA / ML i18n coverage on all pages
- [ ] Admin portal (hospital + camp management)
- [ ] Super admin portal
- [ ] Doctor SMS / email urgent alerts
- [ ] Additional tests: Lang, Ishihara, Suppression
