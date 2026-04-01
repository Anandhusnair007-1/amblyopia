# Vision Screening Status

## Current state

This repository already contains a working Flutter mobile application structure for:

- Patient, worker, and doctor roles
- Consent flow
- Offline local database and report generation
- Camera-based eye scan and gaze-related analysis
- Voice-guided test flow
- PDF reporting and backend sync

## Tests present in the codebase

Implemented screens/controllers exist for:

- Snellen visual acuity
- Worth 4 Dot
- Titmus stereo
- Lang stereo
- Ishihara color vision
- Suppression test
- Depth perception
- Gaze detection
- Prism diopter estimation
- Hirschberg test
- Red reflex test

## Important updates made

The full screening flow was adjusted to better match the clinical notes:

- `Worth 4 Dot` is now included in the main full-screening sequence
- `Snellen` was moved to the end of the sequence
- Progress UI now reflects 11 tests instead of 10
- Final report data now includes `Worth 4 Dot`
- PDF summary now includes `Worth 4 Dot`
- Eye scan now routes into the corrected first test in the sequence

## Current sequence

1. Eye scan
2. Worth 4 Dot
3. Titmus stereo
4. Lang stereo
5. Ishihara color
6. Suppression
7. Depth perception
8. Gaze detection
9. Prism diopter
10. Hirschberg
11. Red reflex
12. Snellen visual acuity
13. Final report

## Gaps still remaining

These areas still need product or clinical decisions:

- The current `Worth 4 Dot` implementation is a practical mobile adaptation using voice/tap responses and eye covering prompts, not a strict red-green goggle implementation.
- `Titmus` classically depends on stereo separation; a standard phone cannot perfectly reproduce the original polarized-card workflow.
- iOS offline voice control is not fully equivalent to Android offline Vosk in this codebase.
- Some tests are screening-oriented digital approximations and should not be described as full replacements for formal ophthalmic examination without validation.
- The AI prediction pipeline exists, but clinical dataset validation and calibration are still essential before deployment.

## Recommended direction

Best practical path for a real mobile screening product:

- Keep `Lang` as the main glasses-free stereopsis screening option.
- Keep `Worth 4 Dot` only as an adapted screening workflow unless you add approved physical filters or clinically validate a replacement.
- Use camera-based gaze, Hirschberg, prism estimation, and red-reflex automation as the core differentiator.
- Keep `Snellen` last, as required.
- Upgrade voice control to a cross-platform offline stack for Android and iOS.
- Treat any glasses-free replacement for binocular-fusion tests as a research feature until clinically validated.

## Open-source candidates to evaluate

- `sherpa-onnx`: better candidate for fully offline cross-platform speech control than the current Android-first Vosk Flutter path.
- `MediaPipe Face Landmarker / Iris`: stronger option if you want more consistent facial/iris landmarks across Android and iOS.
- `OpenCV`: already a good fit for CLAHE, green-channel preprocessing, corneal reflex highlighting, and classical image analysis.

These should be added only after platform testing and clinical review, not just for feature count.
