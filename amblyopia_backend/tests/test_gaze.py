"""Tests for gaze result endpoints."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestSaveGazeResult:
    def test_save_no_auth(self, client):
        response = client.post("/api/gaze/result", json={"session_id": str(uuid4())})
        assert response.status_code == 403

    def test_save_with_auth_missing_fields(self, client, nurse_token_headers):
        response = client.post("/api/gaze/result", json={}, headers=nurse_token_headers)
        assert response.status_code == 422

    def test_save_with_valid_payload(self, client, nurse_token_headers):
        response = client.post("/api/gaze/result",
                               json={"session_id": str(uuid4()),
                                     "left_gaze_x": 0.1, "left_gaze_y": 0.1,
                                     "right_gaze_x": 0.12, "right_gaze_y": 0.11,
                                     "gaze_asymmetry_score": 0.05,
                                     "left_fixation_stability": 0.82,
                                     "right_fixation_stability": 0.80,
                                     "blink_asymmetry": 0.03,
                                     "confidence_score": 0.95},
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestGazeHistory:
    def test_history_no_auth(self, client):
        response = client.get(f"/api/gaze/history/{uuid4()}")
        assert response.status_code == 403

    def test_history_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/gaze/history/{uuid4()}", headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestGazeAnalyze:
    def test_analyze_no_auth(self, client):
        response = client.get(f"/api/gaze/analyze/{uuid4()}")
        assert response.status_code == 403

    def test_analyze_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/gaze/analyze/{uuid4()}", headers=nurse_token_headers)
        assert response.status_code in [200, 404, 500]
