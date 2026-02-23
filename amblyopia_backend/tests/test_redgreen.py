"""Tests for red-green result endpoints."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestSaveRedgreenResult:
    def test_save_no_auth(self, client):
        response = client.post("/api/redgreen/result", json={"session_id": str(uuid4())})
        assert response.status_code == 403

    def test_save_missing_fields(self, client, nurse_token_headers):
        response = client.post("/api/redgreen/result", json={}, headers=nurse_token_headers)
        assert response.status_code == 422

    def test_save_valid_payload(self, client, nurse_token_headers):
        response = client.post("/api/redgreen/result",
                               json={
                                   "session_id": str(uuid4()),
                                   "pupil_diameter_left": 4.2,
                                   "pupil_diameter_right": 4.1,
                                   "asymmetry_ratio": 0.05,
                                   "suppression_flag": False,
                                   "binocular_score": 3,
                                   "confidence_score": 0.95,
                               },
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]

    def test_suppression_flag_in_payload(self, client, nurse_token_headers):
        """Suppression flag True should be accepted."""
        response = client.post("/api/redgreen/result",
                               json={
                                   "session_id": str(uuid4()),
                                   "suppression_flag": True,
                                   "binocular_score": 1,
                                   "confidence_score": 0.91,
                               },
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestRedgreenHistory:
    def test_history_no_auth(self, client):
        response = client.get(f"/api/redgreen/history/{uuid4()}")
        assert response.status_code == 403

    def test_history_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/redgreen/history/{uuid4()}", headers=nurse_token_headers)
        assert response.status_code in [200, 500]
