# Doctor Demo Package

## App Purpose

AmbyoAI supports lazy eye / amblyopia screening workflows, parent-guided test completion, result tracking, and doctor review. It is intended for screening support and workflow documentation, not final diagnosis.

## What The App Does

- Guides parents/guardians through consent, history, calibration, distance setup, and test flow.
- Routes tests by age group.
- Supports visual acuity, red reflex, gaze/fixation proxy, Hirschberg/alignment proxy, prism proxy, Titmus/stereo proxy where available, and patching adherence tracking when a doctor-created plan exists.
- Stores calibration, device, distance, age-at-test, result state, revision, rule/model metadata, and audit events.
- Separates patient-safe results from doctor-only raw details.
- Routes abnormal, incomplete, unreliable, urgent, or AI-flagged findings to doctor review.

## What The App Does Not Do

- It does not diagnose lazy eye or amblyopia.
- It does not prescribe glasses.
- It does not determine patching treatment.
- It does not replace an ophthalmologist, optometrist, or orthoptist.
- It does not claim clinical validation for public medical use.
- It does not show raw AI labels or confidence values to patients.

## Target Users

- Parent/guardian: consent, history, calibration, child test assistance, safe result review.
- Patient/child: guided test interaction with simple instructions.
- Doctor: review queue, test history, raw clinical details, diagnosis field, follow-up plan, referral workflow.
- Optometrist/clinical staff: screening support, scoped clinical review, and referral coordination as permitted by RBAC.

## Screening Flow

1. Login or registration.
2. Age/date-of-birth capture.
3. Guardian consent and medical disclaimer.
4. Vision and health history.
5. Calibration using card or ruler.
6. Distance and lighting readiness check.
7. Monocular OD/OS instructions with parent confirmation.
8. Test execution.
9. Result state assignment: completed, incomplete, unreliable, needs_review, or urgent_review.
10. Patient-safe result page.
11. Doctor review queue and report.
12. Follow-up or referral if clinically appropriate.

## Test Modules For Review

- Visual acuity: calibration-aware optotype sizing, distance validation, OD/OS separation, inter-eye difference review trigger.
- Red reflex: abnormal, absent, white-pupil-like, or poor-quality results route to urgent/review handling.
- Gaze/fixation proxy: poor quality becomes unreliable; does not diagnose fixation disorder.
- Hirschberg/alignment proxy: uses eye alignment screening concern wording, not a strabismus diagnosis.
- Titmus/stereo proxy: documented as a screening proxy, not a validated clinical stereo test.
- Patching tracker: adherence tracking only after a doctor creates a patching plan.

## Doctor Dashboard

Doctors should review patient profile, age, session history, result trend/revision history, calibration data, device data, rule/model metadata, raw doctor-only AI details, diagnosis field, follow-up date, referral controls, and audit trail visibility.

## Patient Result Explanation

Patients should see plain screening language only:

- No major screening concern on this pass
- Screening concern found
- Result needs doctor review
- Incomplete or unreliable screening
- Urgent eye-care review recommended

Patient-facing views must not show diagnosis-like AI labels, internal confidence scores, or raw model classes.

## Patching Guardrails

The app must show: Use patching only as prescribed by an eye-care professional. Parents cannot create medical patching dosage. The tracker activates only with an active doctor-created plan and records adherence, missed sessions, partial sessions, and parent notes.

## Red Reflex Urgent Review Flow

If red reflex is abnormal, absent, white-pupil-like, media-opacity-like, or image quality is suspicious, the patient-facing message is: Urgent eye-care review recommended. Doctor reports may show detailed findings, quality score, image metadata, and rule/model version.

## AI Safety Policy

AI findings are screening support only. AI must not override clinical safety rules. Patient output is sanitized. Raw model version, confidence, quality labels, and class-level details are doctor/admin-only.

## Screens Doctors Should Review

- Patient onboarding and consent
- History questionnaire
- Calibration panel
- Visual acuity test
- Red reflex test
- Gaze/fixation and alignment proxy tests
- Patient result page
- Doctor dashboard
- Doctor report
- Referral/export flow
- Audit log view
- Patching plan and adherence views

## Doctor Feedback Questions

- Are the patient-facing result categories medically safe and understandable?
- Are any result states too reassuring or too alarming?
- Are the urgent review triggers appropriate?
- Is calibration guidance realistic for parents?
- Are OD/OS occlusion instructions clear enough?
- Does the doctor report contain enough raw detail for review?
- Are patching guardrails strong enough?
- What would block use in a controlled clinical comparison?

## Known Limitations

- Calibration is user-assisted, not hardware-certified.
- Camera-based occlusion verification is not implemented.
- Offline payloads are minimized but not encrypted client-side.
- Clinical accuracy has not yet been validated against real pediatric eye examinations.

## Safety Disclaimer

This app provides screening and support only. It does not diagnose lazy eye, prescribe glasses, determine patching treatment, or replace an eye doctor. If screening is abnormal, incomplete, or if a child has eye turning, white pupil, poor vision, eye pain, trauma, or parent concern, consult a pediatric ophthalmologist or qualified eye-care professional.

