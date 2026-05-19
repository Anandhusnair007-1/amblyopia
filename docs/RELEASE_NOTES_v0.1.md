# Release Notes v0.1 Clinical Demo

## Summary

This release prepares AmbyoAI for internal demo, doctor review, staging deployment planning, and clinical validation planning. The app remains a screening/support tool only.

## Clinical Safety Improvements

- Safer patient-facing result wording.
- Explicit incomplete, unreliable, needs-review, and urgent-review result states.
- Age-based test enforcement on backend.
- Calibration-aware visual acuity workflow.
- Distance validation and reliability handling.
- OD/OS monocular occlusion instructions.
- Red reflex urgent review routing.
- Patient-safe AI output sanitization.
- Doctor-only raw AI and metadata views.
- Result revision history.
- Patching tracker guardrails requiring a doctor-created plan.
- Report export audit logging.

## Backend Changes

- Clinical rule version tracked as clinical-fallback-v3.
- Test results store age-at-test, calibration, device, rule/model metadata, revision, and latest markers.
- Backend rejects age-inappropriate tests.
- Backend preserves old result attempts.
- Doctor/staff session access is hospital-scoped.
- `/api/version` exposes release/version metadata for staging checks.

## Frontend Changes

- Calibration panel supports standard card and ruler workflows.
- Visual acuity uses calibration when available and warns when uncalibrated.
- Monocular testing includes clear OD/OS covering instructions.
- Patient result pages avoid diagnosis-like wording and raw AI details.
- Doctor reports include calibration, device, rule/model, and revision metadata.
- Offline queue minimizes cached result payloads.
- Frontend displays: Clinical demo version - screening/support only.

## Test Results

- Backend: 64 passed, 37 skipped, 0 failed.
- Frontend: 26 passed, 0 failed.
- Production build: succeeded.

## Build Warnings

- ESLint webpack plugin not found: does not block staging because the build script disables the CRA ESLint plugin. Keep separate linting in CI before production.
- Missing source map for `@mediapipe/tasks-vision`: does not block staging; affects debugging only.
- Bundle size larger than recommended: does not block staging; review code splitting and MediaPipe lazy loading before public release.

## Offline Data Decision

Offline payloads are minimized and avoid raw images/raw AI labels, but local browser storage is not encrypted. This is acceptable for internal demo on controlled devices, but controlled pilot should either add client-side encryption or require strict managed-device procedures.

## Remaining Limitations

- Not clinically validated.
- Calibration is user-assisted, not hardware-certified.
- Camera-based occlusion verification is not implemented.
- Offline health data is minimized but not client-side encrypted.
- Build warnings remain.
- Regulatory/product classification review is still required before public medical release.

## Next Milestone

Doctor review and staging deployment checklist completion, followed by a controlled clinical validation plan review.

## Safety Disclaimer

This app provides screening and support only. It does not diagnose lazy eye, prescribe glasses, determine patching treatment, or replace an eye doctor. Clinical validation is required before public medical claims.

