# Controlled Pilot Plan

## Pilot Objective

Prepare and evaluate AmbyoAI for safe supervised use as a screening/support workflow under doctor review, while collecting feedback and validation evidence before any public medical release decision.

## Pilot Stages

1. Internal demo: confirm core workflows, role access, audit logs, result wording, and staging stability.
2. Doctor review: collect pediatric ophthalmology/optometry feedback on safety, result states, reports, and escalation wording.
3. Demo patient testing: use test/demo patients only to verify usability and technical reliability.
4. Controlled clinical comparison: compare app screening outputs with clinical examination results under approved consent.
5. Feedback fixes: correct safety, usability, and workflow issues found during pilot.
6. Expanded validation: broaden age, device, lighting, and clinical-condition coverage if early results support continuation.

## Suggested Pilot Size

- Doctor review: 3-5 clinicians.
- Demo patient usability: 10-20 supervised demo/test sessions.
- Initial clinical comparison: 30-50 participants across age/device groups.
- Expanded validation: determined after safety review and statistical planning.

## Roles

- Doctor: clinical oversight, result review, escalation, diagnosis field, follow-up plan.
- Optometrist/orthoptist: supervised screening, clinical comparison support, usability feedback.
- Parent/guardian: consent, calibration, occlusion support, child instruction.
- App admin: user provisioning, hospital scope, audit review, incident coordination.
- Technical support: deployment, logs, bug triage, device/browser support.

## Safety Stop Conditions

Pause pilot enrollment if:

- Patient-facing UI implies diagnosis or treatment.
- Urgent red reflex concern is not escalated.
- Raw AI details appear in patient view.
- Patient can access another patient record.
- Doctor can access records outside scope.
- Patching dosage can be created without a doctor plan.
- Incomplete/unreliable results appear reassuring.
- Report export is not audited.
- Significant data exposure or security incident occurs.

## Feedback Collection Format

- Session ID or demo ID.
- User role.
- Device/browser.
- Test attempted.
- Result state.
- Issue category: safety, clinical, usability, technical, privacy, wording.
- Severity: critical, high, medium, low.
- Screenshot/log reference if appropriate.
- Doctor recommendation.
- Resolution status.

## Incident Reporting

- Critical safety/security incidents reported immediately to clinical and technical leads.
- Preserve audit logs and relevant technical logs.
- Stop affected workflow until triaged.
- Document root cause, fix, retest evidence, and release decision.

## Data Protection Plan

- Use staging-only data for demo unless approved for clinical comparison.
- De-identify validation exports where possible.
- Restrict doctor access by hospital/camp scope.
- Audit all report exports and doctor actions.
- Minimize offline payloads and document device-loss handling.
- Complete client-side offline encryption decision before controlled pilot.

## Success Criteria

- No critical safety or RBAC defects.
- Doctor reviewers agree patient wording is safe.
- Urgent review path works consistently.
- Incomplete/unreliable results are not reassuring.
- Calibration workflow is understandable.
- Parent completion rate meets predefined target.
- Clinical comparison metrics support continued validation.

## Go/No-Go Criteria For Public Release

Go requires:

- Completed clinical validation with acceptable sensitivity/specificity and safety metrics.
- Security review completed.
- Offline data policy finalized.
- Deployment checklist complete.
- Doctor-approved wording and escalation workflows.
- Regulatory/product classification review completed.

No-go if:

- Clinical false-negative risk is unacceptable.
- Any critical RBAC/privacy issue remains unresolved.
- App implies diagnosis or treatment.
- Patching guardrails fail.
- Urgent eye-care review flow is unreliable.

