import hashlib
import json
import os
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from minio import Minio

from api.common import api_success
from database import get_session
from models import ImageRecord, PredictionRecord, SyncedSession

router = APIRouter(prefix="/api/sync", tags=["sync"])

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
RESULTS_BUCKET = os.getenv("MINIO_BUCKET_RESULTS", "ambyoai-results")

minio_client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False,
)


def _ensure_bucket(bucket_name: str) -> None:
    if not minio_client.bucket_exists(bucket_name):
        minio_client.make_bucket(bucket_name)


@router.post("/results")
def sync_results(payload: dict):
    hashed_session_id = hashlib.sha256(payload["session_id"].encode("utf-8")).hexdigest()
    test_date = datetime.fromisoformat(payload["test_date"])

    with get_session() as session:
        record = (
            session.query(SyncedSession)
            .filter(SyncedSession.hashed_session_id == hashed_session_id)
            .one_or_none()
        )
        if record is None:
            record = SyncedSession(
                hashed_session_id=hashed_session_id,
                device_id=payload["device_id"],
                test_date=test_date,
                age_group=payload["results"].get("age_group", "unknown"),
                payload_json=json.dumps(payload["results"]),
                label=payload.get("label"),
            )
            session.add(record)
            session.flush()
        else:
            record.payload_json = json.dumps(payload["results"])
            record.age_group = payload["results"].get("age_group", "unknown")
            record.label = payload.get("label")

        prediction = payload.get("ai_prediction")
        if prediction:
            prediction_record = (
                session.query(PredictionRecord)
                .filter(PredictionRecord.session_id == record.id)
                .one_or_none()
            )
            if prediction_record is None:
                prediction_record = PredictionRecord(
                    session_id=record.id,
                    risk_score=prediction["risk_score"],
                    risk_level=prediction["risk_level"],
                    model_version=prediction["model_version"],
                )
                session.add(prediction_record)
            else:
                prediction_record.risk_score = prediction["risk_score"]
                prediction_record.risk_level = prediction["risk_level"]
                prediction_record.model_version = prediction["model_version"]

        return api_success(
            {
                "status": "queued",
                "hashed_session_id": hashed_session_id,
            },
            message="results queued",
        )


@router.post("/images")
async def sync_images(
    session_id: str = Form(...),
    image_type: str = Form(...),
    image: UploadFile = File(...),
):
    if not image_type:
        raise HTTPException(status_code=400, detail="image_type is required")

    _ensure_bucket(RESULTS_BUCKET)
    hashed_session_id = hashlib.sha256(session_id.encode("utf-8")).hexdigest()
    extension = Path(image.filename or "upload.bin").suffix or ".bin"
    object_name = f"{hashed_session_id}/{image_type}{extension}"

    content = await image.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="empty file upload")

    temp_dir = Path("/tmp/ambyoai_uploads")
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_file = temp_dir / f"{hashed_session_id}_{image_type}{extension}"
    temp_file.write_bytes(content)

    minio_client.fput_object(RESULTS_BUCKET, object_name, str(temp_file))

    with get_session() as session:
        record = (
            session.query(SyncedSession)
            .filter(SyncedSession.hashed_session_id == hashed_session_id)
            .one_or_none()
        )
        if record is None:
            raise HTTPException(status_code=404, detail="session not found")
        session.add(
            ImageRecord(
                session_id=record.id,
                image_type=image_type,
                object_path=object_name,
            )
        )

    return api_success(
        {
            "status": "stored",
            "object_path": object_name,
        },
        message="image stored",
    )
