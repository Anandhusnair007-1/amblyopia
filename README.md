# AmbyoAI — Pediatric Amblyopia Screening

India's first browser-based pediatric amblyopia (lazy eye) screening PWA — built for Aravind Eye Hospital, Coimbatore.

Six clinical tests. Zero equipment. Works offline. Powered by AI.

## Highlights

- **Two portals**: Patient (phone + OTP) and Doctor (email + password)
- **Six clinical tests**: Visual Acuity, Gaze Detection (MediaPipe), Hirschberg, Prism Diopter, Titmus Stereo, Red Reflex
- **Audio guidance**: Multilingual TTS narration (English / தமிழ் / മലയാളം)
- **Face positioning overlay**: Pulsing oval with quantified distance guidance ("Move back 8 cm")
- **AI risk classifier**: Clinical-fallback thresholds validated against 28 test cases
- **Hospital-grade medical report**: Severity-graded findings with clinical interpretations + PDF + urgent referral letter
- **Enterprise UI**: Glass-morphism, Framer Motion animations, dark test-runner theme, light clinical portals
- **Progressive Web App**: Installable, offline-capable, service worker + IndexedDB queue

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
│  └─ tests/            pytest suite (28 cases)
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

## Clinical thresholds (fallback classifier)

| Finding | Urgent | Moderate/High | Mild |
|---------|--------|---------------|------|
| Gaze deviation | > 20 Δ | > 10 Δ | > 4 Δ |
| Hirschberg displacement | > 4 mm | > 2 mm | — |
| Visual acuity (Snellen) | ≤ 6/24 | ≤ 6/12 | — |
| Red reflex | leukocoria / absent | dim / media opacity | — |
| Titmus stereo | 0 / n passed | < n passed | partial |

## Tests

- Backend: `pytest backend/tests/` — 28/28 ✅
- Frontend: End-to-end testing via Playwright subagent — 100% ✅

## License

Private — Aravind Eye Hospital pilot deployment.

## Roadmap

- [ ] TFLite → TF.js model integration (`public/models/ambyo_model.json`)
- [ ] Full EN / TA / ML i18n coverage on all pages
- [ ] Admin portal (hospital + camp management)
- [ ] Super admin portal
- [ ] Doctor SMS / email urgent alerts
- [ ] Additional tests: Lang, Ishihara, Suppression
