import os
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from api.common import api_success
from database import get_session
from models import ModelRegistry

router = APIRouter(prefix="/api/models", tags=["models"])

MODEL_ROOT = Path(os.getenv("MODEL_ROOT", "/tmp/ambyoai_models"))


@router.get("/latest")
def latest_model():
    with get_session() as session:
        model = (
            session.query(ModelRegistry)
            .filter(ModelRegistry.is_active.is_(True))
            .order_by(ModelRegistry.created_at.desc())
            .first()
        )
        if model is None:
            return api_success(
                {
                    "version": "0.0.0",
                    "download_url": "",
                    "size_bytes": 0,
                    "checksum": "",
                },
                message="no active model",
            )

        path = MODEL_ROOT / model.storage_path
        size_bytes = path.stat().st_size if path.exists() else 0
        return api_success(
            {
                "version": model.version,
                "download_url": f"/api/models/download/{model.version}",
                "size_bytes": size_bytes,
                "checksum": model.checksum,
            }
        )


@router.get("/download/{version}")
def download_model(version: str):
    with get_session() as session:
        model = (
            session.query(ModelRegistry)
            .filter(ModelRegistry.version == version)
            .order_by(ModelRegistry.created_at.desc())
            .first()
        )
        if model is None:
            raise HTTPException(status_code=404, detail="model not found")

        path = MODEL_ROOT / model.storage_path
        if not path.exists():
            raise HTTPException(status_code=404, detail="model file missing")
        return FileResponse(path, media_type="application/octet-stream", filename=path.name)
