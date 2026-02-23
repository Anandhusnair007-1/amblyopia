"""
Voice Pipeline — coordinates voice enrollment, audio processing, response analysis.
Called by screening router when nurse sends audio for Snellen test.

Phase 3 hardening additions:
  - Duration gate: max 30 seconds (configurable in settings)
  - Silence-only detection (RMS energy threshold)
  - Confidence threshold gate (< 0.50 rejects transcript)
  - Whisper timeout protection (configurable via asyncio.wait_for)
  - Waveform metadata saved (duration, RMS energy, sample_rate)
"""
from __future__ import annotations

import asyncio
import logging
from typing import Optional

from app.config import settings

logger = logging.getLogger(__name__)

# RMS energy below this = silence-only clip
_SILENCE_RMS_THRESHOLD = 0.005


async def run_voice_pipeline(
    audio_bytes: bytes,
    session_id: str,
    expected_letter: Optional[str] = None,
    response_time_ms: int = 0,
    language: str = "en",
    redis_client=None,
) -> dict:
    """
    Full voice pipeline:
      1. Duration gate (max 30 s)
      2. Silence detection (reject silent clips)
      3. RNNoise denoising → Whisper transcription (with wall-clock timeout)
      4. Confidence threshold check (< voice_confidence_min rejects)
      5. Response analysis vs expected letter
      6. Return transcript + waveform metadata

    Raw audio is NEVER stored — only the text transcript is returned.
    """
    from app.services.voice_processing_service import analyze_response, process_audio

    # ── Step 0: Read waveform metadata before processing ─────────────────────
    waveform_meta = _read_waveform_meta(audio_bytes)
    if waveform_meta.get("error"):
        return {
            "success": False,
            "error": f"Audio read error: {waveform_meta['error']}",
            "transcript": "",
            "analysis": None,
            "waveform": waveform_meta,
        }

    duration_s = waveform_meta.get("duration_s", 0)
    rms_energy = waveform_meta.get("rms_energy", 0.0)

    # ── Step 1: Duration gate ─────────────────────────────────────────────────
    if duration_s > settings.voice_max_duration_s:
        logger.warning(
            "Audio clip too long (%.1f s > %d s) for session %s",
            duration_s, settings.voice_max_duration_s, session_id,
        )
        return {
            "success": False,
            "error": (
                f"Audio too long ({duration_s:.1f}s). "
                f"Maximum is {settings.voice_max_duration_s} seconds."
            ),
            "transcript": "",
            "analysis": None,
            "waveform": waveform_meta,
        }

    # ── Step 2: Silence detection ─────────────────────────────────────────────
    if rms_energy < _SILENCE_RMS_THRESHOLD:
        logger.warning(
            "Silence-only audio (RMS=%.5f) for session %s", rms_energy, session_id
        )
        return {
            "success": False,
            "error": "Audio appears to be silent. Please speak clearly near the microphone.",
            "transcript": "",
            "analysis": None,
            "waveform": waveform_meta,
        }

    # ── Step 3: Transcription with timeout protection ─────────────────────────
    try:
        processed = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None, lambda: process_audio(audio_bytes, session_id, language, redis_client)
            ),
            timeout=float(settings.whisper_timeout_s),
        )
    except asyncio.TimeoutError:
        logger.error(
            "Whisper inference timed out after %d s for session %s",
            settings.whisper_timeout_s, session_id,
        )
        return {
            "success": False,
            "error": f"Voice processing timed out ({settings.whisper_timeout_s}s). Please retry.",
            "transcript": "",
            "analysis": None,
            "waveform": waveform_meta,
        }

    if processed.get("error"):
        logger.error(
            "Voice processing failed for session %s: %s", session_id, processed["error"]
        )
        return {
            "success": False,
            "error": processed["error"],
            "transcript": "",
            "analysis": None,
            "waveform": waveform_meta,
        }

    transcript = processed.get("transcript", "")
    confidence = processed.get("confidence", 0.0)

    # ── Step 4: Confidence threshold ─────────────────────────────────────────
    if confidence < settings.voice_confidence_min:
        logger.warning(
            "Transcription confidence %.2f below threshold %.2f for session %s",
            confidence, settings.voice_confidence_min, session_id,
        )
        return {
            "success": False,
            "error": (
                f"Voice recognition confidence too low ({confidence:.0%}). "
                "Please repeat clearly."
            ),
            "transcript": transcript,
            "confidence": confidence,
            "analysis": None,
            "waveform": waveform_meta,
        }

    # ── Step 5: Response analysis ─────────────────────────────────────────────
    analysis = None
    if expected_letter and transcript:
        analysis = analyze_response(transcript, expected_letter, response_time_ms)

    return {
        "success": True,
        "transcript": transcript,
        "confidence": confidence,
        "duration_ms": processed.get("duration_ms", int(duration_s * 1000)),
        "analysis": analysis,
        "waveform": waveform_meta,
        "noise_reduced": processed.get("noise_reduced", False),
    }


def _read_waveform_meta(audio_bytes: bytes) -> dict:
    """Extract duration, RMS energy, and sample rate from raw WAV bytes."""
    try:
        import io
        import numpy as np
        import soundfile as sf

        audio, sr = sf.read(io.BytesIO(audio_bytes), dtype="float32")
        if audio.ndim > 1:
            audio = audio.mean(axis=1)

        duration_s = len(audio) / sr
        rms_energy = float(np.sqrt(np.mean(audio ** 2)))

        return {
            "duration_s": round(duration_s, 3),
            "sample_rate": sr,
            "samples": len(audio),
            "rms_energy": round(rms_energy, 6),
            "channels": 1,
        }
    except Exception as exc:
        logger.error("Waveform meta read failed: %s", exc)
        return {"error": str(exc), "duration_s": 0, "rms_energy": 0.0}
