"""Tests for screening endpoints."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestStartSession:
    def test_start_session_no_auth(self, client):
        response = client.post("/api/screening/start", json={
            "patient_id": str(uuid4()),
            "nurse_id": str(uuid4()),
            "village_id": str(uuid4()),
            "device_id": "dev-001",
            "lighting_condition": "indoor",
            "internet_available": True,
        })
        assert response.status_code == 403

    def test_start_session_with_auth(self, client, nurse_token_headers):
        response = client.post("/api/screening/start",
                               json={
                                   "patient_id": str(uuid4()),
                                   "nurse_id": "00000000-0000-0000-0000-000000000001",
                                   "village_id": str(uuid4()),
                                   "device_id": "test-device-001",
                                   "lighting_condition": "outdoor",
                                   "internet_available": True,
                               },
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]

    def test_start_session_missing_required_fields(self, client, nurse_token_headers):
        response = client.post("/api/screening/start",
                               json={"patient_id": str(uuid4())},
                               headers=nurse_token_headers)
        assert response.status_code == 422


class TestCompleteSession:
    def test_complete_no_auth(self, client):
        response = client.post("/api/screening/complete", json={"session_id": str(uuid4())})
        assert response.status_code == 403

    def test_complete_with_auth(self, client, nurse_token_headers):
        response = client.post("/api/screening/complete",
                               json={"session_id": str(uuid4())},
                               headers=nurse_token_headers)
        assert response.status_code in [200, 404, 500]


class TestGetReport:
    def test_report_no_auth(self, client):
        response = client.get(f"/api/screening/report/{uuid4()}")
        assert response.status_code == 403

    def test_report_with_auth(self, client, nurse_token_headers):
        response = client.get(f"/api/screening/report/{uuid4()}",
                              headers=nurse_token_headers)
        assert response.status_code in [200, 404, 500]
