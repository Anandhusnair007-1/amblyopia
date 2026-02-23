"""
Amblyopia Care System — Sync Service
Processes batch offline data uploads with deduplication.
Handles model update checks for nurse devices.
"""
from __future__ import annotations

import json
import logging
from typing import List, Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.combined_result import CombinedResult
from app.models.gaze_result import GazeResult
from app.models.ml_model import MLModel
from app.models.redgreen_result import RedgreenResult
from app.models.session import ScreeningSession
from app.models.snellen_result import SnellenResult
from app.models.sync_queue import SyncQueue
from app.services.encryption_service import decrypt
from app.utils.helpers import utc_now

logger = logging.getLogger(__name__)


async def process_batch_sync(
    db: AsyncSession,
    payloads: List[dict],
    device_id: str,
    nurse_id: UUID,
) -> dict:
    """
    Process a batch of encrypted offline payloads.
    Deduplicates by session_id, saves to correct tables, marks synced.
    """
    success_count = 0
    failed_count = 0
    errors = []

    for item in payloads:
        try:
            payload_type = item.get("payload_type")
            payload_encrypted = item.get("payload_encrypted")
            offline_at = item.get("created_offline_at")
            sync_queue_id = item.get("sync_queue_id")

            # Decrypt payload
            try:
                payload_json = decrypt(payload_encrypted)
                data = json.loads(payload_json)
            except Exception as dec_err:
                logger.error("Payload decryption failed: %s", dec_err)
                failed_count += 1
                errors.append({"payload_type": payload_type, "error": "decryption_failed"})
                continue

            session_id_str = data.get("session_id")
            if not session_id_str:
                failed_count += 1
                errors.append({"payload_type": payload_type, "error": "missing_session_id"})
                continue

            session_id = UUID(session_id_str)

            # Deduplication — skip if already exists
            existing = await _check_duplicate(db, payload_type, session_id)
            if existing:
                logger.info("Duplicate detected for %s/%s — skipping", payload_type, session_id)
                success_count += 1
                continue

            await _save_payload(db, payload_type, session_id, data)
            await db.flush()
            success_count += 1

            # Update sync queue if entry exists
            if sync_queue_id:
                sq_q = await db.execute(
                    select(SyncQueue).where(SyncQueue.id == UUID(sync_queue_id))
                )
                sq = sq_q.scalar_one_or_none()
                if sq:
                    sq.sync_status = "synced"
                    sq.synced_at = utc_now()
                    await db.flush()

        except Exception as exc:
            logger.error("Sync item failed: %s", exc)
            failed_count += 1
            errors.append({"error": str(exc)})

    return {
        "success_count": success_count,
        "failed_count": failed_count,
        "total": len(payloads),
        "errors": errors[:10],  # limit error details returned
    }


async def _check_duplicate(db: AsyncSession, payload_type: str, session_id: UUID) -> bool:
    """Return True if a record for this session_id already exists."""
    model_map = {
        "gaze_result": GazeResult,
        "redgreen_result": RedgreenResult,
        "snellen_result": SnellenResult,
        "combined_result": CombinedResult,
    }
    model = model_map.get(payload_type)
    if model is None:
        return False
    result = await db.execute(select(model).where(model.session_id == session_id))
    return result.scalar_one_or_none() is not None


async def _save_payload(db: AsyncSession, payload_type: str, session_id: UUID, data: dict) -> None:
    """Save a decrypted payload to the correct table."""
    if payload_type == "gaze_result":
        obj = GazeResult(session_id=session_id, **{k: v for k, v in data.items()
                                                    if k != "session_id" and hasattr(GazeResult, k)})
        db.add(obj)
    elif payload_type == "redgreen_result":
        obj = RedgreenResult(session_id=session_id, **{k: v for k, v in data.items()
                                                        if k != "session_id" and hasattr(RedgreenResult, k)})
        db.add(obj)
    elif payload_type == "snellen_result":
        obj = SnellenResult(session_id=session_id, **{k: v for k, v in data.items()
                                                       if k != "session_id" and hasattr(SnellenResult, k)})
        db.add(obj)
    elif payload_type == "session":
        # Update session sync status if session exists
        sess_q = await db.execute(select(ScreeningSession).where(ScreeningSession.id == session_id))
        sess = sess_q.scalar_one_or_none()
        if sess:
            sess.sync_status = "synced"
            await db.flush()


async def check_model_update(db: AsyncSession, current_version: str) -> dict:
    """
    Check if a newer active TFLite model is available than current_version.
    Returns update_available, new version, and download URL.
    """
    result = await db.execute(
        select(MLModel)
        .where(MLModel.status == "active")
        .order_by(MLModel.deployed_at.desc())
        .limit(1)
    )
    active_model = result.scalar_one_or_none()

    if active_model is None:
        return {"update_available": False, "reason": "No active model"}

    if active_model.version == current_version:
        return {"update_available": False, "current_version": current_version}

    return {
        "update_available": True,
        "current_version": current_version,
        "new_version": active_model.version,
        "download_url": active_model.tflite_file_path,
        "model_size_mb": float(active_model.model_size_mb) if active_model.model_size_mb else None,
        "accuracy": float(active_model.accuracy_score) if active_model.accuracy_score else None,
    }


async def handle_conflict(existing: dict, incoming: dict) -> dict:
    """For conflicts, keep the most recent record based on created_at timestamp."""
    existing_ts = existing.get("created_at")
    incoming_ts = incoming.get("created_at")

    if existing_ts is None:
        return incoming
    if incoming_ts is None:
        return existing

    return incoming if incoming_ts > existing_ts else existing
