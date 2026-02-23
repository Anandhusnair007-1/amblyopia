"""
Amblyopia Care System — Configuration Module
Reads settings from environment variables with validation.
"""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
        protected_namespaces=(),   # allow fields named model_*
    )

    # ── Database ───────────────────────────────────────────────────────
    database_url: str = (
        "postgresql+asyncpg://amblyopia_user:amblyopia_pass@localhost:5432/amblyopia_db"
    )
    sync_database_url: str = (
        "postgresql://amblyopia_user:amblyopia_pass@localhost:5432/amblyopia_db"
    )

    # ── Redis ──────────────────────────────────────────────────────────
    redis_url: str = "redis://localhost:6379/0"

    # ── JWT / Auth ─────────────────────────────────────────────────────
    secret_key: str = ""      # required — set via SECRET_KEY env var
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 15   # 15 min strict — DPDP Act 2023
    refresh_token_expire_days: int = 7

    # ── Brute-Force Protection ─────────────────────────────────────────
    login_max_attempts: int = 10          # per nurse phone per window
    login_rate_window_seconds: int = 300  # 5-minute rolling window

    # ── Encryption ─────────────────────────────────────────────────────
    encryption_key: str = ""  # required — set via ENCRYPTION_KEY env var (base64 32-byte AES-256)

    # ── MinIO ──────────────────────────────────────────────────────────
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = ""  # required — set via MINIO_ACCESS_KEY env var
    minio_secret_key: str = ""  # required — set via MINIO_SECRET_KEY env var
    minio_bucket: str = "amblyopia-data"
    minio_secure: bool = False
    minio_region: str = "ap-south-1"

    # ── Twilio ─────────────────────────────────────────────────────────
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_whatsapp_number: str = "whatsapp:+14155238886"
    twilio_sms_number: str = ""

    # ── Firebase ───────────────────────────────────────────────────────
    firebase_credentials_path: str = "/app/firebase-key.json"

    # ── MLflow ─────────────────────────────────────────────────────────
    mlflow_tracking_uri: str = "http://localhost:5000"
    mlflow_experiment_name: str = "amblyopia_screening"

    # ── Sentry ─────────────────────────────────────────────────────────
    sentry_dsn: str = ""

    # ── Hospital ───────────────────────────────────────────────────────
    hospital_name: str = "Aravind Eye Hospital"
    hospital_domain: str = "aravind.org"
    cors_origins: str = "https://dashboard.aravind.org,https://admin.aravind.org"

    # ── India / Locale ──────────────────────────────────────────────────
    india_timezone: str = "Asia/Kolkata"
    india_region: str = "ap-south-1"

    # ── Model Config ────────────────────────────────────────────────────
    model_confidence_threshold: float = 0.90
    min_cases_for_retraining: int = 50
    retraining_schedule: str = "0 2 * * 0"

    # ── Pretrained Weight Paths (GitHub repos — weights only, no training) ──
    # xinntao/Real-ESRGAN  — 4× iris super-resolution
    esrgan_model_path: str = "models/real_esrgan/RealESRGAN_x4plus.pth"
    # Thehunk1206/Zero-DCE — low-light enhancement
    zerodce_model_path: str = "models/zero_dce/zero_dce_weights.pth"
    # KAIR-IBD/DeblurGANv2 — motion/focus deblurring
    deblurgan_model_path: str = "models/deblurgan/fpn_inception.h5"
    # ggerganov/whisper.cpp — offline speech recognition (loaded via openai-whisper)
    whisper_model_size: str = "small"        # tiny | small | medium
    # ultralytics/ultralytics — YOLOv8-nano strabismus detection
    yolo_model_path: str = "models/yolo/yolov8n.pt"
    # TFLite ref: tumuyan/ESRGAN-Android-TFLite-Demo — on-device inference size
    tflite_input_size: int = 224

    # ── Rate Limiting ───────────────────────────────────────────────────
    rate_limit_per_minute: int = 100

    # ── Scoring Thresholds (configurable for clinical tuning) ──────────
    score_low_max: float = 30.0        # 0–30   → low risk
    score_medium_max: float = 60.0     # 30–60  → medium
    score_high_max: float = 85.0       # 60–85  → high
    # ≥85 → critical
    face_confidence_min: float = 0.60  # reject image if below
    blur_threshold: float = 100.0      # Laplacian variance threshold
    voice_confidence_min: float = 0.50 # reject transcript if below
    voice_max_duration_s: int = 30     # max audio clip length in seconds
    whisper_timeout_s: int = 30        # Whisper inference wall-clock timeout

    # ── MLflow Model Registry ──────────────────────────────────────────
    mlflow_model_name: str = "amblyopia_screening"
    mlflow_production_alias: str = "production"
    mlflow_staging_alias: str = "staging"
    mlflow_min_auroc: float = 0.82     # must beat this to auto-promote

    # ── JSON Logging ──────────────────────────────────────────────────
    log_json: bool = False             # set True in production via env

    # ── Environment ─────────────────────────────────────────────────────
    environment: str = "development"
    debug: bool = False
    log_level: str = "INFO"

    @model_validator(mode="after")
    def _assert_production_secrets(self) -> "Settings":
        """
        Fail fast on startup if any critical secret is missing in production.
        In development the values come from the local .env file.
        """
        if self.environment.lower() == "production":
            missing: list[str] = []
            if not self.secret_key or len(self.secret_key) < 32:
                missing.append("SECRET_KEY (min 32 chars)")
            if not self.encryption_key:
                missing.append("ENCRYPTION_KEY")
            if not self.minio_access_key:
                missing.append("MINIO_ACCESS_KEY")
            if not self.minio_secret_key:
                missing.append("MINIO_SECRET_KEY")
            if missing:
                raise ValueError(
                    "Production startup blocked — missing required secrets: "
                    + ", ".join(missing)
                    + ". Set them via environment variables or a secrets manager."
                )
        return self

    @property
    def allowed_origins(self) -> List[str]:
        """Parse CORS origins from comma-separated string."""
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


@lru_cache()
def get_settings() -> Settings:
    """Return cached Settings instance."""
    return Settings()


settings: Settings = get_settings()
