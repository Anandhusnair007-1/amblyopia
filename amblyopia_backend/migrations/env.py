"""
Alembic migrations env.py — async PostgreSQL support.
Imports all model modules so Alembic auto-detects schema changes.
"""
from __future__ import annotations

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# ── Import all models so that metadata is populated ───────────────────────────
from app.database import Base
from app.models.audit_trail import AuditTrail  # noqa: F401
from app.models.combined_result import CombinedResult  # noqa: F401
from app.models.doctor_review import DoctorReview  # noqa: F401
from app.models.gaze_result import GazeResult  # noqa: F401
from app.models.ml_model import MLModel  # noqa: F401
from app.models.notification_log import NotificationLog  # noqa: F401
from app.models.nurse import Nurse  # noqa: F401
from app.models.patient import Patient  # noqa: F401
from app.models.redgreen_result import RedgreenResult  # noqa: F401
from app.models.retraining_job import RetrainingJob  # noqa: F401
from app.models.session import ScreeningSession  # noqa: F401
from app.models.snellen_result import SnellenResult  # noqa: F401
from app.models.sync_queue import SyncQueue  # noqa: F401
from app.models.village import Village  # noqa: F401

# ── Alembic Config ─────────────────────────────────────────────────────────────
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Override sqlalchemy.url with DATABASE_URL env var if available
import os
database_url = os.environ.get("DATABASE_URL")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

target_metadata = Base.metadata


# ── Offline Mode ──────────────────────────────────────────────────────────────

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode — no DB connection needed."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online Mode ───────────────────────────────────────────────────────────────

def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


# ── Entry Point ────────────────────────────────────────────────────────────────

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
