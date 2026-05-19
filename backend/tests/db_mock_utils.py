"""Build MagicMock replacements for `server.db` in unit tests (Motor ignores setattr on find_one)."""
from __future__ import annotations

from typing import Any, List, Optional
from unittest.mock import AsyncMock, MagicMock


def mock_db_for_complete_session(
    sess_doc: dict,
    result_rows: List[dict],
    patient_hospital: Optional[dict] = None,
) -> MagicMock:
    m = MagicMock()
    pid = sess_doc.get("patient_id", "p1")
    m.test_sessions.find_one = AsyncMock(return_value=sess_doc)
    base_patient = {"id": pid, "hospital_id": sess_doc.get("hospital_id", "h1"), "age": 8}
    if patient_hospital:
        base_patient.update(patient_hospital)
    m.patients.find_one = AsyncMock(return_value=base_patient)
    fc = MagicMock()
    fc.to_list = AsyncMock(return_value=result_rows)
    m.test_results.find = MagicMock(return_value=fc)
    m.ai_deviation_insights.find_one = AsyncMock(return_value=None)
    m.ai_predictions.find_one = AsyncMock(return_value=None)
    m.ai_predictions.insert_one = AsyncMock()
    m.test_sessions.update_one = AsyncMock()
    m.test_results.update_many = AsyncMock()
    m.test_results.find_one = AsyncMock(return_value=None)
    m.test_results.insert_one = AsyncMock()
    m.patients.update_one = AsyncMock()
    m.referrals.insert_one = AsyncMock()
    return m


def mock_db_for_get_session(
    sess_doc: dict,
    patient_doc: dict,
    pred: Any,
    insights_rows: Optional[list] = None,
) -> MagicMock:
    m = MagicMock()
    m.test_sessions.find_one = AsyncMock(return_value=sess_doc)
    m.patients.find_one = AsyncMock(return_value=patient_doc)
    class RC:
        def __init__(self, rows):
            self.rows = rows

        def sort(self, *a, **kw):
            return self

        async def to_list(self, n):
            return self.rows

    m.test_results.find = MagicMock(return_value=RC([]))
    m.ai_predictions.find_one = AsyncMock(return_value=pred)
    m.doctor_diagnoses.find_one = AsyncMock(return_value=None)
    rows = insights_rows or []

    class IC:
        def sort(self, *a, **kw):
            return self

        async def to_list(self, n):
            return rows

    m.ai_deviation_insights.find = MagicMock(return_value=IC())
    m.ai_deviation_insights.find_one = AsyncMock(return_value=None)
    return m
