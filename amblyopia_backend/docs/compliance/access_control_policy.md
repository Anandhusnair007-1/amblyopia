# Access Control Policy — Amblyopia Care System

**Document ID:** DPDP-ACP-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Platform Engineering  
**Review Frequency:** Annually or on role change  

---

## 1. Purpose

Define role-based access control (RBAC) for the Amblyopia Care System to enforce the principle of least privilege and comply with DPDP Act 2023 Section 5 (purpose limitation).

---

## 2. Roles

| Role    | Description                                        | Assigned To               |
|---------|----------------------------------------------------|---------------------------|
| patient | Patient / guardian self-service access             | Registered patients       |
| nurse   | Screening data collection at camp                  | Field nurses / workers    |
| doctor  | Diagnostic review and report generation            | Qualified ophthalmologists|
| admin   | System administration, user management             | Platform admins only      |

---

## 3. Permission Matrix

| Resource / Action                               | patient | nurse | doctor | admin |
|-------------------------------------------------|:-------:|:-----:|:------:|:-----:|
| **Auth**                                        |         |       |        |       |
| Register account                                | ✅      | ✅    | ✅     | ✅    |
| Login / refresh token                           | ✅      | ✅    | ✅     | ✅    |
| **Patient records**                             |         |       |        |       |
| View own record                                 | ✅      | ❌    | ❌     | ✅    |
| View records in assigned village                | ❌      | ✅    | ❌     | ✅    |
| View all records                                | ❌      | ❌    | ✅     | ✅    |
| Create / update patient record                  | ❌      | ✅    | ❌     | ✅    |
| Delete patient record                           | ❌      | ❌    | ❌     | ✅    |
| **Screening**                                   |         |       |        |       |
| Create screening session                        | ❌      | ✅    | ❌     | ✅    |
| Upload images / voice recordings                | ❌      | ✅    | ❌     | ✅    |
| View own screening results                      | ✅      | ❌    | ❌     | ✅    |
| View all screening results                      | ❌      | ❌    | ✅     | ✅    |
| **Gaze / Vision tests**                         |         |       |        |       |
| Submit gaze test                                | ❌      | ✅    | ❌     | ✅    |
| Submit Snellen test                             | ❌      | ✅    | ❌     | ✅    |
| Submit Red-Green test                           | ❌      | ✅    | ❌     | ✅    |
| **Dashboard / Reporting**                       |         |       |        |       |
| View doctor dashboard                           | ❌      | ❌    | ✅     | ✅    |
| Generate PDF reports                            | ❌      | ❌    | ✅     | ✅    |
| **Notifications**                               |         |       |        |       |
| View own notifications                          | ✅      | ✅    | ✅     | ✅    |
| Send system notifications                       | ❌      | ❌    | ✅     | ✅    |
| **Administration**                              |         |       |        |       |
| Create / deactivate users                       | ❌      | ❌    | ❌     | ✅    |
| View audit logs                                 | ❌      | ❌    | ❌     | ✅    |
| Manage villages                                 | ❌      | ❌    | ❌     | ✅    |
| Control panel access                            | ❌      | ❌    | ❌     | ✅    |

---

## 4. Enforcement

All permissions are enforced via FastAPI dependency injection:

```python
# Example — doctor-only endpoint
@router.get("/dashboard")
async def doctor_dashboard(
    current_user: User = Depends(require_role("doctor", "admin"))
):
    ...
```

Role checks are applied at the **router level** — no business-logic bypass possible.

---

## 5. Account Management

| Process                     | Requirement                                           |
|-----------------------------|-------------------------------------------------------|
| Account creation            | Admin-initiated or self-registration (patient only)   |
| Account deactivation        | Admin action; user cannot self-delete                 |
| Privilege escalation        | Requires admin approval + audit log entry             |
| Leavers (staff offboarding) | Account deactivated within 24h of departure           |
| Annual access review        | Admin reviews all nurse/doctor/admin accounts         |

---

## 6. Session Policy

| Parameter          | Value                                |
|--------------------|--------------------------------------|
| JWT access token   | 24-hour TTL                          |
| JWT refresh token  | 7-day TTL                            |
| Idle timeout       | No client-side timeout in v1.0 (roadmap: 30 min) |
| Token revocation   | Immediate via Redis revocation list  |
| Concurrent sessions| Unlimited (single-device preferred)  |

---

## 7. Shared / Service Accounts

No shared accounts are permitted. All ML pipeline and service-to-service calls use dedicated service principals with scoped permissions.
