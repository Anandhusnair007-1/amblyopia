# AI gate validation report

**Baseline:** Current tree with `AIScreeningGate` wired in `TestRunner` for `gaze`, `hirschberg`, and `red_reflex`; patient API sanitization; `ai_deviation_insights` for doctors; `classify_risk` unchanged; no new models; no clinical threshold changes.

**Date note:** Generated as part of engineering validation; not a clinical study.

## Files tested

| File | Purpose |
|------|---------|
| `backend/tests/test_ai_gate_static.py` | Policy + `TestRunner.jsx` gate set (no Mongo) |
| `backend/tests/test_ai_response_policy.py` | Patient-safe JSON, scrubbing, `classify_risk` smoke |
| `backend/tests/test_ai_gate_validation.py` | Session versioning, doctor/patient GET, OTP rate limit (requires `motor` + imports `server`) |
| `backend/tests/test_rate_limit_unit.py` | Sliding-window limiter unit tests |
| `backend/ai_response_policy.py` | Sanitization helpers |
| `backend/rate_limit.py` | OTP/login rate limiting |
| `frontend/src/tests/TestRunner.jsx` | `CAMERA_QUALITY_GATE_TESTS` |
| `frontend/src/components/ambyo/AIScreeningGate.jsx` | Patient-safe messaging |

## API behavior — patient

- **`POST /api/ai/screen-quality`:** Response omits deviation, ET/XT, and confidence; includes `quality.label`, `quality.is_usable`, `patient_hint`, `disclaimer`, versioning metadata only.
- **`GET /api/sessions/{sid}`:** `prediction` and `results[].details` are sanitized (no raw gaze/Hirschberg/prism/red-reflex measurements in JSON; no `ai_deviation_insights` key).
- **Auth:** OTP request/verify and doctor login subject to rate limits (`429` when exceeded); failed OTP / failed doctor login audited.

## API behavior — doctor

- **`POST /api/ai/screen-quality`:** Full engine payload including optional deviation (doctor review context).
- **`GET /api/sessions/{sid}`:** Includes `ai_deviation_insights` when records exist.
- **Clinical rule output:** `medical_findings` and full prediction revision remain available on doctor-facing payloads where implemented.

## Gate behavior by test

| Test | Quality gate? |
|------|----------------|
| Visual acuity | No |
| Gaze | Yes |
| Hirschberg | Yes |
| Prism diopter | No (derived from stored gaze) |
| Titmus | No |
| Red reflex | Yes |

## Failure when AI model is unavailable

- Backend **`screen_eye`** may return **503** if quality model is not loaded.
- Frontend gate offers **“Continue without automatic check”** and stores `quality_model_version: "unavailable"` in `details.quality_gate` when used.
- **`classify_risk`** uses stored clinical test results only; it does not depend on Keras models.

## Remaining risks

| Risk | Mitigation |
|------|------------|
| In-memory rate limits reset on process restart; multi-worker counts not shared | Use Redis-backed limiter for production scale |
| `X-Forwarded-For` spoofing if proxy not trusted | Configure trusted proxy hops / network isolation |
| Patient PDF client-side generation could theoretically use stale cached data | Ensure patient UI always uses latest GET after completion |
| Static threshold rules vs real-world variance | Clinical validation (below) |

## What must be clinically validated before deployment

- Agreement between **screening outputs** and **in-person examination** for target age groups and environments (lighting, device diversity).
- **Red reflex** heuristic vs clinical examination under standard illumination.
- **Gaze / MediaPipe** geometry vs gold-standard alignment measures in the intended use setting.
- **AI quality model** false accept/reject rates for unusable frames.
- **Deviation model** (doctor-only) precision/recall and failure modes; human override workflow.
- **Consent, referral pathways, and urgent escalation** with hospital medical governance.

---

*This document does not claim regulatory clearance or clinical validation.*
