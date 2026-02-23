"""
Phase 8: Voice pipeline safety-gate tests.
Tests: duration gate, silence detection, confidence threshold gate, waveform metadata.
"""
from __future__ import annotations

import struct
import wave
import io
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


def _make_wav_bytes(duration_s: float = 3.0, rms: float = 0.1, sample_rate: int = 16000) -> bytes:
    """Generate a minimal PCM WAV file with controllable duration and RMS energy."""
    import math, random
    n_samples = int(duration_s * sample_rate)
    # Sine + noise to hit target RMS
    amplitude = int(rms * 32767)
    samples   = [int(amplitude * math.sin(2 * math.pi * 440 * i / sample_rate)) for i in range(n_samples)]
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{n_samples}h", *samples))
    return buf.getvalue()


def _make_silent_wav_bytes(duration_s: float = 3.0, sample_rate: int = 16000) -> bytes:
    """Completely silent WAV (RMS ≈ 0)."""
    n_samples = int(duration_s * sample_rate)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * n_samples)
    return buf.getvalue()


# ── Waveform metadata ─────────────────────────────────────────────────────────
class TestWaveformMeta:
    def test_duration_extracted_correctly(self):
        from app.pipelines.voice_pipeline import _read_waveform_meta
        wav = _make_wav_bytes(duration_s=5.0)
        meta = _read_waveform_meta(wav)
        assert abs(meta["duration_s"] - 5.0) < 0.1

    def test_sample_rate_extracted(self):
        from app.pipelines.voice_pipeline import _read_waveform_meta
        wav = _make_wav_bytes(sample_rate=16000)
        meta = _read_waveform_meta(wav)
        assert meta["sample_rate"] == 16000

    def test_rms_energy_positive_for_loud_audio(self):
        from app.pipelines.voice_pipeline import _read_waveform_meta
        wav = _make_wav_bytes(rms=0.5)
        meta = _read_waveform_meta(wav)
        assert meta["rms_energy"] > 0.005

    def test_rms_energy_near_zero_for_silence(self):
        from app.pipelines.voice_pipeline import _read_waveform_meta
        wav = _make_silent_wav_bytes()
        meta = _read_waveform_meta(wav)
        assert meta["rms_energy"] < 0.005


# ── Duration gate ─────────────────────────────────────────────────────────────
class TestDurationGate:
    @pytest.mark.asyncio
    async def test_short_audio_accepted(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(duration_s=5.0)

        with (
            patch(
                "app.pipelines.voice_pipeline.denoise_audio",
                new_callable=AsyncMock,
                return_value=wav,
            ),
            patch(
                "app.pipelines.voice_pipeline._transcribe_with_timeout",
                new_callable=AsyncMock,
                return_value={"text": "red green", "confidence": 0.95},
            ),
        ):
            result = await run_voice_pipeline(wav, session_id="s-1")

        assert result["status"] != "rejected" or "duration" not in result.get("reason", "")

    @pytest.mark.asyncio
    async def test_long_audio_rejected(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(duration_s=35.0)   # exceeds 30-second max

        result = await run_voice_pipeline(wav, session_id="s-2")
        assert result["status"] == "rejected"
        assert "duration" in result.get("reason", "").lower()


# ── Silence gate ──────────────────────────────────────────────────────────────
class TestSilenceGate:
    @pytest.mark.asyncio
    async def test_silent_audio_rejected(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_silent_wav_bytes(duration_s=3.0)

        result = await run_voice_pipeline(wav, session_id="s-3")
        assert result["status"] == "rejected"
        assert "silence" in result.get("reason", "").lower()

    @pytest.mark.asyncio
    async def test_audible_audio_passes_silence_gate(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(rms=0.3, duration_s=4.0)

        with (
            patch(
                "app.pipelines.voice_pipeline.denoise_audio",
                new_callable=AsyncMock,
                return_value=wav,
            ),
            patch(
                "app.pipelines.voice_pipeline._transcribe_with_timeout",
                new_callable=AsyncMock,
                return_value={"text": "red", "confidence": 0.9},
            ),
        ):
            result = await run_voice_pipeline(wav, session_id="s-4")

        assert result.get("reason", "") != "silence detected"


# ── Confidence gate ───────────────────────────────────────────────────────────
class TestVoiceConfidenceGate:
    @pytest.mark.asyncio
    async def test_low_confidence_rejected(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(duration_s=4.0, rms=0.3)

        with (
            patch(
                "app.pipelines.voice_pipeline.denoise_audio",
                new_callable=AsyncMock,
                return_value=wav,
            ),
            patch(
                "app.pipelines.voice_pipeline._transcribe_with_timeout",
                new_callable=AsyncMock,
                return_value={"text": "...", "confidence": 0.30},   # below 0.5
            ),
        ):
            result = await run_voice_pipeline(wav, session_id="s-5")

        assert result["status"] == "rejected"
        assert "confidence" in result.get("reason", "").lower()

    @pytest.mark.asyncio
    async def test_high_confidence_accepted(self):
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(duration_s=4.0, rms=0.3)

        with (
            patch(
                "app.pipelines.voice_pipeline.denoise_audio",
                new_callable=AsyncMock,
                return_value=wav,
            ),
            patch(
                "app.pipelines.voice_pipeline._transcribe_with_timeout",
                new_callable=AsyncMock,
                return_value={"text": "red green blue", "confidence": 0.92},
            ),
        ):
            result = await run_voice_pipeline(wav, session_id="s-6")

        assert result["status"] != "rejected"

    @pytest.mark.asyncio
    async def test_waveform_metadata_in_result(self):
        """Successful pipeline should include waveform metadata."""
        from app.pipelines.voice_pipeline import run_voice_pipeline

        wav = _make_wav_bytes(duration_s=4.0, rms=0.3)

        with (
            patch(
                "app.pipelines.voice_pipeline.denoise_audio",
                new_callable=AsyncMock,
                return_value=wav,
            ),
            patch(
                "app.pipelines.voice_pipeline._transcribe_with_timeout",
                new_callable=AsyncMock,
                return_value={"text": "red green", "confidence": 0.88},
            ),
        ):
            result = await run_voice_pipeline(wav, session_id="s-7")

        assert "waveform" in result
        for key in ("duration_s", "sample_rate", "rms_energy"):
            assert key in result["waveform"], f"Missing waveform.{key}"
