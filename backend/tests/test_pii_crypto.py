"""PII encryption, hashing, registration shape, and audit hygiene."""
import asyncio
import os
import sys
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

os.environ.setdefault(
    "PII_ENCRYPTION_KEY",
    os.environ.get("PII_ENCRYPTION_KEY", "xv9Sz6cKC7Ic0zwJxMeabPlFG5UZ3oDqOBrbDVx12_Y="),
)
os.environ.setdefault(
    "PII_LOOKUP_SECRET",
    os.environ.get("PII_LOOKUP_SECRET", "pytest-pii-lookup-secret-min-32-characters-long!!"),
)

from security.crypto import decrypt_pii, encrypt_pii, hash_lookup


def test_encrypt_decrypt_roundtrip():
    d = encrypt_pii("Alice")
    assert isinstance(d, dict) and d.get("enc") is True
    assert decrypt_pii(d) == "Alice"


def test_same_phone_same_hash():
    assert hash_lookup("9876543210") == hash_lookup("9876543210")
    assert hash_lookup("9876543210") != hash_lookup("9876543211")


def test_audit_failed_otp_has_no_raw_phone(monkeypatch):
    pytest.importorskip("motor")
    import server as srv

    captured = []

    async def capture_audit(action, u, target_id=None, details=None):
        captured.append({"action": action, "user": dict(u), "details": dict(details or {})})

    monkeypatch.setattr(srv, "audit", capture_audit)
    monkeypatch.setattr(srv, "enforce_auth_rate_limit", AsyncMock())
    monkeypatch.setattr(srv, "DEMO_OTP", None)

    req = MagicMock()
    req.url.path = "/api/auth/patient/verify-otp"

    async def run():
        from fastapi import HTTPException

        try:
            await srv.patient_verify_otp(req, srv.OtpVerifyIn(phone="9876543210", otp="0000"))
        except HTTPException:
            pass

    asyncio.run(run())
    assert captured
    det = captured[0]["details"]
    assert "9876543210" not in str(det)
    assert "phone_hash" in det
    assert captured[0]["user"].get("sub") == "anonymous"


def test_patient_register_stores_encrypted_payloads(monkeypatch):
    pytest.importorskip("motor")
    import server as srv

    inserted = {}

    async def capture_insert(doc):
        inserted.update(doc)

    # Replace module db: MotorCollection ignores naive setattr(find_one) patches.
    monkeypatch.setattr(
        srv,
        "db",
        SimpleNamespace(
            patients=SimpleNamespace(insert_one=capture_insert),
            hospitals=SimpleNamespace(
                find_one=AsyncMock(return_value={"id": "h1", "name": "H"}),
            ),
        ),
    )
    monkeypatch.setattr(srv, "audit", AsyncMock())

    body = srv.PatientRegisterIn(
        name="Pat Child",
        date_of_birth="2018-05-10",
        gender="male",
        guardian_name="G Parent",
        guardian_relation="mother",
    )
    u = {"role": "patient_pending", "phone": "9123456789", "sub": "tmp-x"}

    asyncio.run(srv.patient_register(body, u))

    assert inserted.get("phone_hash") == hash_lookup("9123456789")
    assert _already_new(inserted.get("name"))
    assert _already_new(inserted.get("phone"))
    assert _already_new(inserted.get("date_of_birth"))
    assert inserted.get("name_search_hash") == hash_lookup("pat child")


def _already_new(blob):
    return isinstance(blob, dict) and blob.get("enc") is True


def test_find_patient_by_phone_uses_hash(monkeypatch):
    pytest.importorskip("motor")
    import server as srv

    async def fake_find(q, *a, **kw):
        if q.get("phone_hash") == hash_lookup("9999999999"):
            return {"id": "p1", "name": encrypt_pii("X"), "phone": encrypt_pii("9999999999")}
        return None

    monkeypatch.setattr(
        srv,
        "db",
        SimpleNamespace(patients=SimpleNamespace(find_one=fake_find)),
    )

    async def run():
        return await srv._find_patient_by_phone("9999999999")

    p = asyncio.run(run())
    assert p and p["id"] == "p1"
