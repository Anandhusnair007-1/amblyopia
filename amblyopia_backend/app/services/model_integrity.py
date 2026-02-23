"""
Amblyopia Care System — Model Integrity Verification (MLSecOps)
===============================================================
Provides cryptographic hash verification for all ML model files.
Prevents execution of tampered, corrupted, or substituted model weights.

Flow:
  1. At deployment time: `register_all_model_hashes()` computes and stores
     SHA-256 hashes for every model file in the DB + a local manifest.
  2. At startup (warm_up hooks): `verify_model_at_load()` recomputes the hash
     and compares it against the registered value; aborts if mismatch.
  3. On MLflow model promotion: `register_mlflow_model_hash()` records the
     new version's hash so future loads can be verified.
  4. Scheduled check (Airflow DAG, daily): `audit_all_models()` re-verifies
     every registered model and raises alerts on any anomaly.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from sqlalchemy import Column, DateTime, Integer, String, Text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.database import Base

logger = logging.getLogger(__name__)

# ── Default model directory (relative to project root) ───────────────────────
_DEFAULT_MODELS_DIR = Path(__file__).resolve().parent.parent.parent / "models"
_MANIFEST_PATH = _DEFAULT_MODELS_DIR / ".model_integrity_manifest.json"

# ── ORM Model ─────────────────────────────────────────────────────────────────

class ModelHashRecord(Base):
    """Persistent store of each model file's expected SHA-256 hash."""
    __tablename__ = "model_hash_records"

    id             = Column(Integer, primary_key=True, index=True)
    model_name     = Column(String(128), nullable=False, index=True)
    model_version  = Column(String(64),  nullable=False)
    file_path      = Column(Text,        nullable=False)
    sha256_hash    = Column(String(64),  nullable=False)
    registered_at  = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    registered_by  = Column(String(128), nullable=True)   # username or 'system'
    mlflow_run_id  = Column(String(128), nullable=True)


# ── Core cryptographic helpers ────────────────────────────────────────────────

def compute_file_hash(file_path: str | Path, chunk_size: int = 1024 * 1024) -> str:
    """Return the lowercase hex SHA-256 digest of *file_path*.

    Reads the file in *chunk_size* byte chunks to handle large model files
    without loading the entire file into memory.

    Args:
        file_path: Absolute or relative path to the model file.
        chunk_size: Read buffer size in bytes (default 1 MiB).

    Returns:
        64-character lowercase hexadecimal SHA-256 digest.

    Raises:
        FileNotFoundError: If *file_path* does not exist.
        PermissionError:   If the file cannot be read.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Model file not found: {path}")

    hasher = hashlib.sha256()
    with path.open("rb") as fh:
        while chunk := fh.read(chunk_size):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    logger.debug("SHA-256(%s) = %s", path.name, digest)
    return digest


def verify_file_hash(file_path: str | Path, expected_hash: str) -> bool:
    """Return True iff the file's current SHA-256 matches *expected_hash*.

    Args:
        file_path:     Path to the model file.
        expected_hash: Expected 64-char hex SHA-256 digest.

    Returns:
        True on match, False on mismatch.
    """
    actual = compute_file_hash(file_path)
    match  = (actual.lower() == expected_hash.lower())
    if not match:
        logger.error(
            "INTEGRITY VIOLATION: %s — expected=%s actual=%s",
            file_path, expected_hash[:16] + "...", actual[:16] + "..."
        )
    return match


# ── DB operations ─────────────────────────────────────────────────────────────

async def register_model_hash(
    db:            AsyncSession,
    model_name:    str,
    model_version: str,
    file_path:     str | Path,
    registered_by: str = "system",
    mlflow_run_id: Optional[str] = None,
) -> ModelHashRecord:
    """Compute and persist the SHA-256 hash of *file_path* in the DB.

    If a record already exists for the same name+version+path, it is updated
    rather than creating a duplicate.

    Args:
        db:            Active async SQLAlchemy session.
        model_name:    Human-readable model name (e.g. ``"real_esrgan"``).
        model_version: Version string (e.g. ``"v2.0"`` or MLflow version ``"5"``).
        file_path:     Absolute path to the model file.
        registered_by: Who triggered the registration (user or service name).
        mlflow_run_id: Optional MLflow run ID for traceability.

    Returns:
        The persisted :class:`ModelHashRecord`.
    """
    sha256 = compute_file_hash(file_path)
    str_path = str(Path(file_path).resolve())

    # Upsert logic
    result = await db.execute(
        select(ModelHashRecord).filter_by(
            model_name=model_name,
            model_version=model_version,
            file_path=str_path,
        )
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = ModelHashRecord(
            model_name=model_name,
            model_version=model_version,
            file_path=str_path,
            sha256_hash=sha256,
            registered_by=registered_by,
            mlflow_run_id=mlflow_run_id,
        )
        db.add(record)
    else:
        record.sha256_hash   = sha256
        record.registered_at = datetime.now(timezone.utc)
        record.registered_by = registered_by
        record.mlflow_run_id = mlflow_run_id or record.mlflow_run_id

    await db.commit()
    await db.refresh(record)
    logger.info(
        "Registered hash for %s v%s: %s...",
        model_name, model_version, sha256[:16]
    )
    return record


async def verify_model_at_load(
    db:            AsyncSession,
    model_name:    str,
    model_version: str,
    file_path:     str | Path,
    abort_on_fail: bool = True,
) -> bool:
    """Verify a model file's hash against the stored expected value.

    Called by model warm-up hooks before loading weights into memory.

    Args:
        db:            Active async SQLAlchemy session.
        model_name:    Model identifier.
        model_version: Version string.
        file_path:     Path to the model file being loaded.
        abort_on_fail: If True (default), raise :class:`ModelIntegrityError`
                       on mismatch.  If False, return False and log only.

    Returns:
        True if hash matches, False otherwise (only if ``abort_on_fail=False``).

    Raises:
        ModelIntegrityError: On hash mismatch when ``abort_on_fail=True``.
        ModelNotRegisteredError: If no hash record is found and
                                 ``abort_on_fail=True``.
    """
    str_path = str(Path(file_path).resolve())

    result = await db.execute(
        select(ModelHashRecord).filter_by(
            model_name=model_name,
            model_version=model_version,
            file_path=str_path,
        )
    )
    record = result.scalar_one_or_none()

    if record is None:
        msg = f"No hash record found for {model_name} v{model_version} at {str_path}"
        logger.warning(msg)
        if abort_on_fail:
            raise ModelNotRegisteredError(msg)
        return False

    ok = verify_file_hash(file_path, record.sha256_hash)

    if not ok:
        msg = (
            f"INTEGRITY VIOLATION: {model_name} v{model_version} "
            f"— hash mismatch. Possible tampering or corruption!"
        )
        logger.critical(msg)
        if abort_on_fail:
            raise ModelIntegrityError(msg)
        return False

    logger.info("Model integrity OK: %s v%s", model_name, model_version)
    return True


async def audit_all_models(
    db: AsyncSession,
) -> dict[str, bool]:
    """Re-verify every registered model hash.

    Intended to be called by a daily Airflow DAG. Returns a mapping of
    ``"model_name:version:path"`` → boolean integrity result.

    Args:
        db: Active async SQLAlchemy session.

    Returns:
        Dict mapping model identifier strings to True (pass) / False (fail).
    """
    result = await db.execute(select(ModelHashRecord))
    records = result.scalars().all()

    results: dict[str, bool] = {}
    for rec in records:
        key = f"{rec.model_name}:{rec.model_version}:{Path(rec.file_path).name}"
        try:
            ok = verify_file_hash(rec.file_path, rec.sha256_hash)
        except FileNotFoundError:
            logger.error("Model file MISSING: %s", rec.file_path)
            ok = False
        results[key] = ok

    failed = [k for k, v in results.items() if not v]
    if failed:
        logger.critical("MODEL INTEGRITY AUDIT FAILURES: %s", failed)
    else:
        logger.info("Model integrity audit: all %d model(s) OK.", len(records))

    return results


# ── Local filesystem manifest (offline / pre-DB verification) ─────────────────

def write_manifest(
    model_dir:     str | Path = _DEFAULT_MODELS_DIR,
    manifest_path: str | Path = _MANIFEST_PATH,
) -> dict[str, str]:
    """Scan *model_dir* recursively and write a SHA-256 manifest JSON file.

    Covers the following extensions: ``.pt``, ``.pth``, ``.onnx``,
    ``.tflite``, ``.bin``, ``.h5``, ``.pb``.

    Args:
        model_dir:     Root directory containing model files.
        manifest_path: Output JSON path.

    Returns:
        Manifest dict mapping relative paths to SHA-256 hashes.
    """
    model_dir = Path(model_dir)
    extensions = {".pt", ".pth", ".onnx", ".tflite", ".bin", ".h5", ".pb", ".pkl"}

    manifest: dict[str, str] = {}
    for ext in extensions:
        for fpath in sorted(model_dir.rglob(f"*{ext}")):
            rel = str(fpath.relative_to(model_dir))
            manifest[rel] = compute_file_hash(fpath)
            logger.debug("Hashed  %s", rel)

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "model_dir":    str(model_dir),
                "files":        manifest,
            },
            f,
            indent=2,
        )
    logger.info("Manifest written to %s (%d files)", manifest_path, len(manifest))
    return manifest


def verify_manifest(
    model_dir:     str | Path = _DEFAULT_MODELS_DIR,
    manifest_path: str | Path = _MANIFEST_PATH,
    abort_on_fail: bool = False,
) -> tuple[int, int]:
    """Verify all files in *manifest_path* against their stored hashes.

    Args:
        model_dir:     Root directory (used to resolve relative paths).
        manifest_path: Path to the JSON manifest.
        abort_on_fail: If True, raise :class:`ModelIntegrityError` on first mismatch.

    Returns:
        Tuple of (pass_count, fail_count).
    """
    model_dir = Path(model_dir)
    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    pass_count = fail_count = 0
    for rel_path, expected_hash in data["files"].items():
        full_path = model_dir / rel_path
        try:
            ok = verify_file_hash(full_path, expected_hash)
        except FileNotFoundError:
            logger.error("MISSING model file: %s", full_path)
            ok = False

        if ok:
            pass_count += 1
        else:
            fail_count += 1
            if abort_on_fail:
                raise ModelIntegrityError(f"Hash mismatch: {rel_path}")

    logger.info(
        "Manifest verification: %d PASS / %d FAIL",
        pass_count, fail_count
    )
    return pass_count, fail_count


# ── MLflow integration ────────────────────────────────────────────────────────

async def register_mlflow_model_hash(
    db:            AsyncSession,
    model_name:    str,
    mlflow_version: str,
    local_model_path: str | Path,
    run_id:        Optional[str] = None,
) -> ModelHashRecord:
    """Register the hash of a promoted MLflow model version.

    Call this in the MLflow model promotion callback / CI step.

    Args:
        db:               Active async DB session.
        model_name:       MLflow registered model name.
        mlflow_version:   MLflow model version number (as string).
        local_model_path: Local path where the model artifact is stored.
        run_id:           MLflow run ID for traceability.

    Returns:
        The persisted :class:`ModelHashRecord`.
    """
    return await register_model_hash(
        db=db,
        model_name=model_name,
        model_version=f"mlflow-v{mlflow_version}",
        file_path=local_model_path,
        registered_by="mlflow-promotion",
        mlflow_run_id=run_id,
    )


# ── Exceptions ────────────────────────────────────────────────────────────────

class ModelIntegrityError(RuntimeError):
    """Raised when a model file's hash does not match the registered value."""


class ModelNotRegisteredError(RuntimeError):
    """Raised when no hash record exists for a model that requires verification."""
