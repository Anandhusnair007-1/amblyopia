# Clinical test methodology (AmbyoAI screening proxies)

This document explains **how each screening test works in the app**, what numbers mean, and how results relate to in-clinic examination. It is written for clinicians (e.g. Dr. Sandra / Aravind team review).

**Important:** All six tests are **screening proxies** on a consumer phone or tablet. They do **not** replace slit-lamp, cover test, Randot/Titmus stereo, or fundus-camera red-reflex examination.

---

## 1. Hirschberg test (corneal light reflex)

### Clinical reference (Dr. Sandra)

| Reflex position on cornea | Prism estimate (screening grade) |
|---------------------------|--------------------------------|
| Center | 0 Δ |
| Pupil edge | 15 Δ |
| Between pupil and limbus | 30 Δ |
| At limbus | 45 Δ |

### How the app measures it

1. **White full-screen flash** (~2 s) while the front camera captures the face.
2. **MediaPipe Face Landmarker** tracks iris landmarks (indices 468–477).
3. **Iris center** = mean of iris landmark positions; **iris diameter** = max pairwise distance among iris landmarks (pixels).
4. **Corneal reflex** = brightest pixel cluster in a padded iris region (adaptive luminance threshold).
5. **Offset** = distance from iris center to reflex (pixels), converted to mm using an average iris diameter of **11.8 mm**.
6. **Zone mapping:** normalized offset `r = displacementPx / (irisDiameterPx / 2)` is compared to tunable thresholds in `backend/clinical_constants.json`:
   - `r < 0.35` → center → **0 Δ**
   - `r < 0.85` → pupil edge → **15 Δ**
   - `r < 1.35` → between pupil and limbus → **30 Δ**
   - else → limbus → **45 Δ**

### Stored fields (doctor view)

- `predicted_pd`, `hirschberg_zone`, `displacement_mm`, `estimatedPD_continuous` (mm × 22 legacy), sample count, confidence.

### Limitations

- Not calibrated to a known light source or Kappa angle.
- Flash/reflection artifacts can shift the brightest blob.
- Zone thresholds should be validated with local capture samples.

---

## 2. Titmus / stereo depth screening

### Clinical reference (Dr. Sandra) — arc-seconds

| Arc-seconds | Grade |
|-------------|--------|
| 40–60 | Normal |
| 61–200 | Mild impairment |
| 201–800 | Moderate |
| 801–2000 | Severe |
| > 2001 | Absence of stereopsis |

### How the app estimates arc-seconds

This is **not** a physical Titmus or Randot book. The app runs a **graded on-screen depth quiz**:

1. Levels run from **coarse → fine** disparity (see `frontend/src/core/vision/stereoLevels.js`).
2. At each level the patient answers fly / animal / circle depth questions.
3. **Stop at first failure**; `arc_seconds` = finest level passed (or **2500** if none).
4. Backend maps `arc_seconds` to the bands above (`classify_titmus_arc_seconds` in `clinical_classifier.py`).

### Limitations

- Flat screen, no polarized filters, no calibrated viewing distance for stereo.
- Borderline results should be confirmed with in-clinic Randot/Titmus.

---

## 3. Red reflex

### Clinical reference

Fundus cameras use **coaxial illumination**; a **red/orange** pupil reflex indicates light returning from the retina (normal). **White** or absent reflex raises concern for leukocoria / media opacity.

### How the app measures it

1. **White full-screen flash** (~2 s), front camera at **25–35 cm** (distance gate).
2. **21×21 pixel patch** centered on each iris landmark (left 468, right 473).
3. Per eye: average RGB → HSV + **red_ratio** = R / (R+G+B).
4. **Normal:** red hue, saturation > 0.35, brightness > 0.3, red_ratio ≥ 0.38 (both eyes).
5. **Leukocoria:** very bright + low saturation on **either** eye.
6. Session classification = **worst eye**; `asymmetric` if left ≠ right.

### Limitations

- Consumer camera + screen flash ≠ coaxial fundus camera.
- Glare, dark room, or off-axis gaze can mimic abnormal reflex.
- Abnormal screening results need clinical red-reflex confirmation.

---

## 4. Gaze and prism (brief)

- **Gaze:** MediaPipe iris/gaze stability proxy; thresholds in arc-minute–like index (uncalibrated).
- **Prism:** Cover-test style animation; PD from iris shift angle — screening proxy only.

---

## 5. Data storage (MongoDB)

**System of record:** MongoDB (`MONGO_URL`, database `ambyoai` by default).

| Collection | Purpose |
|------------|---------|
| `patients` | Demographics; encrypted PII (name, phone, DOB) |
| `test_sessions` | Screening session metadata, risk level |
| `test_results` | Per-test `raw_score`, `details` (full measurements for clinicians) |
| `ai_predictions` | Classifier output, medical_findings |
| `doctor_diagnoses` | Clinician review |
| `hospitals`, `camps`, `devices` | Pilot deployment |
| `audit_logs` | Security / export audit |

**Browser IndexedDB** (`frontend/src/core/offline/db.js`) queues sessions offline only until sync — not the hospital record.

**Why MongoDB:** Nested screening documents (six tests + AI metadata) fit a flexible schema; scales via self-hosted Docker or MongoDB Atlas.

---

## 6. Devices and responsive layout

- `frontend/public/index.html` includes standard mobile viewport: `width=device-width, initial-scale=1`.
- UI uses Tailwind responsive breakpoints; PWA manifest locks portrait for tests.
- `@emergentbase/visual-edits` in CRACO is **development-only** visual editing — **not** required for production device scaling.
- Test UI uses `env(safe-area-inset-*)` for notched phones.

Supported browsers: modern Chrome, Edge, Safari (see `frontend/package.json` browserslist).

---

## 7. Local development and deployment path

```bash
# MongoDB + API
cd backend && uvicorn server:app --host 0.0.0.0 --port 8001 --reload

# React dev server
cd frontend && yarn start   # http://localhost:3000

# Or Docker Compose (Mongo + API + nginx UI)
docker compose up --build   # http://localhost:8080
```

Production: HTTPS, strong secrets, `ENV=production`, managed MongoDB — see `docs/HOSTING_DEPLOYMENT_GUIDE.md`.

---

## 8. Patient vs doctor visibility

- **Doctors** receive full `test_results.details` from the API.
- **Patients** receive sanitized `screening_status` / labels only (no raw PD, mm, or arc-seconds) per `backend/ai_response_policy.py`.

---

*Version aligned with clinical_constants.json `clinical-fallback-v3` and iris-radius Hirschberg zone mapping.*
