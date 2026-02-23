"""
Sync router — batch sync, model update check, conflict handling.
POST /api/sync/batch-upload
GET  /api/sync/check-model-update
POST /api/sync/resolve-conflict
"""
from __future__ import annotations

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.services.sync_service import check_model_update, handle_conflict, process_batch_sync
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/sync", tags=["sync"])


@router.post("/batch-upload")
async def batch_upload(
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """
    Process batch offline data upload.
    Expects: {"payloads": [...], "device_id": "...", "nurse_id": "..."}
    """
    payloads = body.get("payloads", [])
    nurse_id = UUID(current_user["sub"])
    result = await process_batch_sync(db, payloads, device_id, nurse_id)
    return standard_response(result, "Batch sync processed", device_id=device_id)


@router.get("/check-model-update")
async def check_model(
    current_version: str,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Check if a newer TFLite model is available for download."""
    result = await check_model_update(db, current_version)
    return standard_response(result, "Model update status", device_id=device_id)


@router.post("/resolve-conflict")
async def resolve_conflict(
    body: dict,
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    """Resolve sync conflict between existing and incoming data."""
    existing = body.get("existing", {})
    incoming = body.get("incoming", {})
    result = await handle_conflict(existing, incoming)
    return standard_response({"resolved": result}, "Conflict resolved", device_id=device_id)
