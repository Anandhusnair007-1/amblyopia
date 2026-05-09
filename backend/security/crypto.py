"""
Application-level PII encryption (Fernet) and deterministic lookup hashes (HMAC-SHA256).

Env:
  PII_ENCRYPTION_KEY — urlsafe base64 32-byte Fernet key (see Fernet.generate_key()).
  PII_LOOKUP_SECRET — secret for HMAC-SHA256 lookup hashes (phone, name search).
  ENCRYPTION_KEY — optional legacy Fernet key for reading old patient documents during migration.

Production (ENV=production): both PII_ENCRYPTION_KEY and PII_LOOKUP_SECRET are required or startup fails.
Development: if PII_ENCRYPTION_KEY missing, values are stored in a dev wrapper (not confidential).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import os
from typing import Any, Dict, Optional

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger("ambyoai.crypto")

KEY_VERSION = "v1"
ALG_FERNET = "fernet-v1"
ALG_DEV_PLAIN = "dev-plaintext"


def _env() -> str:
    return os.environ.get("ENV", "development").lower()


def _fernet_from_env(key_b64: Optional[str]) -> Optional[Fernet]:
    if not key_b64 or not key_b64.strip():
        return None
    try:
        return Fernet(key_b64.strip().encode("ascii"))
    except Exception as e:
        logger.error("Invalid Fernet key: %s", e)
        return None


def get_pii_fernet() -> Optional[Fernet]:
    return _fernet_from_env(os.environ.get("PII_ENCRYPTION_KEY"))


def get_legacy_fernet() -> Optional[Fernet]:
    """Pre–P1.1 ENCRYPTION_KEY for decrypting migrated ciphertext strings."""
    return _fernet_from_env(os.environ.get("ENCRYPTION_KEY"))


def validate_pii_startup() -> None:
    """Call from FastAPI startup. Raises in production if secrets missing."""
    env = _env()
    if env == "production":
        if not os.environ.get("PII_ENCRYPTION_KEY"):
            raise RuntimeError("FATAL: PII_ENCRYPTION_KEY is required in production")
        if not os.environ.get("PII_LOOKUP_SECRET"):
            raise RuntimeError("FATAL: PII_LOOKUP_SECRET is required in production")
        if get_pii_fernet() is None:
            raise RuntimeError("FATAL: PII_ENCRYPTION_KEY is not a valid Fernet key")
        return
    if not os.environ.get("PII_ENCRYPTION_KEY"):
        logger.warning(
            "PII_ENCRYPTION_KEY not set; storing PII in reversible dev wrapper (not for production)"
        )
    if not os.environ.get("PII_LOOKUP_SECRET"):
        logger.warning(
            "PII_LOOKUP_SECRET not set; using JWT_SECRET for lookup HMAC if available, else weak dev default"
        )


def _lookup_secret() -> bytes:
    s = os.environ.get("PII_LOOKUP_SECRET") or os.environ.get("JWT_SECRET") or "dev-only-lookup-secret"
    return s.encode("utf-8")


def hash_lookup(value: str) -> str:
    """Deterministic HMAC-SHA256 hex digest for phone / normalized name lookup."""
    if value is None:
        value = ""
    msg = value.strip().encode("utf-8")
    return hmac.new(_lookup_secret(), msg, hashlib.sha256).hexdigest()


def encrypt_pii(value: Optional[str]) -> Optional[Dict[str, Any]]:
    """
    Encrypt a string field. Returns structured dict, or None for empty input.
    In development without PII_ENCRYPTION_KEY, stores dev-plaintext wrapper.
    """
    if value is None or value == "":
        return None
    f = get_pii_fernet()
    if f is None:
        return {"enc": False, "alg": ALG_DEV_PLAIN, "v": value, "key_version": "none"}
    token = f.encrypt(value.encode("utf-8"))
    ct = base64.urlsafe_b64encode(token).decode("ascii")
    return {"enc": True, "alg": ALG_FERNET, "ciphertext": ct, "key_version": KEY_VERSION}


def decrypt_pii(payload: Any) -> Optional[str]:
    """
    Decrypt structured payload, legacy Fernet string, or return plaintext string.
    """
    if payload is None:
        return None
    if isinstance(payload, dict):
        if payload.get("enc") is False:
            return payload.get("v")
        if payload.get("enc") is True and payload.get("alg") == ALG_FERNET:
            f = get_pii_fernet()
            if not f:
                logger.error("Cannot decrypt: PII_ENCRYPTION_KEY missing")
                return None
            try:
                raw = base64.urlsafe_b64decode(payload["ciphertext"].encode("ascii"))
                return f.decrypt(raw).decode("utf-8")
            except (InvalidToken, KeyError, ValueError) as e:
                logger.warning("Fernet decrypt failed: %s", e)
                return None
        return None
    if isinstance(payload, str):
        f = get_pii_fernet()
        if f:
            try:
                return f.decrypt(payload.encode("ascii")).decode("utf-8")
            except Exception:
                pass
        leg = get_legacy_fernet()
        if leg:
            try:
                return leg.decrypt(payload.encode("ascii")).decode("utf-8")
            except Exception:
                pass
        return payload
    return str(payload)


def legacy_jwt_phone_hash(phone: str, jwt_secret: str) -> str:
    """Pre-P1.1 phone_hash: sha256(f\"{JWT_SECRET}_{phone}\").hexdigest()"""
    return hashlib.sha256(f"{jwt_secret}_{phone}".encode()).hexdigest()
