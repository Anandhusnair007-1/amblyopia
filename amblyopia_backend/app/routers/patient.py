"""
Patient router — create, get, history, update face vector.
POST /api/patient/create
GET  /api/patient/{patient_id}
GET  /api/patient/history/{patient_id}
PUT  /api/patient/{patient_id}/update-face-vector
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_nurse, get_device_id, rate_limit
from app.schemas.patient import PatientCreate, UpdateFaceVectorRequest
from app.services import audit_service, patient_service
from app.utils.helpers import standard_response

router = APIRouter(prefix="/api/patient", tags=["patient"])


@router.post("/create")
async def create_patient(
    body: PatientCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    patient = await patient_service.create_patient(
        db, body.age_group, body.village_id, body.face_vector
    )
    await audit_service.log_action(
        db, actor_id=UUID(current_user["sub"]), actor_type="nurse",
        action="CREATE_PATIENT", resource_type="Patient", resource_id=patient.id,
        ip_address=request.client.host, device_id=device_id,
        new_value={"age_group": body.age_group, "village_id": str(body.village_id)},
    )
    return standard_response({"patient_id": str(patient.id)}, "Patient created", device_id=device_id)


@router.get("/{patient_id}")
async def get_patient(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    patient = await patient_service.get_patient(db, patient_id)
    data = {
        "id": str(patient.id),
        "age_group": patient.age_group,
        "village_id": str(patient.village_id) if patient.village_id else None,
        "created_at": patient.created_at.isoformat() if patient.created_at else None,
        "last_screened_at": patient.last_screened_at.isoformat() if patient.last_screened_at else None,
        "total_screenings": patient.total_screenings,
        "is_active": patient.is_active,
    }
    return standard_response(data, "Patient retrieved", device_id=device_id)


@router.get("/history/{patient_id}")
async def get_patient_history(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    history = await patient_service.get_patient_history(db, patient_id)
    return standard_response(history, "Patient history retrieved", device_id=device_id)


@router.put("/{patient_id}/update-face-vector")
async def update_face_vector(
    patient_id: UUID,
    body: UpdateFaceVectorRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_nurse),
    device_id: str = Depends(get_device_id),
    _rl: None = Depends(rate_limit),
):
    patient = await patient_service.update_face_vector(db, patient_id, body.face_vector)
    await audit_service.log_action(
        db, actor_id=UUID(current_user["sub"]), actor_type="nurse",
        action="UPDATE_FACE_VECTOR", resource_type="Patient", resource_id=patient_id,
        ip_address=request.client.host, device_id=device_id,
    )
    return standard_response({"patient_id": str(patient.id)}, "Face vector updated", device_id=device_id)
