"""
Amblyopia Care System — Database Module
Async SQLAlchemy engine + session factory using asyncpg.
"""
from __future__ import annotations

import asyncio
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


# ── Async Engine ────────────────────────────────────────────────────────────
def create_engine_instance():
    return create_async_engine(
        settings.database_url,
        echo=settings.debug,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
        pool_recycle=3600,
        connect_args={
            "server_settings": {
                "application_name": "amblyopia_care_system",
                "timezone": "Asia/Kolkata",
            }
        },
    )

# ── Session Factory ─────────────────────────────────────────────────────────
def create_session_factory(engine_instance):
    return async_sessionmaker(
        bind=engine_instance,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
        autocommit=False,
    )

# Global instances (initialized on first use)
_engine = None
_session_factory = None
_last_loop = None

def get_engine():
    global _engine, _last_loop
    try:
        current_loop = asyncio.get_running_loop()
    except RuntimeError:
        current_loop = None

    if _engine is None or _last_loop != current_loop:
        if _engine is not None:
            # We can't easily await dispose here as it's not async,
            # but SQLAlchemy handles closure of underlying pool.
            pass
        _engine = create_engine_instance()
        _last_loop = current_loop
    return _engine

def get_session_local():
    global _session_factory, _last_loop
    try:
        current_loop = asyncio.get_running_loop()
    except RuntimeError:
        current_loop = None

    if _session_factory is None or _last_loop != current_loop:
        _session_factory = create_session_factory(get_engine())
    return _session_factory

# Mock definitions for modules that import these at top level
engine = None  # Will be initialized on first use via getter
AsyncSessionLocal = None 

# ── Base Model ──────────────────────────────────────────────────────────────
class Base(DeclarativeBase):
    """Declarative base for all ORM models."""
    pass


# ── Dependency ──────────────────────────────────────────────────────────────
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: yield an async database session."""
    # Re-initialize if the loop has changed (critical for tests)
    import asyncio
    global _engine, _session_factory
    
    # ensures we don't use a stale engine from a closed loop.
    factory = get_session_local()
    
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
