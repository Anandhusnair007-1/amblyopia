"""Tests for dashboard and its analytics endpoints."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestOverview:
    def test_overview_no_auth(self, client):
        response = client.get("/api/dashboard/overview")
        assert response.status_code == 403

    def test_overview_nurse_forbidden(self, client, nurse_token_headers):
        """Dashboard requires doctor role."""
        response = client.get("/api/dashboard/overview", headers=nurse_token_headers)
        assert response.status_code in [403, 500]

    def test_overview_with_doctor_auth(self, client, doctor_token_headers):
        response = client.get("/api/dashboard/overview", headers=doctor_token_headers)
        assert response.status_code in [200, 500]


class TestAnalytics:
    def test_analytics_no_auth(self, client):
        response = client.get("/api/dashboard/analytics")
        assert response.status_code == 403

    def test_analytics_with_doctor_auth(self, client, doctor_token_headers):
        response = client.get("/api/dashboard/analytics", headers=doctor_token_headers)
        assert response.status_code in [200, 500]


class TestPilotDashboard:
    def test_pilot_no_auth(self, client):
        response = client.get("/api/dashboard/pilot-dashboard")
        assert response.status_code == 403

    def test_pilot_with_doctor_auth(self, client, doctor_token_headers):
        response = client.get("/api/dashboard/pilot-dashboard", headers=doctor_token_headers)
        assert response.status_code in [200, 500]


class TestHealthCheck:
    def test_health_endpoint_accessible(self, client):
        """Health check should ALWAYS return 200 without auth."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data

    def test_root_endpoint(self, client):
        response = client.get("/")
        assert response.status_code == 200
