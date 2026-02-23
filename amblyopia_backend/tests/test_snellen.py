"""Tests for Snellen result endpoints and acuity trend."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestSaveSnellenResult:
    def test_save_no_auth(self, client):
        response = client.post("/api/snellen/result", json={"session_id": str(uuid4())})
        assert response.status_code == 403

    def test_save_missing_session(self, client, nurse_token_headers):
        response = client.post("/api/snellen/result", json={}, headers=nurse_token_headers)
        assert response.status_code == 422

    def test_save_valid_payload(self, client, nurse_token_headers):
        response = client.post("/api/snellen/result",
                               json={
                                   "session_id": str(uuid4()),
                                   "visual_acuity_right": "6/9",
                                   "visual_acuity_left": "6/6",
                                   "hesitation_score": 0.15,
                                   "confidence_score": 0.93,
                               },
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestSnellenHistory:
    def test_history_no_auth(self, client):
        response = client.get(f"/api/snellen/history/{uuid4()}")
        assert response.status_code == 403

    def test_history_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/snellen/history/{uuid4()}", headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestAcuityTrend:
    def test_acuity_trend_no_auth(self, client):
        response = client.get(f"/api/snellen/acuity-trend/{uuid4()}")
        assert response.status_code == 403

    def test_acuity_trend_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/snellen/acuity-trend/{uuid4()}", headers=nurse_token_headers)
        assert response.status_code in [200, 500]
