"""
TASK 3 — Test All 12 API Routers
Aravind Eye Hospital — Amblyopia Care System

Tests every registered API route. A route is considered
"active" if it returns any HTTP status that is NOT 404 or 500.
(401 Unauthorized, 422 Unprocessable are valid — route exists.)
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime

import requests
from dotenv import load_dotenv

load_dotenv()

BASE    = "http://localhost:8000"
TOKEN   = None
RESULTS = []

PROJECT = "/home/anandhu/projects/amblyopia_backend"
os.makedirs(f"{PROJECT}/logs", exist_ok=True)


# ── Helpers ───────────────────────────────────────────────────────────────────

def log(passed: bool, name: str, detail: str = "") -> None:
    icon = "PASS" if passed else "FAIL"
    msg  = f"  {icon} — {name}"
    if detail:
        msg += f"  [{detail}]"
    print(msg)
    RESULTS.append({"name": name, "passed": passed, "detail": detail})


def hdrs() -> dict:
    return {"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}


def req(method: str, path: str, **kwargs) -> requests.Response:
    return requests.request(
        method, f"{BASE}{path}",
        headers=hdrs(), timeout=8, **kwargs
    )


def active(status: int) -> bool:
    """Route is 'active' if status is not 404 or 500."""
    return status not in (404, 500)


# ── Header ────────────────────────────────────────────────────────────────────

print("================================================")
print("TASK 3 — Testing All 12 API Routers")
print("================================================")
print(f"Target: {BASE}")
print(f"Time:   {datetime.now().strftime('%Y-%m-%d %H:%M:%S IST')}")
print("")

# ┌─────────────────────────────────────────────────────────────────────────────
# │ CHECKPOINT — Backend must be running
# └─────────────────────────────────────────────────────────────────────────────
print("[ CONNECTIVITY ]")
try:
    r = requests.get(f"{BASE}/health", timeout=5)
    if r.status_code == 200:
        data = r.json()
        log(True, "FastAPI /health",
            f"v{data.get('version','?')} · {data.get('environment','?')}")
    else:
        log(False, "FastAPI /health", f"HTTP {r.status_code}")
        sys.exit(1)
except requests.ConnectionError:
    log(False, "FastAPI /health", "Connection refused")
    print("")
    print("  ERROR: Backend not running.")
    print("  Fix:   cd /home/anandhu/projects/amblyopia_backend")
    print("         bash run_local.sh")
    sys.exit(1)

# Swagger docs
try:
    r = requests.get(f"{BASE}/docs", timeout=5)
    log(r.status_code == 200, "Swagger /docs", f"HTTP {r.status_code}")
except Exception as e:
    log(False, "Swagger /docs", str(e))

# OpenAPI schema
try:
    r = requests.get(f"{BASE}/openapi.json", timeout=5)
    route_count = 0
    if r.status_code == 200:
        route_count = len(r.json().get("paths", {}))
    log(r.status_code == 200, "OpenAPI schema",
        f"{route_count} routes documented")
except Exception as e:
    log(False, "OpenAPI schema", str(e))


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 1 — Auth
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 1 — auth ]")

# Nurse login
try:
    r = req("POST", "/api/auth/nurse-login", json={
        "phone_number": "+919876543210",
        "password": "Test@123",
        "device_id": "TEST_DEVICE_001",
    })
    if r.status_code in (200, 201):
        data  = r.json().get("data", {})
        TOKEN = data.get("access_token")
        log(True, "POST /api/auth/nurse-login",
            f"Token={'received' if TOKEN else 'missing'}")
    else:
        log(active(r.status_code), "POST /api/auth/nurse-login",
            f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/auth/nurse-login", str(e)[:80])

# Nurse register
try:
    r = req("POST", "/api/auth/nurse-register", json={
        "name": "Test Nurse",
        "phone_number": "+919876543210",
        "password": "Test@123",
        "employee_id": "EMP001",
        "village_ids": [],
    })
    log(active(r.status_code), "POST /api/auth/nurse-register",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/auth/nurse-register", str(e)[:80])

# Token refresh
try:
    r = req("POST", "/api/auth/refresh-token",
            json={"refresh_token": "dummy"})
    log(active(r.status_code), "POST /api/auth/refresh-token",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/auth/refresh-token", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 2 — Village
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 2 — village ]")
VILLAGE_ID = None

try:
    r = req("POST", "/api/village/create", json={
        "name": "Test Village Coimbatore",
        "district": "Coimbatore",
        "state": "Tamil Nadu",
        "lat": 11.0168,
        "lng": 76.9558,
        "estimated_population": 500,
        "children_under_7": 45,
    })
    if r.status_code in (200, 201):
        VILLAGE_ID = r.json().get("data", {}).get("id")
    log(active(r.status_code), "POST /api/village/create",
        f"HTTP {r.status_code}" + (f" · ID={VILLAGE_ID}" if VILLAGE_ID else ""))
except Exception as e:
    log(False, "POST /api/village/create", str(e)[:80])

try:
    r = req("GET", "/api/village/list")
    log(active(r.status_code), "GET /api/village/list",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/village/list", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 3 — Patient
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 3 — patient ]")
PATIENT_ID = None

VILLAGE_REF = VILLAGE_ID or "00000000-0000-0000-0000-000000000001"

try:
    r = req("POST", "/api/patient/create", json={
        "age_group": "child",
        "village_id": VILLAGE_REF,
    })
    if r.status_code in (200, 201):
        PATIENT_ID = r.json().get("data", {}).get("id")
    log(active(r.status_code), "POST /api/patient/create",
        f"HTTP {r.status_code}" + (f" · ID={PATIENT_ID}" if PATIENT_ID else ""))
except Exception as e:
    log(False, "POST /api/patient/create", str(e)[:80])

try:
    r = req("GET", f"/api/patient/list?village_id={VILLAGE_REF}")
    log(active(r.status_code), "GET /api/patient/list",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/patient/list", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 4 — Nurse
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 4 — nurse ]")

try:
    r = req("GET", "/api/nurse/profile")
    log(active(r.status_code), "GET /api/nurse/profile",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/nurse/profile", str(e)[:80])

try:
    r = req("GET", "/api/nurse/my-villages")
    log(active(r.status_code), "GET /api/nurse/my-villages",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/nurse/my-villages", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 5 — Screening (session management)
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 5 — screening ]")
SESSION_ID = None
PATIENT_REF = PATIENT_ID or "00000000-0000-0000-0000-000000000001"

try:
    r = req("POST", "/api/screening/start", json={
        "patient_id": PATIENT_REF,
        "village_id": VILLAGE_REF,
        "device_id": "TEST_DEVICE_001",
        "gps_lat": 11.0168,
        "gps_lng": 76.9558,
        "lighting_condition": "good",
        "battery_level": 85,
        "internet_available": True,
    })
    if r.status_code in (200, 201):
        SESSION_ID = r.json().get("data", {}).get("session_id")
    log(active(r.status_code), "POST /api/screening/start",
        f"HTTP {r.status_code}" + (f" · session={SESSION_ID}" if SESSION_ID else ""))
except Exception as e:
    log(False, "POST /api/screening/start", str(e)[:80])

SESSION_REF = SESSION_ID or "00000000-0000-0000-0000-000000000001"
try:
    r = req("GET", f"/api/screening/session/{SESSION_REF}")
    log(active(r.status_code), "GET /api/screening/session/{id}",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/screening/session/{id}", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 6 — Snellen
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 6 — snellen ]")

try:
    r = req("POST", "/api/snellen/result", json={
        "session_id": SESSION_REF,
        "visual_acuity_right": "6/12",
        "visual_acuity_left": "6/9",
        "visual_acuity_both": "6/9",
        "hesitation_score": 0.3,
        "gaze_compliance_score": 0.85,
        "test_mode": "snellen",
        "confidence_score": 0.88,
    })
    log(active(r.status_code), "POST /api/snellen/result",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/snellen/result", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 7 — Gaze
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 7 — gaze ]")

try:
    r = req("POST", "/api/gaze/result", json={
        "session_id": SESSION_REF,
        "left_gaze_x": 0.45,
        "left_gaze_y": 0.50,
        "right_gaze_x": 0.62,
        "right_gaze_y": 0.50,
        "left_fixation_stability": 0.08,
        "right_fixation_stability": 0.19,
        "gaze_asymmetry_score": 0.17,
        "left_blink_ratio": 0.28,
        "right_blink_ratio": 0.31,
        "blink_asymmetry": 0.03,
        "frames_analyzed": 900,
        "confidence_score": 0.87,
        "result": "asymmetry_detected",
    })
    log(active(r.status_code), "POST /api/gaze/result",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/gaze/result", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 8 — Red-Green
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 8 — redgreen ]")

try:
    r = req("POST", "/api/redgreen/result", json={
        "session_id": SESSION_REF,
        "left_pupil_diameter": 4.2,
        "right_pupil_diameter": 5.1,
        "asymmetry_ratio": 0.19,
        "suppression_flag": True,
        "dominant_eye": "right",
        "binocular_score": 2,
        "constriction_speed_left": 180.0,
        "constriction_speed_right": 220.0,
        "confidence_score": 0.82,
    })
    log(active(r.status_code), "POST /api/redgreen/result",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/redgreen/result", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 9 — Doctor
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 9 — doctor ]")

try:
    r = req("GET", "/api/doctor/review-queue")
    log(active(r.status_code), "GET /api/doctor/review-queue",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/doctor/review-queue", str(e)[:80])

try:
    r = req("GET", "/api/doctor/pending-count")
    log(active(r.status_code), "GET /api/doctor/pending-count",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/doctor/pending-count", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 10 — Dashboard
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 10 — dashboard ]")

try:
    r = req("GET", "/api/dashboard/village-heatmap")
    log(active(r.status_code), "GET /api/dashboard/village-heatmap",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/dashboard/village-heatmap", str(e)[:80])

try:
    r = req("GET", "/api/dashboard/summary")
    log(active(r.status_code), "GET /api/dashboard/summary",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/dashboard/summary", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 11 — Sync
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 11 — sync ]")

try:
    r = req("GET", "/api/sync/pending-model-update")
    log(active(r.status_code), "GET /api/sync/pending-model-update",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/sync/pending-model-update", str(e)[:80])

try:
    r = req("POST", "/api/sync/push-offline-data",
            json={"sessions": [], "device_id": "TEST_DEVICE_001"})
    log(active(r.status_code), "POST /api/sync/push-offline-data",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/sync/push-offline-data", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ ROUTER 12 — Notifications
# └─────────────────────────────────────────────────────────────────────────────
print("")
print("[ ROUTER 12 — notifications ]")

try:
    r = req("POST", "/api/notify/doctor-alert", json={
        "session_id": SESSION_REF,
        "priority": "high",
    })
    log(active(r.status_code), "POST /api/notify/doctor-alert",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "POST /api/notify/doctor-alert", str(e)[:80])

try:
    r = req("GET", "/api/dashboard/pilot-dashboard")
    log(active(r.status_code), "GET /api/dashboard/pilot-dashboard",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/dashboard/pilot-dashboard", str(e)[:80])

try:
    r = req("GET", "/api/sync/check-model-update")
    log(active(r.status_code), "GET /api/sync/check-model-update",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/sync/check-model-update", str(e)[:80])

try:
    r = req("GET", "/api/notifications/history/test-id")
    log(active(r.status_code), "GET /api/notifications/history/test-id",
        f"HTTP {r.status_code}")
except Exception as e:
    log(False, "GET /api/notifications/history/test-id", str(e)[:80])


# ┌─────────────────────────────────────────────────────────────────────────────
# │ FINAL REPORT
# └─────────────────────────────────────────────────────────────────────────────
total  = len(RESULTS)
passed = sum(1 for r in RESULTS if r["passed"])
failed = total - passed
score  = int(passed / total * 100) if total else 0

print("")
print("================================================")
print("API TEST REPORT")
print("================================================")
for rr in RESULTS:
    icon = "PASS" if rr["passed"] else "FAIL"
    print(f"  {icon} — {rr['name']:<45} {rr['detail']}")
print("──────────────────────────────────────────────")
print(f"  PASSED:  {passed}/{total}  ({score}%)")
print(f"  FAILED:  {failed}/{total}")
print("")
if failed == 0:
    print("  STATUS:  ALL APIs WORKING ✓")
elif score >= 80:
    print("  STATUS:  MOSTLY WORKING — fix FAIL items above")
else:
    print(f"  STATUS:  {failed} APIs NEED FIXING")
print("================================================")

# Save report
report = {
    "timestamp":  datetime.now().isoformat(),
    "base_url":   BASE,
    "total":      total,
    "passed":     passed,
    "failed":     failed,
    "score_pct":  score,
    "results":    RESULTS,
}
report_path = f"{PROJECT}/logs/api_test_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)
print(f"  Report saved: {report_path}")
print("================================================")

if failed > 0:
    sys.exit(1)
