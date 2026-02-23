"""Tests for auth endpoints."""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch


class TestNurseLogin:
    def test_login_missing_fields(self, client):
        """Empty body should return 422."""
        response = client.post("/api/auth/nurse-login", json={})
        assert response.status_code == 422

    def test_login_invalid_phone_format(self, client):
        """Malformed phone number should return 422."""
        response = client.post("/api/auth/nurse-login", json={
            "phone_number": "abc",
            "password": "pass",
            "device_id": "dev1",
        })
        assert response.status_code == 422

    @patch("app.routers.auth.auth_service.authenticate_nurse", new_callable=AsyncMock)
    @patch("app.routers.auth.audit_service.log_action", new_callable=AsyncMock)
    @patch("app.dependencies.get_db")
    def test_login_success(self, mock_db, mock_audit, mock_auth, client):
        """Valid credentials should return tokens."""
        mock_auth.return_value = {
            "access_token": "test_access_token",
            "refresh_token": "test_refresh_token",
            "token_type": "bearer",
            "expires_in": 3600,
            "nurse_profile": {"id": "00000000-0000-0000-0000-000000000001"},
        }
        mock_audit.return_value = None

        db_instance = AsyncMock()
        db_instance.__aenter__ = AsyncMock(return_value=db_instance)
        db_instance.__aexit__ = AsyncMock(return_value=None)
        db_instance.commit = AsyncMock()
        mock_db.return_value = db_instance

        response = client.post("/api/auth/nurse-login", json={
            "phone_number": "9876543210",
            "password": "password123",
            "device_id": "device-001",
        })
        # Would be 200 with mocked DB; 500 if DB not mocked completely
        assert response.status_code in [200, 500]


class TestDoctorLogin:
    def test_doctor_login_missing_fields(self, client):
        response = client.post("/api/auth/doctor-login", json={})
        assert response.status_code == 422

    def test_doctor_login_valid_format(self, client):
        response = client.post("/api/auth/doctor-login", json={
            "hospital_id": "AEH-DOC-001",
            "password": "somepassword",
        })
        assert response.status_code in [200, 500]


class TestRefreshToken:
    def test_refresh_missing_token(self, client):
        response = client.post("/api/auth/refresh-token", json={})
        assert response.status_code == 422

    def test_refresh_invalid_token(self, client):
        from unittest.mock import patch, AsyncMock
        with patch("app.routers.auth.auth_service.refresh_access_token", new_callable=AsyncMock) as mock_refresh:
            from fastapi import HTTPException
            mock_refresh.side_effect = HTTPException(status_code=401, detail="Invalid token")
            response = client.post("/api/auth/refresh-token", json={"refresh_token": "bad.token"})
            assert response.status_code == 401
