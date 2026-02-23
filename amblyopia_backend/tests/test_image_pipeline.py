"""
Phase 8: Image pipeline hardening tests.
Tests: magic-byte validation, face-confidence gate, per-stage timing present.
"""
from __future__ import annotations

import io
import struct
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


def _make_jpeg_bytes(size: int = 2048) -> bytes:
    """Minimal valid JPEG header + padding."""
    return b"\xff\xd8\xff" + bytes(size - 3)


def _make_png_bytes(size: int = 2048) -> bytes:
    """Minimal valid PNG header + padding."""
    return b"\x89PNG\r\n\x1a\n" + bytes(size - 8)


def _make_bmp_bytes(size: int = 2048) -> bytes:
    """BMP magic bytes (unsupported)."""
    return b"BM" + bytes(size - 2)


# ── Magic-byte validation ─────────────────────────────────────────────────────
class TestImageMagicByte:
    @pytest.mark.asyncio
    async def test_valid_jpeg_accepted(self):
        from app.pipelines.image_pipeline import _validate_image_bytes
        # Should NOT raise
        _validate_image_bytes(_make_jpeg_bytes())

    @pytest.mark.asyncio
    async def test_valid_png_accepted(self):
        from app.pipelines.image_pipeline import _validate_image_bytes
        _validate_image_bytes(_make_png_bytes())

    def test_bmp_rejected(self):
        from app.pipelines.image_pipeline import _validate_image_bytes
        with pytest.raises(ValueError, match="(?i)unsupported|invalid|format"):
            _validate_image_bytes(_make_bmp_bytes())

    def test_random_bytes_rejected(self):
        from app.pipelines.image_pipeline import _validate_image_bytes
        with pytest.raises(ValueError):
            _validate_image_bytes(b"\x00\x01\x02" * 1000)

    def test_too_small_rejected(self):
        from app.pipelines.image_pipeline import _validate_image_bytes
        with pytest.raises(ValueError, match="(?i)too small|size|minimum"):
            _validate_image_bytes(b"\xff\xd8\xff")  # valid header but < 1 KB


# ── Face confidence gate ──────────────────────────────────────────────────────
class TestFaceConfidenceGate:
    @pytest.mark.asyncio
    async def test_low_confidence_rejected(self):
        """Pipeline should reject images where face confidence < 0.6."""
        from app.pipelines.image_pipeline import run_image_pipeline

        with (
            patch("app.pipelines.image_pipeline._validate_image_bytes"),
            patch(
                "app.pipelines.image_pipeline.run_image_enhancement",
                new_callable=AsyncMock,
                return_value={
                    "enhanced_bytes": _make_jpeg_bytes(),
                    "blur_score":     80.0,
                    "brightness":     120.0,
                    "face_confidence": 0.35,   # below threshold
                },
            ),
        ):
            result = await run_image_pipeline(
                image_bytes=_make_jpeg_bytes(),
                session_id="s-1",
                patient_id="p-1",
            )
        assert result["status"] == "rejected"
        assert "confidence" in result.get("reason", "").lower()

    @pytest.mark.asyncio
    async def test_high_confidence_proceeds(self):
        """Pipeline should proceed when face confidence >= 0.6."""
        from app.pipelines.image_pipeline import run_image_pipeline

        with (
            patch("app.pipelines.image_pipeline._validate_image_bytes"),
            patch(
                "app.pipelines.image_pipeline.run_image_enhancement",
                new_callable=AsyncMock,
                return_value={
                    "enhanced_bytes": _make_jpeg_bytes(),
                    "blur_score":     80.0,
                    "brightness":     120.0,
                    "face_confidence": 0.85,
                },
            ),
            patch(
                "app.pipelines.image_pipeline.run_yolo_inference",
                new_callable=AsyncMock,
                return_value={
                    "eye_detected":           True,
                    "strabismus_detected":    False,
                    "strabismus_confidence":  0.1,
                    "prediction_confidence":  0.88,
                    "amblyopia_probability":  0.22,
                },
            ),
            patch("app.pipelines.image_pipeline._log_to_mlflow"),
        ):
            result = await run_image_pipeline(
                image_bytes=_make_jpeg_bytes(),
                session_id="s-2",
                patient_id="p-2",
            )
        assert result["status"] != "rejected"


# ── Per-stage timing ──────────────────────────────────────────────────────────
class TestImagePipelineTiming:
    @pytest.mark.asyncio
    async def test_timing_dict_present_in_result(self):
        from app.pipelines.image_pipeline import run_image_pipeline

        with (
            patch("app.pipelines.image_pipeline._validate_image_bytes"),
            patch(
                "app.pipelines.image_pipeline.run_image_enhancement",
                new_callable=AsyncMock,
                return_value={
                    "enhanced_bytes": _make_jpeg_bytes(),
                    "blur_score":     80.0,
                    "brightness":     120.0,
                    "face_confidence": 0.90,
                },
            ),
            patch(
                "app.pipelines.image_pipeline.run_yolo_inference",
                new_callable=AsyncMock,
                return_value={
                    "eye_detected":          True,
                    "strabismus_detected":   False,
                    "strabismus_confidence": 0.1,
                    "prediction_confidence": 0.82,
                    "amblyopia_probability": 0.18,
                },
            ),
            patch("app.pipelines.image_pipeline._log_to_mlflow"),
        ):
            result = await run_image_pipeline(
                image_bytes=_make_jpeg_bytes(),
                session_id="s-3",
                patient_id="p-3",
            )

        assert "timing_ms" in result, "timing_ms dict must be returned"
        timing = result["timing_ms"]
        assert "total_ms" in timing
        assert timing["total_ms"] >= 0

    @pytest.mark.asyncio
    async def test_strabismus_flag_in_result(self):
        from app.pipelines.image_pipeline import run_image_pipeline

        with (
            patch("app.pipelines.image_pipeline._validate_image_bytes"),
            patch(
                "app.pipelines.image_pipeline.run_image_enhancement",
                new_callable=AsyncMock,
                return_value={
                    "enhanced_bytes": _make_jpeg_bytes(),
                    "blur_score":     80.0,
                    "brightness":     120.0,
                    "face_confidence": 0.90,
                },
            ),
            patch(
                "app.pipelines.image_pipeline.run_yolo_inference",
                new_callable=AsyncMock,
                return_value={
                    "eye_detected":          True,
                    "strabismus_detected":   True,   # ← positive strabismus
                    "strabismus_confidence": 0.91,
                    "prediction_confidence": 0.88,
                    "amblyopia_probability": 0.75,
                },
            ),
            patch("app.pipelines.image_pipeline._log_to_mlflow"),
        ):
            result = await run_image_pipeline(
                image_bytes=_make_jpeg_bytes(),
                session_id="s-4",
                patient_id="p-4",
            )
        assert result.get("strabismus_flag") is True
