"""P1.2 hospital admin, roles, referrals, and RBAC — unit tests with full `db` mock."""
import asyncio
import os
import sys

import pytest
from fastapi import HTTPException

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

pytest.importorskip("motor")

from tests.db_mock_utils import mock_db_for_complete_session, mock_db_for_get_session


def test_urgent_session_creates_referral(monkeypatch):
    import server as srv
    from unittest.mock import AsyncMock

    RESULTS = [
        {
            "test_name": "red_reflex",
            "raw_score": 1,
            "normalized_score": 1,
            "details": {"classification": "leukocoria"},
        },
    ]
    sess_doc = {
        "id": "sid1",
        "patient_id": "p1",
        "status": "in_progress",
        "hospital_id": "h1",
        "camp_id": "c1",
        "created_at": srv.now_iso(),
    }
    mock_db = mock_db_for_complete_session(sess_doc, RESULTS)
    ref = mock_db.referrals.insert_one
    monkeypatch.setattr(srv, "db", mock_db)
    monkeypatch.setattr(srv, "audit", AsyncMock())

    u = {"sub": "d1", "role": "doctor", "hospital_id": "h1"}
    asyncio.run(srv.complete_session("sid1", u))
    assert ref.await_count == 1
    doc = ref.await_args.args[0]
    assert doc["urgency"] == "urgent"
    assert doc["status"] == "new"
    assert doc["doctor_review_required"] is True
    assert doc.get("sla_due_at")
    assert doc.get("contact_attempts") == []


def test_field_worker_session_strips_medical_findings(monkeypatch):
    import server as srv
    from unittest.mock import AsyncMock

    pred = {
        "risk_level": "high",
        "findings": ["a"],
        "medical_findings": [{"test": "Red Reflex", "severity": "urgent"}],
    }
    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1", "status": "completed"},
        {"id": "p1", "name": "N", "date_of_birth": "2015-01-01"},
        pred,
        insights_rows=None,
    )
    monkeypatch.setattr(srv, "db", mock_db)

    out = asyncio.run(srv.get_session("s1", {"sub": "fw", "role": "field_worker"}))
    assert out.get("prediction", {}).get("medical_findings") is None


def test_doctor_cannot_create_hospital(monkeypatch):
    import server as srv
    from unittest.mock import AsyncMock, MagicMock

    monkeypatch.setattr(srv, "db", MagicMock())
    monkeypatch.setattr(srv, "audit", AsyncMock())
    body = srv.HospitalExtendedIn(name="X", location="Y", status="active")
    u = {"sub": "doc1", "role": "doctor", "hospital_id": "h1", "name": "D", "email": "d@x.in"}

    with pytest.raises(HTTPException) as ei:
        asyncio.run(srv.create_hospital(body, u))
    assert ei.value.status_code == 403


def test_super_admin_can_create_hospital(monkeypatch):
    import server as srv
    from unittest.mock import AsyncMock, MagicMock

    mock_db = MagicMock()
    mock_db.hospitals.insert_one = AsyncMock()
    monkeypatch.setattr(srv, "db", mock_db)
    monkeypatch.setattr(srv, "audit", AsyncMock())
    body = srv.HospitalExtendedIn(name="New H", location="Loc", status="active")
    u = {"sub": "sa1", "role": "super_admin", "name": "SA", "email": "sa@x.in"}
    asyncio.run(srv.create_hospital(body, u))
    assert mock_db.hospitals.insert_one.await_count == 1


def test_hospital_admin_can_create_camp(monkeypatch):
    import server as srv
    from unittest.mock import AsyncMock, MagicMock

    mock_db = MagicMock()
    mock_db.hospitals.find_one = AsyncMock(return_value={"id": "h1", "name": "Hosp"})
    mock_db.camps.insert_one = AsyncMock()
    monkeypatch.setattr(srv, "db", mock_db)
    monkeypatch.setattr(srv, "audit", AsyncMock())
    body = srv.CampIn(
        hospital_id="h1",
        name="Camp A",
        location="Field",
        start_date="2026-06-01",
        end_date="2026-06-02",
    )
    u = {"sub": "a1", "role": "hospital_admin", "hospital_id": "h1", "name": "A", "email": "a@x.in"}
    asyncio.run(srv.create_camp(body, u))
    assert mock_db.camps.insert_one.await_count == 1


def test_patient_cannot_list_admin_camps(monkeypatch):
    import server as srv
    from unittest.mock import MagicMock

    monkeypatch.setattr(srv, "db", MagicMock())
    u = {"sub": "p1", "role": "patient", "name": "P", "phone": "9123456789"}

    with pytest.raises(HTTPException) as ei:
        asyncio.run(srv.list_camps(None, u))
    assert ei.value.status_code == 403


def test_field_worker_cannot_post_diagnosis(monkeypatch):
    import server as srv
    from unittest.mock import MagicMock

    monkeypatch.setattr(srv, "db", MagicMock())
    body = srv.DiagnosisIn(
        session_id="s1",
        diagnosis="x",
        confirmed_by_doctor=True,
        ai_agreement="not_reviewed",
    )
    u = {"sub": "fw1", "role": "field_worker", "hospital_id": "h1", "name": "FW", "email": "fw@x.in"}

    with pytest.raises(HTTPException) as ei:
        asyncio.run(srv.save_diagnosis(body, u))
    assert ei.value.status_code == 403
