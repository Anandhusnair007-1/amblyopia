"""Pytest configuration and shared fixtures."""
from __future__ import annotations

import asyncio
import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from httpx import AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch

from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def client():
    """Sync test client for simple endpoint tests."""
    return TestClient(app)


@pytest.fixture
def mock_db():
    """Mock AsyncSession for unit tests."""
    db = AsyncMock()
    db.execute = AsyncMock()
    db.flush = AsyncMock()
    db.add = MagicMock()
    return db


@pytest.fixture
def mock_redis():
    """Mock Redis client."""
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=None)
    redis.setex = AsyncMock(return_value=True)
    redis.incr = AsyncMock(return_value=1)
    redis.expire = AsyncMock(return_value=True)
    return redis


@pytest.fixture
def nurse_token_headers():
    """JWT token headers for nurse authentication."""
    from app.utils.security import create_access_token
    token = create_access_token({
        "sub": "00000000-0000-0000-0000-000000000001",
        "role": "nurse",
        "device_id": "test-device-001",
    })
    return {
        "Authorization": f"Bearer {token}",
        "X-Device-ID": "test-device-001",
    }


@pytest.fixture
def doctor_token_headers():
    """JWT token headers for doctor authentication."""
    from app.utils.security import create_access_token
    token = create_access_token({
        "sub": "00000000-0000-0000-0000-000000000099",
        "role": "doctor",
        "device_id": "hospital-system",
    })
    return {
        "Authorization": f"Bearer {token}",
        "X-Device-ID": "hospital-system",
    }
