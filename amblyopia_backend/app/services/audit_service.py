"""
Amblyopia Care System — Audit Service
Tamper-proof audit logging. No DELETE on audit_trail ever.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_trail import AuditTrail
from app.utils.helpers import utc_now


async def log_action(
    db: AsyncSession,
    actor_id: Optional[UUID],
    actor_type: str,
    action: str,
    resource_type: Optional[str] = None,
    resource_id: Optional[UUID] = None,
    ip_address: Optional[str] = None,
    device_id: Optional[str] = None,
    old_value: Optional[Dict[str, Any]] = None,
    new_value: Optional[Dict[str, Any]] = None,
) -> AuditTrail:
    """
    Write one immutable audit record. Must never raise — wrap all errors.
    """
    try:
        entry = AuditTrail(
            actor_id=actor_id,
            actor_type=actor_type,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=ip_address,
            device_id=device_id,
            old_value=old_value,
            new_value=new_value,
            timestamp=utc_now(),
        )
        db.add(entry)
        await db.flush()   # write to DB within current transaction
        return entry
    except Exception as exc:
        # Audit logging must never crash the main flow
        import logging
        logging.getLogger(__name__).error("Audit log failed: %s", exc)
        return None


async def get_audit_log(
    db: AsyncSession,
    resource_id: UUID,
    limit: int = 100,
) -> List[AuditTrail]:
    """Return all audit records for a specific resource."""
    result = await db.execute(
        select(AuditTrail)
        .where(AuditTrail.resource_id == resource_id)
        .order_by(AuditTrail.timestamp.desc())
        .limit(limit)
    )
    return result.scalars().all()


async def get_actor_audit_log(
    db: AsyncSession,
    actor_id: UUID,
    limit: int = 100,
) -> List[AuditTrail]:
    """Return all audit records for a specific actor (nurse/doctor/admin)."""
    result = await db.execute(
        select(AuditTrail)
        .where(AuditTrail.actor_id == actor_id)
        .order_by(AuditTrail.timestamp.desc())
        .limit(limit)
    )
    return result.scalars().all()
