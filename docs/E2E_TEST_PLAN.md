# End-to-end (E2E) test plan — AI gate & portals

**Status:** No Playwright (or other E2E) harness is present in this repository snapshot. This document is the **plan only**. Implement when product priority allows.

## Prerequisites (when implementing)

- Backend running with MongoDB, seeded doctor, demo OTP enabled (`ENABLE_DEMO_OTP=true`).
- Frontend `REACT_APP_BACKEND_URL` pointing at the API.
- Optional: TensorFlow models loaded if testing real `/api/ai/screen-quality` success paths.

## Recommended toolchain

- **Playwright** (`@playwright/test`) or **Cypress** for browser automation.
- Baseline commands (after adding Playwright):

```bash
cd frontend
yarn add -D @playwright/test
npx playwright install
npx playwright test
```

(CRA-specific: ensure tests run against `yarn start` or a production build served locally.)

## Test cases

### TC1 — Patient starts gaze → AI gate appears

- **Given:** Patient logged in (OTP), consent completed, session started, navigated to gaze step.
- **Expect:** Element `[data-testid="ai-screening-gate"]` (or equivalent) visible before gaze UI.

### TC2 — Gate passes → test begins

- **Given:** Gate visible; backend returns `quality.is_usable: true` for captured frame (or mock API).
- **Expect:** Gate dismisses; gaze test UI (e.g. dots / MediaPipe stage) visible within timeout.

### TC3 — Gate fails → patient sees safe hint only

- **Given:** Backend returns `quality.is_usable: false` with label e.g. `dark`.
- **Expect:** User-visible text matches lighting / framing guidance; **no** ET/XT/confidence/model jargon.

### TC4 — Continue without AI → unavailable version stored

- **Given:** Gate shows continue-without-AI path (e.g. after 503 or explicit button).
- **Expect:** Session result for gaze includes `details.quality_gate.quality_model_version === "unavailable"` after completing step.

### TC5 — Doctor report shows AI insights

- **Given:** At least one `ai_deviation_insights` row for session (from gated capture with `session_id` + `test_name`).
- **Expect:** Doctor session view shows doctor-only section (e.g. `[data-testid="ai-deviation-insights"]`) with structured deviation metadata.

### TC6 — Patient results hide XT/ET/confidence

- **Given:** Completed session with doctor insights present in DB.
- **When:** Patient opens results / API returns patient GET.
- **Expect:** Response body contains no `ET`/`XT` deviation labels, no model confidence fields in patient JSON.

### TC7 — Prism / Titmus / VA not blocked by gate

- **Given:** Session flow reaches prism, titmus, visual acuity.
- **Expect:** No full-screen gate component before those steps (only gaze/hirschberg/red_reflex).

## Non-goals for E2E

- Training or re-running ML pipelines.
- Changing clinical thresholds from UI.

---

*Add this suite to CI after Playwright is installed and stable seed data is available.*
