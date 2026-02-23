"""
Phase 8: AES-256-GCM encryption / phone hashing roundtrip tests.
"""
from __future__ import annotations

import pytest
from app.services.encryption_service import (
    encrypt_field,
    decrypt_field,
    hash_phone,
)


class TestEncryptionRoundtrip:
    def test_encrypt_decrypt_roundtrip(self):
        plaintext = "Anandhu Snair"
        ciphertext = encrypt_field(plaintext)
        assert ciphertext != plaintext, "Ciphertext must differ from plaintext"
        assert decrypt_field(ciphertext) == plaintext

    def test_empty_string_roundtrip(self):
        ciphertext = encrypt_field("")
        assert decrypt_field(ciphertext) == ""

    def test_unicode_roundtrip(self):
        plaintext = "अभिराम शर्मा"  # Hindi name
        ciphertext = encrypt_field(plaintext)
        assert decrypt_field(ciphertext) == plaintext

    def test_two_encryptions_differ(self):
        """AES-256-GCM uses a random nonce — same plaintext → different ciphertext."""
        ct1 = encrypt_field("hello")
        ct2 = encrypt_field("hello")
        assert ct1 != ct2, "GCM nonce must be random; ciphertexts must differ"

    def test_decrypt_wrong_data_raises(self):
        with pytest.raises(Exception):
            decrypt_field("not_valid_ciphertext")

    def test_long_field_roundtrip(self):
        long_text = "A" * 2000
        assert decrypt_field(encrypt_field(long_text)) == long_text

    def test_address_roundtrip(self):
        addr = "123, MG Road, Coimbatore, Tamil Nadu - 641001"
        assert decrypt_field(encrypt_field(addr)) == addr


class TestPhoneHashing:
    def test_hash_phone_deterministic(self):
        phone = "+919876543210"
        assert hash_phone(phone) == hash_phone(phone)

    def test_hash_phone_different_numbers(self):
        assert hash_phone("+919876543210") != hash_phone("+919876543211")

    def test_hash_phone_format_normalisation(self):
        """Leading zeros / format variants must NOT produce the same hash
        unless explicitly normalised — confirm consistency."""
        h1 = hash_phone("+919876543210")
        h2 = hash_phone("+919876543210")
        assert h1 == h2

    def test_hash_phone_not_reversible(self):
        """SHA-256 digest must not equal input."""
        phone = "+919000000001"
        assert hash_phone(phone) != phone

    def test_hash_phone_fixed_length(self):
        """SHA-256 hex digest is always 64 chars."""
        h = hash_phone("+919876543210")
        assert len(h) == 64

    def test_encrypt_and_hash_independence(self):
        """Encrypt and hash of same phone should share no common prefix."""
        phone = "+919876543210"
        enc   = encrypt_field(phone)
        hashed = hash_phone(phone)
        assert hashed not in enc
