# Version Freeze

## Freeze Identity

- Product name: AmbyoAI lazy eye / amblyopia screening and support app
- Release name: amblyopia-screening-v0.1-clinical-demo
- Freeze date: 2026-05-19
- Release purpose: internal demo, doctor review, staging readiness, and clinical validation planning

## Version Inventory

- Frontend version: 0.1.0
- Backend version: 2.0.0
- Clinical rule version: clinical-fallback-v3
- Test algorithm version: ambyo-core-2.2
- Calibration version: screen-calibration-v1
- AI/model versions:
  - Quality model: eye_quality_v1
  - Deviation model: deviation_classifier_v0_2_balanced
  - Strabismus/alignment model label: strabismus_v1.0.0
  - Dataset version: environment-provided; default is unknown

## QA Summary At Freeze

- Backend tests: 64 passed, 37 skipped, 0 failed
- Frontend tests: 26 passed, 0 failed
- Frontend production build: succeeded
- Safety wording scan: passed for active patient-facing unsafe claims
- Current software safety verdict: safe for internal demo and doctor review
- Public medical release verdict: not ready

## Safety Positioning

This release is a screening/support workflow only. It does not diagnose lazy eye, prescribe glasses, determine patching treatment, replace an ophthalmologist, or claim clinical validation. Abnormal, incomplete, unreliable, urgent, or AI-flagged results require eye-care professional review.

## Known Limitations

- Calibration is user-assisted and not hardware-certified.
- Distance validation depends on available device/browser signals and workflow confirmation.
- Camera-based occlusion verification is not implemented.
- Offline result payloads are minimized but not client-side encrypted.
- AI output is for screening support and doctor/admin review only; it must not override clinical safety rules.
- Clinical accuracy requires prospective validation against pediatric ophthalmology or qualified optometry examinations.
- Build warnings remain for ESLint plugin discovery, a MediaPipe source map, and large bundle size.

