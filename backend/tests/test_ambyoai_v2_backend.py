"""
AmbyoAI v2 Backend Tests — Patient (OTP) + Doctor portals, clinical classifier.
"""
import os
import time
import pytest
import requests

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "https://eye-screening-ai.preview.emergentagent.com").rstrip("/")
API = f"{BASE_URL}/api"
DOCTOR_EMAIL = "doctor@aravind.in"
DOCTOR_PASS = "aravind2026"


def _phone() -> str:
    # Unique 10-digit phone per test run to avoid collision with existing patients
    return "9" + str(int(time.time() * 1000))[-9:]


@pytest.fixture(scope="session")
def s():
    sess = requests.Session()
    sess.headers.update({"Content-Type": "application/json"})
    return sess


@pytest.fixture(scope="session")
def doctor_token(s):
    r = s.post(f"{API}/auth/doctor/login", json={"email": DOCTOR_EMAIL, "password": DOCTOR_PASS})
    assert r.status_code == 200, f"Doctor login failed: {r.status_code} {r.text}"
    return r.json()["token"]


def hdr(tok): return {"Authorization": f"Bearer {tok}"}


# ── Root / Health ──────────────────────────────────────────────────────────────
class TestRoot:
    def test_root_v2_ok(self, s):
        r = s.get(f"{API}/")
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "ok"
        assert data["version"].startswith("2")
        assert data["service"] == "AmbyoAI"


# ── Patient OTP flow ───────────────────────────────────────────────────────────
class TestPatientAuth:
    def test_request_otp_valid_phone(self, s):
        r = s.post(f"{API}/auth/patient/request-otp", json={"phone": _phone()})
        assert r.status_code == 200
        d = r.json()
        assert d["ok"] is True
        assert d["demo_otp"] == "1234"

    @pytest.mark.parametrize("bad", ["abc", "123", "12345678901", "98765-4321"])
    def test_request_otp_invalid(self, s, bad):
        r = s.post(f"{API}/auth/patient/request-otp", json={"phone": bad})
        assert r.status_code == 400

    def test_verify_otp_wrong_returns_401(self, s):
        r = s.post(f"{API}/auth/patient/verify-otp", json={"phone": _phone(), "otp": "9999"})
        assert r.status_code == 401

    def test_verify_otp_new_phone_patient_pending(self, s):
        ph = _phone()
        r = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"})
        assert r.status_code == 200
        d = r.json()
        assert d["registered"] is False
        assert d["user"]["role"] == "patient_pending"
        assert "token" in d and len(d["token"]) > 10

    def test_full_register_flow_and_reverify(self, s):
        ph = _phone()
        # Verify -> patient_pending
        v1 = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"}).json()
        assert v1["registered"] is False
        pending_tok = v1["token"]
        # Register
        reg = s.post(f"{API}/patient/register", headers=hdr(pending_tok),
                     json={"name": "TEST_Patient", "date_of_birth": "2018-05-10",
                           "gender": "male", "guardian_name": "TEST_Parent", "guardian_relation": "father"})
        assert reg.status_code == 200, reg.text
        rd = reg.json()
        assert rd["user"]["role"] == "patient"
        assert rd["patient"]["name"] == "TEST_Patient"
        patient_token = rd["token"]
        patient_id = rd["user"]["id"]

        # Re-verify OTP for same phone returns registered=True
        v2 = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"}).json()
        assert v2["registered"] is True
        assert v2["user"]["role"] == "patient"
        assert v2["user"]["id"] == patient_id

        # /auth/me works
        me = s.get(f"{API}/auth/me", headers=hdr(patient_token))
        assert me.status_code == 200
        assert me.json()["role"] == "patient"

        # /patient/me returns profile + sessions
        pm = s.get(f"{API}/patient/me", headers=hdr(patient_token))
        assert pm.status_code == 200
        assert pm.json()["patient"]["id"] == patient_id
        assert isinstance(pm.json()["sessions"], list)


# ── Doctor Auth ────────────────────────────────────────────────────────────────
class TestDoctorAuth:
    def test_doctor_login_ok(self, s, doctor_token):
        assert doctor_token

    def test_doctor_login_wrong_password(self, s):
        r = s.post(f"{API}/auth/doctor/login", json={"email": DOCTOR_EMAIL, "password": "wrong"})
        assert r.status_code == 401

    def test_doctor_me(self, s, doctor_token):
        r = s.get(f"{API}/auth/me", headers=hdr(doctor_token))
        assert r.status_code == 200
        assert r.json()["role"] == "doctor"
        assert r.json()["email"] == DOCTOR_EMAIL

    def test_doctor_cannot_access_patient_me(self, s, doctor_token):
        r = s.get(f"{API}/patient/me", headers=hdr(doctor_token))
        assert r.status_code == 403


# ── Full patient journey + doctor overview ────────────────────────────────────
@pytest.fixture(scope="session")
def registered_patient(s):
    ph = _phone()
    v = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"}).json()
    reg = s.post(f"{API}/patient/register", headers=hdr(v["token"]),
                 json={"name": "TEST_Flow", "date_of_birth": "2019-01-01", "gender": "female",
                       "guardian_name": "G", "guardian_relation": "mother"}).json()
    return {"token": reg["token"], "id": reg["user"]["id"], "phone": ph}


class TestConsent:
    def test_consent_all_true(self, s, registered_patient):
        r = s.post(f"{API}/consent", headers=hdr(registered_patient["token"]),
                   json={"patient_id": registered_patient["id"],
                         "toggles": {"camera": True, "storage": True, "research": True, "doctor_share": True}})
        assert r.status_code == 200
        assert r.json()["ok"] is True

    def test_consent_one_false_400(self, s, registered_patient):
        r = s.post(f"{API}/consent", headers=hdr(registered_patient["token"]),
                   json={"patient_id": registered_patient["id"],
                         "toggles": {"camera": True, "storage": True, "research": False, "doctor_share": True}})
        assert r.status_code == 400

    def test_consent_other_patient_403(self, s, registered_patient):
        # Create a second patient
        ph2 = _phone()
        v = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph2, "otp": "1234"}).json()
        reg2 = s.post(f"{API}/patient/register", headers=hdr(v["token"]),
                      json={"name": "TEST_Other", "date_of_birth": "2020-02-02"}).json()
        other_id = reg2["user"]["id"]
        # First patient tries to save consent for second — expect 403
        r = s.post(f"{API}/consent", headers=hdr(registered_patient["token"]),
                   json={"patient_id": other_id,
                         "toggles": {"camera": True, "storage": True, "research": True, "doctor_share": True}})
        assert r.status_code == 403


@pytest.fixture(scope="session")
def urgent_session(s, registered_patient):
    tok = registered_patient["token"]
    pid = registered_patient["id"]
    # Create session without patient_id (auto-fill from token)
    sess = s.post(f"{API}/sessions", headers=hdr(tok), json={}).json()
    sid = sess["id"]
    assert sess["patient_id"] == pid
    # Submit results designed to trigger URGENT
    payloads = [
        {"test_name": "visual_acuity", "raw_score": 6/60, "normalized_score": 0.1,
         "details": {"snellen_denominator": 60}},
        {"test_name": "gaze", "raw_score": 0.9, "normalized_score": 0.9,
         "details": {"max_deviation_pd": 25}},
        {"test_name": "hirschberg", "raw_score": 0.8, "normalized_score": 0.8,
         "details": {"displacement_mm": 5}},
        {"test_name": "prism", "raw_score": 25, "normalized_score": 0.9,
         "details": {"max_prism_diopters": 25}},
        {"test_name": "titmus", "raw_score": 0, "normalized_score": 0,
         "details": {"passed": 0, "total": 3}},
        {"test_name": "red_reflex", "raw_score": 0, "normalized_score": 0,
         "details": {"classification": "leukocoria"}},
    ]
    for p in payloads:
        r = s.post(f"{API}/sessions/{sid}/results", headers=hdr(tok), json=p)
        assert r.status_code == 200, r.text
    pred = s.post(f"{API}/sessions/{sid}/complete", headers=hdr(tok)).json()
    return {"sid": sid, "pred": pred}


class TestSessionFlow:
    def test_session_complete_urgent(self, urgent_session):
        pred = urgent_session["pred"]
        assert pred["risk_level"] == "urgent"
        assert pred["risk_score"] >= 0.9
        assert isinstance(pred["findings"], list) and pred["findings"]
        # medical_findings returned in /complete response (doctor-grade payload)
        assert "medical_findings" in pred
        mf = pred["medical_findings"]
        assert any(m["test"] == "Red Reflex" and m["severity"] == "urgent" for m in mf)
        assert any(m["test"] == "Gaze Deviation" and m["severity"] == "urgent" for m in mf)
        assert any(m["test"] == "Hirschberg" and m["severity"] == "urgent" for m in mf)
        assert any(m["test"] == "Visual Acuity" and m["severity"] == "urgent" for m in mf)

    def test_patient_session_hides_medical_findings(self, s, registered_patient, urgent_session):
        r = s.get(f"{API}/sessions/{urgent_session['sid']}", headers=hdr(registered_patient["token"]))
        assert r.status_code == 200
        pred = r.json()["prediction"]
        assert pred is not None
        assert "medical_findings" not in pred
        assert "findings" in pred  # plain text findings still visible

    def test_doctor_session_includes_medical_findings(self, s, doctor_token, urgent_session):
        r = s.get(f"{API}/sessions/{urgent_session['sid']}", headers=hdr(doctor_token))
        assert r.status_code == 200
        pred = r.json()["prediction"]
        assert "medical_findings" in pred
        assert len(pred["medical_findings"]) >= 4

    def test_patient_cannot_access_other_session(self, s, urgent_session):
        # Second patient
        ph = _phone()
        v = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"}).json()
        reg = s.post(f"{API}/patient/register", headers=hdr(v["token"]),
                     json={"name": "TEST_Intruder", "date_of_birth": "2017-03-03"}).json()
        other_tok = reg["token"]
        r = s.get(f"{API}/sessions/{urgent_session['sid']}", headers=hdr(other_tok))
        assert r.status_code == 403


# ── Doctor endpoints ──────────────────────────────────────────────────────────
class TestDoctorEndpoints:
    def test_stats_doctor_only(self, s, doctor_token, urgent_session):
        r = s.get(f"{API}/doctor/stats", headers=hdr(doctor_token))
        assert r.status_code == 200
        d = r.json()
        for k in ["total_patients", "completed_sessions", "urgent_cases", "today_sessions", "pending_review"]:
            assert k in d and isinstance(d[k], int)
        assert d["urgent_cases"] >= 1
        assert d["pending_review"] >= 1

    def test_stats_requires_doctor(self, s, registered_patient):
        r = s.get(f"{API}/doctor/stats", headers=hdr(registered_patient["token"]))
        assert r.status_code == 403

    def test_patients_list(self, s, doctor_token):
        r = s.get(f"{API}/doctor/patients", headers=hdr(doctor_token))
        assert r.status_code == 200
        assert isinstance(r.json(), list)
        assert len(r.json()) >= 1

    def test_patients_filter_risk_urgent(self, s, doctor_token):
        r = s.get(f"{API}/doctor/patients", headers=hdr(doctor_token), params={"risk": "urgent"})
        assert r.status_code == 200
        rows = r.json()
        assert all(p.get("last_risk_level") == "urgent" for p in rows)
        assert len(rows) >= 1

    def test_patients_search_q(self, s, doctor_token):
        r = s.get(f"{API}/doctor/patients", headers=hdr(doctor_token), params={"q": "TEST_Flow"})
        assert r.status_code == 200
        rows = r.json()
        assert len(rows) >= 1
        assert any("TEST_Flow" in p["name"] for p in rows)

    def test_patient_detail(self, s, doctor_token, registered_patient):
        r = s.get(f"{API}/doctor/patients/{registered_patient['id']}", headers=hdr(doctor_token))
        assert r.status_code == 200
        d = r.json()
        assert d["patient"]["id"] == registered_patient["id"]
        assert isinstance(d["sessions"], list)

    def test_save_diagnosis_marks_reviewed(self, s, doctor_token, urgent_session):
        sid = urgent_session["sid"]
        r = s.post(f"{API}/doctor/diagnoses", headers=hdr(doctor_token), json={
            "session_id": sid, "diagnosis": "Suspected retinoblastoma",
            "treatment": "Immediate referral", "risk_label": "urgent",
            "follow_up_date": "2026-02-01", "referred_to": "Oncology"
        })
        assert r.status_code == 200
        assert r.json()["ok"] is True
        # Verify reviewed=true persisted
        g = s.get(f"{API}/sessions/{sid}", headers=hdr(doctor_token)).json()
        assert g["session"].get("reviewed") is True
        assert g["diagnosis"]["diagnosis"] == "Suspected retinoblastoma"


# ── Classifier — normal case ──────────────────────────────────────────────────
class TestClassifierNormal:
    def test_all_in_range_returns_normal(self, s, doctor_token):
        # New patient
        ph = _phone()
        v = s.post(f"{API}/auth/patient/verify-otp", json={"phone": ph, "otp": "1234"}).json()
        reg = s.post(f"{API}/patient/register", headers=hdr(v["token"]),
                     json={"name": "TEST_Normal", "date_of_birth": "2019-06-06"}).json()
        tok = reg["token"]
        sess = s.post(f"{API}/sessions", headers=hdr(tok), json={}).json()
        sid = sess["id"]
        normals = [
            {"test_name": "visual_acuity", "raw_score": 1.0, "normalized_score": 1.0,
             "details": {"snellen_denominator": 6}},
            {"test_name": "gaze", "raw_score": 0.02, "normalized_score": 0.02,
             "details": {"max_deviation_pd": 2}},
            {"test_name": "hirschberg", "raw_score": 0.1, "normalized_score": 0.1,
             "details": {"displacement_mm": 0.5}},
            {"test_name": "prism", "raw_score": 2, "normalized_score": 0.1,
             "details": {"max_prism_diopters": 2}},
            {"test_name": "titmus", "raw_score": 1, "normalized_score": 1,
             "details": {"passed": 3, "total": 3}},
            {"test_name": "red_reflex", "raw_score": 1, "normalized_score": 1,
             "details": {"classification": "normal"}},
        ]
        for p in normals:
            s.post(f"{API}/sessions/{sid}/results", headers=hdr(tok), json=p)
        pred = s.post(f"{API}/sessions/{sid}/complete", headers=hdr(tok)).json()
        assert pred["risk_level"] == "normal"
        assert pred["health_score"] >= 85
