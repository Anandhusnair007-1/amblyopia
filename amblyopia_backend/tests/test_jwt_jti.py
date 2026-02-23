"""
Phase 8: JWT JTI (unique token ID) — presence, blacklisting, refresh rotation.
"""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from jose import jwt

from app.utils.security import (
    create_access_token,
    create_refresh_token,
    get_jti,
    SECRET_KEY,
    ALGORITHM,
)


class TestJTIPresence:
    def test_access_token_has_jti(self):
        token = create_access_token({"sub": "user-1", "role": "nurse"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert "jti" in payload, "Access token must contain 'jti' claim"

    def test_refresh_token_has_jti(self):
        token = create_refresh_token({"sub": "user-1", "role": "nurse"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert "jti" in payload, "Refresh token must contain 'jti' claim"

    def test_jti_is_uuid_format(self):
        import re
        UUID_RE = re.compile(
            r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
            re.IGNORECASE,
        )
        token = create_access_token({"sub": "user-1", "role": "nurse"})
        jti = get_jti(token)
        assert UUID_RE.match(jti), f"JTI is not a v4 UUID: {jti}"

    def test_two_tokens_have_different_jtis(self):
        t1 = create_access_token({"sub": "user-1", "role": "nurse"})
        t2 = create_access_token({"sub": "user-1", "role": "nurse"})
        assert get_jti(t1) != get_jti(t2)

    def test_access_token_has_iat(self):
        token = create_access_token({"sub": "user-1", "role": "nurse"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert "iat" in payload

    def test_get_jti_returns_correct_value(self):
        token = create_access_token({"sub": "user-1", "role": "nurse"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert get_jti(token) == payload["jti"]


class TestTokenBlacklist:
    @pytest.mark.asyncio
    async def test_logout_blacklists_jti(self):
        """logout() should store jti_blacklist:{jti} = '1' in Redis."""
        mock_redis = AsyncMock()
        mock_redis.setex = AsyncMock(return_value=True)

        access_token  = create_access_token({"sub": "u-1", "role": "nurse"})
        refresh_token = create_refresh_token({"sub": "u-1", "role": "nurse"})
        jti = get_jti(access_token)

        from app.services.auth_service import logout

        mock_db = AsyncMock()
        await logout(access_token, refresh_token, mock_redis, mock_db)

        # At least one setex call must reference the jti
        calls_str = str(mock_redis.setex.call_args_list)
        assert "jti_blacklist" in calls_str or jti in calls_str

    @pytest.mark.asyncio
    async def test_refresh_rotation_invalidates_old_jti(self):
        """refresh_access_token should delete the old JTI from Redis."""
        old_refresh = create_refresh_token({"sub": "u-2", "role": "nurse"})
        old_jti     = get_jti(old_refresh)

        mock_redis = AsyncMock()
        mock_redis.get    = AsyncMock(return_value=b"1")   # old JTI is registered
        mock_redis.delete = AsyncMock(return_value=1)
        mock_redis.setex  = AsyncMock(return_value=True)

        mock_db = AsyncMock()
        # Simulate nurse DB lookup
        mock_nurse = MagicMock()
        mock_nurse.id     = "u-2"
        mock_nurse.role   = "nurse"
        mock_db.execute   = AsyncMock(return_value=MagicMock(
            scalar_one_or_none=MagicMock(return_value=mock_nurse)
        ))

        from app.services.auth_service import refresh_access_token
        result = await refresh_access_token(old_refresh, mock_redis, mock_db)

        # Old JTI must have been deleted
        delete_calls_str = str(mock_redis.delete.call_args_list)
        assert old_jti in delete_calls_str or "rt_jti" in delete_calls_str

        # New tokens must be returned
        assert result is not None
        assert "access_token" in result
        assert "refresh_token" in result
