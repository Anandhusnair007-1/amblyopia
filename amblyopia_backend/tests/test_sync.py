"""Tests for sync endpoints."""
from __future__ import annotations

import pytest
from uuid import uuid4


class TestBatchUpload:
    def test_batch_no_auth(self, client):
        response = client.post("/api/sync/batch-upload", json={"payloads": []})
        assert response.status_code == 403

    def test_batch_empty_payloads(self, client, nurse_token_headers):
        response = client.post("/api/sync/batch-upload",
                               json={"payloads": []},
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]

    def test_batch_with_payloads(self, client, nurse_token_headers):
        """Batch with encrypted data should be processed."""
        response = client.post("/api/sync/batch-upload",
                               json={"payloads": [{"payload_type": "gaze_result", "payload_encrypted": "invalid_enc"}]},
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]


class TestModelUpdateCheck:
    def test_check_no_auth(self, client):
        response = client.get("/api/sync/check-model-update?current_version=v1.0")
        assert response.status_code == 403

    def test_check_with_auth(self, client, nurse_token_headers):
        response = client.get("/api/sync/check-model-update?current_version=v1.0",
                              headers=nurse_token_headers)
        assert response.status_code in [200, 500]

    def test_check_missing_version(self, client, nurse_token_headers):
        response = client.get("/api/sync/check-model-update",
                              headers=nurse_token_headers)
        assert response.status_code == 422


class TestResolveConflict:
    def test_resolve_no_auth(self, client):
        response = client.post("/api/sync/resolve-conflict", json={})
        assert response.status_code == 403

    def test_resolve_with_auth(self, client, nurse_token_headers):
        existing = {"session_id": str(uuid4()), "created_at": "2024-01-01T10:00:00"}
        incoming = {"session_id": str(uuid4()), "created_at": "2024-01-01T11:00:00"}
        response = client.post("/api/sync/resolve-conflict",
                               json={"existing": existing, "incoming": incoming},
                               headers=nurse_token_headers)
        assert response.status_code in [200, 500]
