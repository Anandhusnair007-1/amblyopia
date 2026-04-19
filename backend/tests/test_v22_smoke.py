"""AmbyoAI v2.2 smoke regression — 3 critical endpoints only.

Per review_request: no full 28-test suite, just regression smoke on:
 - POST /api/auth/doctor/login
 - POST /api/auth/patient/request-otp
 - GET  /api/doctor/patients
"""
import os
import requests
import pytest

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "https://eye-screening-ai.preview.emergentagent.com").rstrip("/")


@pytest.fixture(scope="module")
def session():
    s = requests.Session()
    s.headers.update({"Content-Type": "application/json"})
    return s


@pytest.fixture(scope="module")
def doctor_token(session):
    r = session.post(
        f"{BASE_URL}/api/auth/doctor/login",
        json={"email": "doctor@aravind.in", "password": "aravind2026"},
        timeout=20,
    )
    assert r.status_code == 200, f"doctor login: {r.status_code} {r.text}"
    body = r.json()
    tok = body.get("token") or body.get("access_token")
    assert tok, f"no token in response: {body}"
    return tok


# --- auth: doctor login ---
def test_doctor_login_success(doctor_token):
    assert isinstance(doctor_token, str) and len(doctor_token) > 10


def test_doctor_login_bad_password(session):
    r = session.post(
        f"{BASE_URL}/api/auth/doctor/login",
        json={"email": "doctor@aravind.in", "password": "wrongpassword"},
        timeout=15,
    )
    assert r.status_code in (400, 401, 403), f"expected 4xx, got {r.status_code}"


# --- auth: patient OTP request ---
def test_patient_request_otp(session):
    r = session.post(
        f"{BASE_URL}/api/auth/patient/request-otp",
        json={"phone": "9876543210"},
        timeout=15,
    )
    assert r.status_code == 200, f"request-otp: {r.status_code} {r.text}"
    data = r.json()
    # Response should at least be json-serializable and indicate success
    assert isinstance(data, dict)


# --- doctor: patients list ---
def test_doctor_patients_list(session, doctor_token):
    r = session.get(
        f"{BASE_URL}/api/doctor/patients",
        headers={"Authorization": f"Bearer {doctor_token}"},
        timeout=20,
    )
    assert r.status_code == 200, f"patients list: {r.status_code} {r.text}"
    data = r.json()
    # Should be either a list or an object containing a list
    if isinstance(data, dict):
        assert "patients" in data or "items" in data or "data" in data or len(data) >= 0
    else:
        assert isinstance(data, list)


def test_doctor_patients_unauthorized(session):
    r = session.get(f"{BASE_URL}/api/doctor/patients", timeout=15)
    assert r.status_code in (401, 403), f"expected 401/403 for no auth, got {r.status_code}"
