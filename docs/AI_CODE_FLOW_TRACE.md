# AmbyoAI — AI code flow trace

This document maps **training scripts**, **runtime AI**, **frontend** usage, **API contracts**, **MongoDB fields**, and **gaps in lifecycle versioning**. It reflects the codebase as wired for **AI-assisted screening only** (not diagnosis).

## 1. Training / offline scripts (`scripts/`)

| File | Role |
|------|------|
| `train_deviation_classifier.py` | Trains binary ET vs XT image classifier (EfficientNetB0, verified CSV labels). |
| `train_image_quality.py` | Quality class training (`good`, `blurred`, etc.). |
| `train_prototype.py` | Alternative/older quality training path. |
| `filter_verified_dataset.py` | Builds `verified_training_labels.csv` for training. |
| `split_dataset.py` | Train/val/test splits. |
| `extract_dataset.py` / `scavenge_dataset.py` | Dataset extraction utilities. |
| `create_frozen_v1.py` | Frozen image assets for training. |
| `validate_live_camera_dataset.py` | Dataset validation. |
| `import_et_doctor_review.py` / `filter_verified_dataset.py` / `prepare_*` | Review/audit prep utilities. |
| `test_ai_engine.py` | Script-level checks for `ai_engine`. |
| `test_p0_hardening.py` | Hardening checks. |

**Note:** The running app does **not** train models. Training is offline; weights are loaded from `backend/models/` at runtime.

## 2. Runtime AI — backend

| File | Role |
|------|------|
| `backend/ai_engine.py` | Loads Keras quality + optional deviation models; `screen_eye()` returns quality + optional deviation. |
| `backend/ai_response_policy.py` | **Pure functions**: patient vs doctor JSON for screen endpoint; sanitize session/prediction for patients. |
| `backend/server.py` | `POST /api/ai/screen-quality`, session CRUD, `classify_risk()`, persistence to `ai_deviation_insights`, `ai_predictions`, `test_results`. |

**Collections:**

- `ai_deviation_insights` — **doctor-only** rows from optional `session_id` + `test_name` on screen-quality (stores deviation + quality metadata + versioning).
- `ai_predictions` — Session-level **clinical rule engine** output + versioning fields (immutable revisions).
- `test_results` — Per-test scores/details (full clinical measurements remain in DB; **patient GET** returns sanitized details).

## 3. Frontend — AI-related files

| File | Role |
|------|------|
| `frontend/src/components/ambyo/AIScreeningGate.jsx` | Pre-test **camera quality gate** (multipart upload + patient-safe messages). |
| `frontend/src/tests/TestRunner.jsx` | Shows gate before **gaze**, **hirschberg**, **red_reflex**; merges `details.quality_gate` into saved results. |
| `frontend/src/core/camera/MediaPipeSetup.js` | MediaPipe Face Landmarker (Google pretrained) — geometry, not custom training. |
| `frontend/src/core/camera/WebRTCCamera.jsx` | Camera feed (used by `TestStage` and `AIScreeningGate`). |
| `frontend/src/tests/GazeTest.jsx` / `HirschbergTest.jsx` / `RedReflexTest.jsx` | Clinical heuristics + MediaPipe; not Keras. |
| `frontend/src/portals/doctor/DoctorReport.jsx` | Doctor view; may show `ai_deviation_insights` when returned by API. |

## 4. Is `AIScreeningGate` used?

**Yes.** `TestRunner.jsx` imports it and renders it before camera-based tests **gaze**, **hirschberg**, and **red_reflex** until the gate passes.

## 5. `POST /api/ai/screen-quality` — request / response

**Request:** `multipart/form-data`

- `file` (required): JPEG frame.
- `session_id` (optional): Links insight to a session for doctor-only storage.
- `test_name` (optional): e.g. `gaze`, `hirschberg`, `red_reflex`.

**Authorization:** Bearer JWT (patient or doctor).

**Internal processing:** `ai_engine.screen_eye()` → quality always; deviation only if quality usable and deviation model loaded.

**Patient response (safe subset):**

```json
{
  "quality": { "label": "good|blurred|dark|bad_crop|reflection_issue|unknown", "is_usable": true },
  "patient_hint": "ready|improve_lighting|hold_steady|center_face|retake_image",
  "disclaimer": "…not a diagnosis.",
  "app_version": "2.0.0",
  "quality_model_version": "eye_quality_v1"
}
```

No `deviation`, no ET/XT, no confidence values.

**Doctor/admin response:** Full engine payload including optional `deviation` (`possible_type`, `confidence`, `score`), `doctor_review_required`, `disclaimer`, model version fields.

**HTTP 503:** Quality model not loaded — client may continue screening without automatic check (see gate UX).

## 6. Patient-safe vs doctor-only

| Data | Patient | Doctor |
|------|---------|--------|
| Quality label / usable flag | Yes (via gate UX + optional `quality_gate` in stored details) | Yes |
| Quality model confidence | **No** | Yes (in raw engine / stored insight) |
| Deviation possible_type (ET/XT/uncertain) | **No** | Yes (`ai_deviation_insights`, full screen response) |
| Clinical rule outputs (`medical_findings`) | **No** on GET | Yes |
| Raw gaze/Hirschberg/prism/red strings in `test_results.details` | **Stripped on GET** (DB unchanged for rules engine) | Full |

## 7. MongoDB — AI-related fields

**`ai_deviation_insights`** (per gate call when `session_id` + `test_name` present):

- `session_id`, `test_name`, `created_at`
- `quality`, `deviation`, `doctor_review_required`, `disclaimer`
- `app_version`, `quality_model_version`, `deviation_model_version`, `dataset_version`, `test_algorithm_version`, `prediction_created_at`

**`test_results.details.quality_gate`** (patient-safe, written by app):

```json
{
  "checked": true,
  "quality_label": "...",
  "is_usable": true,
  "quality_model_version": "...",
  "checked_at": "ISO-8601"
}
```

**`ai_predictions`** (on session complete): includes clinical rule output plus `app_version`, `quality_model_version`, `deviation_model_version`, `dataset_version`, `test_algorithm_version`, `clinical_rule_version`, `prediction_created_at`.

**`test_sessions`** (on complete): mirrors key versioning fields for audit/debug.

## 8. Fields each of the six tests writes

Stored in `test_results` (full `details` in DB); patient GET returns **sanitized** `details` per `ai_response_policy.sanitize_detail_for_patient`.

| Test | Typical `details` keys (full DB) |
|------|-----------------------------------|
| `visual_acuity` | `snellen_denominator`, line/error metadata |
| `gaze` | `max_deviation_pd`, `per_direction`, calibration |
| `hirschberg` | `displacement_mm`, samples |
| `prism` | `max_prism_diopters`, `derived_from`, links to gaze |
| `titmus` | `passed`, `total` |
| `red_reflex` | `classification`, HSV samples |

After gate wiring, **gaze / hirschberg / red_reflex** may also include **`quality_gate`** (patient-safe).

## 9. How `classify_risk()` consumes results

`server.py` → `classify_risk(results)` reads **only** rule-relevant fields:

- `red_reflex.details.classification`
- `gaze.details.max_deviation_pd`
- `hirschberg.details.displacement_mm`
- `visual_acuity.details.snellen_denominator`
- `titmus.details.passed` / `total`
- `prism.details.max_prism_diopters`

It does **not** use Keras deviation output. AI quality/deviation assist **does not** replace this engine.

## 10. Lifecycle versioning — gaps / implemented

**Implemented (session completion + AI insights):**

- `app_version`, `clinical_rule_version`, `quality_model_version`, `deviation_model_version`, `dataset_version`, `test_algorithm_version`, `prediction_created_at`

**Remaining gaps (product / ops):**

- Central **model registry** (artifact SHA, training git hash, calibration report linkage).
- Automated **schema migration** for `ai_deviation_insights` / `ai_predictions` revisions.
- **Monitoring** for 503 rate from `/api/ai/screen-quality` and drift alerts (ops, not code-only).

---

*This trace is descriptive documentation only; it does not claim clinical validation.*
