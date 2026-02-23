"""
Auth schemas — strict Pydantic v2 request/response models.
All fields validated; unknown fields rejected (model_config extra='forbid').
"""
from __future__ import annotations

import re
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ── Shared strict config ──────────────────────────────────────────────────────

class _Strict(BaseModel):
    model_config = ConfigDict(
        extra="forbid",          # reject unknown fields
        str_strip_whitespace=True,
        str_max_length=512,
    )


# ── Validators ────────────────────────────────────────────────────────────────

_PHONE_RE = re.compile(r"^\+?[0-9]{7,15}$")
_DEVICE_RE = re.compile(r"^[A-Za-z0-9_\-]{4,128}$")
_HOSPITAL_ID_RE = re.compile(r"^[A-Za-z0-9_\-]{4,64}$")


class NurseLoginRequest(_Strict):
    phone_number: Annotated[str, Field(..., min_length=7, max_length=15, description="Nurse phone number (will be hashed)")]
    password: Annotated[str, Field(..., min_length=8, max_length=128)]
    device_id: Annotated[str, Field(..., min_length=4, max_length=128, description="Unique device identifier")]

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not _PHONE_RE.match(v):
            raise ValueError("Invalid phone number format")
        return v

    @field_validator("device_id")
    @classmethod
    def validate_device_id(cls, v: str) -> str:
        if not _DEVICE_RE.match(v):
            raise ValueError("device_id must be alphanumeric (4-128 chars)")
        return v


class DoctorLoginRequest(_Strict):
    hospital_id: Annotated[str, Field(..., min_length=4, max_length=64, description="Hospital-issued doctor ID")]
    password: Annotated[str, Field(..., min_length=8, max_length=128)]

    @field_validator("hospital_id")
    @classmethod
    def validate_hospital_id(cls, v: str) -> str:
        if not _HOSPITAL_ID_RE.match(v):
            raise ValueError("hospital_id must be alphanumeric (4-64 chars)")
        return v


class TokenResponse(_Strict):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token lifetime in seconds")


class NurseLoginResponse(_Strict):
    success: bool = True
    data: dict
    message: str = "Login successful"
    timestamp: str
    device_id: str


class DoctorLoginResponse(_Strict):
    success: bool = True
    data: dict
    message: str = "Login successful"
    timestamp: str
    device_id: str


class RefreshTokenRequest(_Strict):
    refresh_token: Annotated[str, Field(..., min_length=10, max_length=2048)]


class RefreshTokenResponse(_Strict):
    success: bool = True
    data: dict
    message: str = "Token refreshed"
    timestamp: str
    device_id: str


class LogoutRequest(_Strict):
    refresh_token: Annotated[str, Field(..., min_length=10, max_length=2048)]
