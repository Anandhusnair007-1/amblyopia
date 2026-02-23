"""
Phase 8: Brute-force rate limiting on nurse login.
Tests login_rate_limit() from app.dependencies.
"""
from __future__ import annotations

import hashlib
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException


def _make_request_mock(ip: str = "1.2.3.4") -> MagicMock:
    req = MagicMock()
    req.client = MagicMock()
    req.client.host = ip
    req.state = MagicMock()
    req.state.request_id = "test-req-id"
    return req


class TestBruteForceRateLimit:
    @pytest.mark.asyncio
    async def test_first_attempt_allowed(self):
        from app.dependencies import login_rate_limit

        mock_redis = AsyncMock()
        mock_redis.incr   = AsyncMock(return_value=1)
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        # Should NOT raise
        await login_rate_limit("+919876543210", req, mock_redis)

    @pytest.mark.asyncio
    async def test_ninth_attempt_allowed(self):
        from app.dependencies import login_rate_limit

        mock_redis = AsyncMock()
        mock_redis.incr   = AsyncMock(return_value=9)
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        await login_rate_limit("+919876543210", req, mock_redis)   # should not raise

    @pytest.mark.asyncio
    async def test_tenth_attempt_raises_429(self):
        from app.dependencies import login_rate_limit

        mock_redis = AsyncMock()
        mock_redis.incr   = AsyncMock(return_value=10)
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        with pytest.raises(HTTPException) as exc_info:
            await login_rate_limit("+919876543210", req, mock_redis)
        assert exc_info.value.status_code == 429

    @pytest.mark.asyncio
    async def test_eleventh_attempt_raises_429(self):
        from app.dependencies import login_rate_limit

        mock_redis = AsyncMock()
        mock_redis.incr   = AsyncMock(return_value=11)
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        with pytest.raises(HTTPException) as exc_info:
            await login_rate_limit("+919876543210", req, mock_redis)
        assert exc_info.value.status_code == 429

    @pytest.mark.asyncio
    async def test_rate_limit_key_uses_phone_hash(self):
        """Redis key must hash the phone number (not store plaintext)."""
        from app.dependencies import login_rate_limit

        phone = "+919876543210"
        phone_hash = hashlib.sha256(phone.encode()).hexdigest()

        seen_keys = []
        mock_redis = AsyncMock()

        async def track_incr(key):
            seen_keys.append(key)
            return 1

        mock_redis.incr   = track_incr
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        await login_rate_limit(phone, req, mock_redis)

        assert any(phone_hash in k for k in seen_keys), (
            f"Phone hash not found in Redis keys: {seen_keys}"
        )
        # Plaintext phone must NOT appear in any key
        assert not any(phone in k for k in seen_keys), (
            f"Plaintext phone leaked into Redis key: {seen_keys}"
        )

    @pytest.mark.asyncio
    async def test_clear_login_attempts_deletes_key(self):
        from app.dependencies import clear_login_attempts

        phone = "+919876543210"
        phone_hash = hashlib.sha256(phone.encode()).hexdigest()

        deleted_keys = []
        mock_redis = AsyncMock()

        async def track_delete(key):
            deleted_keys.append(key)
            return 1

        mock_redis.delete = track_delete
        await clear_login_attempts(phone, mock_redis)

        assert any(phone_hash in k for k in deleted_keys), (
            f"clear_login_attempts did not delete the rate-limit key: {deleted_keys}"
        )

    @pytest.mark.asyncio
    async def test_different_phones_have_separate_counters(self):
        from app.dependencies import login_rate_limit

        incr_calls = []
        mock_redis = AsyncMock()

        async def track_incr(key):
            incr_calls.append(key)
            return 1

        mock_redis.incr   = track_incr
        mock_redis.expire = AsyncMock(return_value=True)

        req = _make_request_mock()
        await login_rate_limit("+919876543210", req, mock_redis)
        await login_rate_limit("+919876543211", req, mock_redis)

        assert len(set(incr_calls)) == 2, "Different phones must use different keys"
