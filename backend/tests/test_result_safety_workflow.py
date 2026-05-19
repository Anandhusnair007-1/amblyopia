import asyncio
import os
import sys
import types
import importlib.util
from unittest.mock import AsyncMock, MagicMock

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

os.environ.setdefault("MONGO_URL", "mongodb://unit-test")
os.environ.setdefault("DB_NAME", "unit_test")
os.environ.setdefault("JWT_SECRET", "unit-test-secret")

if importlib.util.find_spec("motor") is None:
    motor_mod = types.ModuleType("motor")
    motor_asyncio_mod = types.ModuleType("motor.motor_asyncio")
    motor_asyncio_mod.AsyncIOMotorClient = MagicMock()
    sys.modules["motor"] = motor_mod
    sys.modules["motor.motor_asyncio"] = motor_asyncio_mod

from tests.db_mock_utils import mock_db_for_get_session


def test_add_result_rejects_age_inappropriate_test(monkeypatch):
    import server as srv

    m = MagicMock()
    m.test_sessions.find_one = AsyncMock(return_value={"id": "s1", "patient_id": "p1"})
    m.patients.find_one = AsyncMock(return_value={"id": "p1", "age": 0, "hospital_id": None})
    monkeypatch.setattr(srv, "db", m)

    body = srv.TestResultIn(test_name="titmus", raw_score=1, normalized_score=1, details={})
    with pytest.raises(srv.HTTPException) as exc:
        asyncio.run(srv.add_result("s1", body, {"sub": "p1", "role": "patient"}))
    assert exc.value.status_code == 400


def test_add_result_preserves_revision_history(monkeypatch):
    import server as srv

    inserted = {}
    m = MagicMock()
    m.test_sessions.find_one = AsyncMock(return_value={"id": "s1", "patient_id": "p1"})
    m.patients.find_one = AsyncMock(return_value={"id": "p1", "age": 8, "hospital_id": None})
    m.test_results.find_one = AsyncMock(return_value={"id": "old1", "revision": 1})
    m.test_results.update_many = AsyncMock()

    async def capture_insert(doc):
        inserted.update(doc)

    m.test_results.insert_one = capture_insert
    monkeypatch.setattr(srv, "db", m)
    monkeypatch.setattr(srv, "audit", AsyncMock())

    body = srv.TestResultIn(
        test_name="visual_acuity",
        raw_score=12,
        normalized_score=0.5,
        details={"measurement_valid": True, "test_status": "completed"},
        calibration_info={"px_per_mm": 4},
        device_info={"device_pixel_ratio": 2},
    )
    out = asyncio.run(srv.add_result("s1", body, {"sub": "p1", "role": "patient"}))
    assert out["ok"] is True
    assert inserted["revision"] == 2
    assert inserted["supersedes_result_id"] == "old1"
    assert inserted["is_latest"] is True
    assert inserted["age_at_test"] == 8
    assert inserted["calibration_info"]["px_per_mm"] == 4


def test_patching_log_requires_doctor_plan(monkeypatch):
    import server as srv

    m = MagicMock()
    m.patching_plans.find_one = AsyncMock(return_value=None)
    monkeypatch.setattr(srv, "db", m)

    body = srv.PatchingLogIn(plan_id="missing", status="completed", minutes_completed=30)
    with pytest.raises(srv.HTTPException) as exc:
        asyncio.run(srv.patient_patching_log(body, {"sub": "p1", "role": "patient"}))
    assert exc.value.status_code == 403


def test_patient_cannot_access_other_patient_session(monkeypatch):
    import server as srv

    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p-owner", "status": "completed"},
        {"id": "p-owner", "name": "N", "date_of_birth": "2015-01-01"},
        {"risk_level": "normal", "findings": []},
    )
    monkeypatch.setattr(srv, "db", mock_db)
    with pytest.raises(srv.HTTPException) as exc:
        asyncio.run(srv.get_session("s1", {"sub": "p-other", "role": "patient"}))
    assert exc.value.status_code == 403


def test_doctor_session_access_is_hospital_scoped(monkeypatch):
    import server as srv

    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1", "status": "completed", "hospital_id": "h2"},
        {"id": "p1", "name": "N", "date_of_birth": "2015-01-01", "hospital_id": "h2"},
        {"risk_level": "normal", "findings": []},
    )
    monkeypatch.setattr(srv, "db", mock_db)
    with pytest.raises(srv.HTTPException) as exc:
        asyncio.run(srv.get_session("s1", {"sub": "d1", "role": "doctor", "hospital_id": "h1"}))
    assert exc.value.status_code == 403


def test_report_export_audit_created(monkeypatch):
    import server as srv

    m = MagicMock()
    m.test_sessions.find_one = AsyncMock(return_value={"id": "s1", "patient_id": "p1", "hospital_id": "h1"})
    audit = AsyncMock()
    monkeypatch.setattr(srv, "db", m)
    monkeypatch.setattr(srv, "audit", audit)

    body = srv.ExportAuditIn(export_type="medical_pdf")
    out = asyncio.run(srv.audit_session_export("s1", body, {"sub": "d1", "role": "doctor", "hospital_id": "h1"}))
    assert out["ok"] is True
    assert audit.await_count == 1
    assert audit.await_args.args[0] == "session.export"


def test_version_endpoint_exposes_clinical_demo_metadata():
    import server as srv

    out = asyncio.run(srv.version())
    assert out["release_name"] == "amblyopia-screening-v0.1-clinical-demo"
    assert out["clinical_rule_version"] == srv.CLINICAL_RULE_VERSION
    assert out["calibration_version"] == "screen-calibration-v1"
    assert "screening/support only" in out["safety_positioning"]
