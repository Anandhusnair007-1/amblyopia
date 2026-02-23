"""
Amblyopia Care System — Encryption Service
AES-256-GCM encryption for all sensitive stored fields.
DPDP Act 2023 compliant — no plaintext PII in database.
"""
from __future__ import annotations

import base64
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.config import settings

# 12-byte nonce for AES-GCM (standard)
NONCE_SIZE = 12
SEPARATOR = b"|"


def _get_key() -> bytes:
    """Derive a 32-byte AES-256 key from the configured encryption key."""
    raw = settings.encryption_key
    # If base64-encoded, decode it; otherwise use SHA-256 to get 32 bytes
    try:
        key = base64.b64decode(raw)
        if len(key) == 32:
            return key
    except Exception:
        pass
    return hashlib.sha256(raw.encode()).digest()


def encrypt(plaintext: str) -> str:
    """
    Encrypt plaintext using AES-256-GCM.
    Returns a base64url-encoded string: nonce + ciphertext + tag.
    """
    if not plaintext:
        return plaintext

    key = _get_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(NONCE_SIZE)

    ciphertext_tag = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)

    # Concatenate nonce + ciphertext_tag and base64-encode
    raw = nonce + ciphertext_tag
    return base64.urlsafe_b64encode(raw).decode("ascii")


def decrypt(ciphertext: str) -> str:
    """
    Decrypt an AES-256-GCM encrypted string.
    Raises ValueError on failure.
    """
    if not ciphertext:
        return ciphertext

    key = _get_key()
    aesgcm = AESGCM(key)

    raw = base64.urlsafe_b64decode(ciphertext.encode("ascii"))
    nonce = raw[:NONCE_SIZE]
    ciphertext_tag = raw[NONCE_SIZE:]

    plaintext_bytes = aesgcm.decrypt(nonce, ciphertext_tag, None)
    return plaintext_bytes.decode("utf-8")


def hash_phone(phone_number: str) -> str:
    """
    SHA-256 hash a phone number for deterministic lookup
    without storing the raw number.
    """
    normalized = phone_number.strip().replace(" ", "").replace("+91", "")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def encrypt_if_not_none(value: str | None) -> str | None:
    """Encrypt a value only if it is not None."""
    if value is None:
        return None
    return encrypt(value)


def decrypt_if_not_none(value: str | None) -> str | None:
    """Decrypt a value only if it is not None."""
    if value is None:
        return None
    return decrypt(value)
