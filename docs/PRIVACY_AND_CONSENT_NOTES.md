# Privacy And Consent Notes

## What Data Is Collected

- Patient/guardian account and contact details.
- Child age/date of birth and profile details.
- Guardian consent and consent version.
- Vision and health history responses.
- Test results, result states, and timestamps.
- Calibration and device metadata.
- Doctor review notes, diagnosis field, follow-up date, and referral status where entered by clinicians.
- Audit logs for important access, changes, exports, and clinical actions.
- Offline queue metadata when network is unavailable.

## Why Data Is Collected

Data is collected to support screening workflow completion, doctor review, safety escalation, report generation, follow-up planning, auditability, and validation planning.

## Who Can Access It

- Patient/guardian: own patient-safe summaries and allowed patient workflow data.
- Doctor/optometrist/staff: scoped clinical data according to role and hospital/camp permissions.
- Admin: operational data according to configured role permissions.
- Technical team: limited staging/support access only as approved and logged.

## Consent Explanation

Guardian consent is required before child screening workflows. Consent should explain that the app provides screening/support only and does not provide a diagnosis or treatment plan.

## Doctor Sharing Consent

Guardian should understand that screening results may be shared with authorized eye-care professionals for review, follow-up, or referral.

## Report Export Consent

Report export should be user/clinic initiated, access controlled, and audit logged. Exported reports may contain sensitive child health data.

## Offline Data Note

The current offline flow stores minimized queued result data in browser storage until sync. It should not store raw images or raw AI class/confidence details. This local data is not currently client-side encrypted, so pilot sites should avoid shared/public devices and should clear data after supervised testing when appropriate.

## Data Deletion And Export Planning

Before controlled pilot, define:

- How guardians request data export.
- How guardians request data deletion where legally allowed.
- Retention period for screening and audit logs.
- De-identification process for validation analysis.
- Backup retention and deletion limits.

## Child Data Caution

Child health data is sensitive. Collect the minimum necessary data, restrict access, audit exports, and avoid storing unnecessary images, raw AI details, or free-text PII.

## Parent-Friendly Privacy Explanation

We collect only the information needed to guide the screening, save the result, and help an eye-care professional review it if needed. The app is not a diagnosis. Your child’s information should only be visible to you and authorized care teams. Reports and doctor actions are tracked for safety.

