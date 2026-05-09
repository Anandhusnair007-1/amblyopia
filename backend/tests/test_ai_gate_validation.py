"""
Validation tests for AI gate policy, session versioning fields.
Uses full `server.db` mock (Motor ignores setattr on collection methods).
"""
import asyncio
import os
import sys
from unittest.mock import AsyncMock

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

pytest.importorskip("motor")

from tests.db_mock_utils import mock_db_for_complete_session, mock_db_for_get_session


def test_completed_session_has_version_fields(monkeypatch):
    """complete_session writes required keys onto prediction doc and session update."""
    import server as srv

    captured_pred = {}
    captured_session_update = {}

    RESULTS = [
        {"test_name": "visual_acuity", "raw_score": 1, "normalized_score": 1, "details": {"snellen_denominator": 6}},
        {"test_name": "gaze", "raw_score": 0.1, "normalized_score": 0.1, "details": {"max_deviation_pd": 2}},
        {"test_name": "hirschberg", "raw_score": 0.1, "normalized_score": 0.1, "details": {"displacement_mm": 0.5}},
        {"test_name": "prism", "raw_score": 2, "normalized_score": 0.1, "details": {"max_prism_diopters": 2}},
        {"test_name": "titmus", "raw_score": 1, "normalized_score": 1, "details": {"passed": 3, "total": 3}},
        {"test_name": "red_reflex", "raw_score": 1, "normalized_score": 1, "details": {"classification": "normal"}},
    ]

    async def fake_insert_pred(doc):
        captured_pred.clear()
        captured_pred.update(doc)

    async def fake_update_session(query, update, *a, **kw):
        captured_session_update.update(update.get("$set", {}))

    sess = {"id": "sid1", "patient_id": "p1", "status": "in_progress", "created_at": srv.now_iso()}
    mock_db = mock_db_for_complete_session(sess, RESULTS, patient_hospital={"id": "p1", "hospital_id": None})
    mock_db.ai_predictions.insert_one = fake_insert_pred
    mock_db.test_sessions.update_one = fake_update_session
    monkeypatch.setattr(srv, "db", mock_db)
    monkeypatch.setattr(srv, "audit", AsyncMock())

    u = {"sub": "p1", "role": "patient"}
    asyncio.run(srv.complete_session("sid1", u))

    for key in (
        "app_version",
        "clinical_rule_version",
        "quality_model_version",
        "deviation_model_version",
        "dataset_version",
        "test_algorithm_version",
        "prediction_created_at",
    ):
        assert key in captured_pred, f"missing {key} in prediction doc"

    for key in (
        "app_version",
        "clinical_rule_version",
        "quality_model_version",
        "deviation_model_version",
        "dataset_version",
        "test_algorithm_version",
        "prediction_created_at",
    ):
        assert key in captured_session_update, f"missing {key} in session $set"


def test_get_session_doctor_includes_insights_key(monkeypatch):
    """Doctor GET should attach ai_deviation_insights list when present."""
    import server as srv

    pred = {"risk_level": "normal", "findings": []}
    insights = [{"id": "i1", "session_id": "s1", "deviation": {"possible_type": "ET"}}]
    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1", "status": "completed"},
        {"id": "p1", "name": "Test", "date_of_birth": "2015-01-01", "age": 10, "gender": "male"},
        pred,
        insights_rows=insights,
    )
    monkeypatch.setattr(srv, "db", mock_db)

    out = asyncio.run(srv.get_session("s1", {"sub": "d1", "role": "doctor"}))
    assert "ai_deviation_insights" in out
    assert len(out["ai_deviation_insights"]) >= 1
    assert out.get("strabismus_ai") is None  # insight rows lack strabismus `condition`


def test_get_session_patient_has_no_insights(monkeypatch):
    import server as srv

    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1"},
        {"id": "p1", "name": "Test", "date_of_birth": "2015-01-01"},
        None,
        insights_rows=None,
    )
    monkeypatch.setattr(srv, "db", mock_db)

    out = asyncio.run(srv.get_session("s1", {"sub": "p1", "role": "patient"}))
    assert out.get("ai_deviation_insights") is None
    assert out.get("strabismus_ai") is None


def test_get_session_doctor_strabismus_ai_when_condition_present(monkeypatch):
    import server as srv

    pred = {"risk_level": "normal", "findings": []}
    insights = [{
        "id": "i1",
        "session_id": "s1",
        "condition": "XT",
        "confidence": 0.94,
        "risk": "urgent",
        "all_scores": {"Normal": 0.02, "XT": 0.94, "ET": 0.02, "HT": 0.02},
        "model_version": "strabismus_v1.0.0",
        "created_at": "2026-01-01T00:00:00+00:00",
    }]
    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1", "status": "completed"},
        {"id": "p1", "name": "Test", "date_of_birth": "2015-01-01", "age": 10, "gender": "male"},
        pred,
        insights_rows=insights,
    )
    monkeypatch.setattr(srv, "db", mock_db)

    out = asyncio.run(srv.get_session("s1", {"sub": "d1", "role": "doctor"}))
    sa = out.get("strabismus_ai")
    assert sa is not None
    assert sa["condition"] == "XT"
    assert sa["confidence"] == 0.94
    assert sa["risk"] == "urgent"
    assert sa["all_scores"]["XT"] == 0.94
    assert "recommendation" in sa
    assert sa["model_version"] == "strabismus_v1.0.0"


def test_get_session_patient_strabismus_ai_patient_safe(monkeypatch):
    import server as srv

    insight = {
        "condition": "XT",
        "confidence": 0.94,
        "risk": "urgent",
        "all_scores": {"Normal": 0.02, "XT": 0.94, "ET": 0.02, "HT": 0.02},
        "model_version": "strabismus_v1.0.0",
        "created_at": "2026-01-01T00:00:00+00:00",
    }
    mock_db = mock_db_for_get_session(
        {"id": "s1", "patient_id": "p1"},
        {"id": "p1", "name": "Test", "date_of_birth": "2015-01-01"},
        None,
        insights_rows=None,
    )
    mock_db.ai_deviation_insights.find_one = AsyncMock(return_value=insight)
    monkeypatch.setattr(srv, "db", mock_db)

    out = asyncio.run(srv.get_session("s1", {"sub": "p1", "role": "patient"}))
    sa = out["strabismus_ai"]
    assert sa["risk"] == "urgent"
    assert sa["screening_complete"] is True
    assert "confidence" not in sa
    assert "condition" not in sa
