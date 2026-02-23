"""
Amblyopia Care System — Voice Processing Service
=================================================
Processes nurse voice recordings for Snellen / Tumbling-E / Gaze tests.

GitHub repos wired in:
  ✅ ggerganov/whisper.cpp  → offline speech-to-text (small model)
                              loaded via openai-whisper Python package
  ✅ xiph/rnnoise           → background noise suppression (compiled C lib)
                              wrapped via Python ctypes

Loading strategy: LAZY — both models loaded once on first call and cached.
If RNNoise library is not compiled, audio goes directly to Whisper.
If Whisper is unavailable, transcription returns empty with error flag.

PRIVACY: raw audio bytes are NEVER persisted.
         Only the text transcript is kept after this function returns.
"""
from __future__ import annotations

import io
import logging
from typing import Optional


import numpy as np

logger = logging.getLogger(__name__)

# ── Model / library config ──────────────────────────────────────────────────
WHISPER_MODEL_SIZE   = "small"          # tiny | small | medium
HESITATION_THRESHOLD_MS = 3000         # 3 s → hesitation flag
VAD_AGGRESSIVENESS   = 2               # 0-3; for webrtcvad fallback

# ── Singletons ──────────────────────────────────────────────────────────────
_whisper_integration = None   # WhisperIntegration instance
_rnnoise_integration = None   # RNNoiseIntegration instance
_rnnoise_unavailable = False  # flag to skip retry after first failure


# ══════════════════════════════════════════════════════════════════════════
# Lazy loaders
# ══════════════════════════════════════════════════════════════════════════

def _get_whisper():
    """
    Load WhisperIntegration (wraps openai-whisper with small model weights
    from ggerganov/whisper.cpp or HuggingFace).
    """
    global _whisper_integration
    if _whisper_integration is not None:
        return _whisper_integration
    try:
        from integrations.whisper_integration import WhisperIntegration
        _whisper_integration = WhisperIntegration(model_size=WHISPER_MODEL_SIZE)
        logger.info("WhisperIntegration loaded ✓ (model=%s)", WHISPER_MODEL_SIZE)
        return _whisper_integration
    except Exception as exc:
        logger.warning("WhisperIntegration load failed (%s) — trying bare whisper", exc)
        # Try bare openai-whisper as last resort
        try:
            import whisper as _w
            class _BareWhisper:
                """Thin adapter so bare whisper looks like WhisperIntegration."""
                def __init__(self):
                    self._model = _w.load_model(WHISPER_MODEL_SIZE)

                def transcribe(self, audio, language=None, **kw):
                    opts = {"fp16": False, "verbose": False}
                    if language:
                        opts["language"] = language
                    res = self._model.transcribe(audio, **opts)
                    segs = res.get("segments", [])
                    lp   = float(np.mean([s.get("avg_logprob", -1) for s in segs])) if segs else -1.0
                    conf = float(np.clip(np.exp(lp), 0, 1))
                    return {
                        "text": res["text"].strip(),
                        "language": res.get("language", "en"),
                        "confidence": round(conf, 4),
                        "processing_time_ms": 0,
                    }

                def transcribe_single_letter(self, audio, language=None):
                    from integrations.whisper_integration import _LETTER_CORRECTIONS
                    import re
                    res = self.transcribe(audio, language=language)
                    raw = res["text"].lower()
                    for phrase, letter in _LETTER_CORRECTIONS.items():
                        if phrase in raw:
                            return {"letter": letter, "confidence": res["confidence"]}
                    cleaned = re.sub(r"[^A-Za-z]", "", raw).upper()
                    return {"letter": cleaned[0] if cleaned else "", "confidence": res["confidence"]}

                def transcribe_direction(self, audio, language=None):
                    from integrations.whisper_integration import _DIRECTION_MAP
                    res = self.transcribe(audio, language=language)
                    raw = res["text"].lower()
                    for kw, direction in _DIRECTION_MAP.items():
                        if kw in raw:
                            return {"direction": direction, "confidence": res["confidence"]}
                    return {"direction": "", "confidence": 0.0}

            _whisper_integration = _BareWhisper()
            logger.info("Bare openai-whisper loaded as fallback ✓")
            return _whisper_integration
        except Exception as exc2:
            logger.error("Whisper completely unavailable: %s", exc2)
            return None


def _get_rnnoise():
    """
    Load RNNoiseIntegration (wraps compiled xiph/rnnoise via ctypes).
    Returns None silently if library not compiled.
    """
    global _rnnoise_integration, _rnnoise_unavailable
    if _rnnoise_unavailable:
        return None
    if _rnnoise_integration is not None:
        return _rnnoise_integration
    try:
        from integrations.rnnoise_integration import RNNoiseIntegration
        _rnnoise_integration = RNNoiseIntegration()
        logger.info("RNNoiseIntegration loaded ✓")
        return _rnnoise_integration
    except RuntimeError:
        # Library not compiled yet — silent skip
        _rnnoise_unavailable = True
        logger.debug("RNNoise library not compiled — audio passed raw to Whisper")
        return None
    except Exception as exc:
        _rnnoise_unavailable = True
        logger.warning("RNNoise load failed (%s)", exc)
        return None


# ══════════════════════════════════════════════════════════════════════════
# Internal helpers
# ══════════════════════════════════════════════════════════════════════════

def _read_audio(audio_bytes: bytes) -> tuple[np.ndarray, int]:
    """Read .wav bytes → (float32 numpy array, sample_rate)."""
    import soundfile as sf
    audio, sr = sf.read(io.BytesIO(audio_bytes), dtype="float32")
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    return audio, sr


def _apply_rnnoise(audio: np.ndarray, sr: int) -> np.ndarray:
    """
    Denoise audio with RNNoise (xiph/rnnoise).
    Returns original array if RNNoise unavailable or fails.
    """
    rnn = _get_rnnoise()
    if rnn is None:
        return audio
    try:
        return rnn.denoise_array(audio, sr)
    except Exception as exc:
        logger.warning("RNNoise denoise failed (%s) — using raw audio", exc)
        return audio


def _apply_vad_fallback(audio: np.ndarray, sr: int) -> np.ndarray:
    """WebRTC VAD fallback when RNNoise is unavailable."""
    try:
        import struct
        import webrtcvad
        vad            = webrtcvad.Vad(VAD_AGGRESSIVENESS)
        frame_samples  = int(sr * 0.02)   # 20 ms frames
        int16          = (audio * 32768).astype(np.int16)
        voiced = []
        for i in range(0, len(int16) - frame_samples, frame_samples):
            frame = int16[i: i + frame_samples]
            if vad.is_speech(struct.pack(f"{len(frame)}h", *frame), sr):
                voiced.append(frame)
        if not voiced:
            return audio
        return np.concatenate(voiced).astype(np.float32) / 32768.0
    except Exception:
        return audio


# ══════════════════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════════════════

def enroll_patient_voice(
    audio_bytes: bytes,
    session_id: str,
    redis_client=None,
) -> dict:
    """
    Extract MFCC voice fingerprint from 3-second audio.
    Stored in Redis under voice:<session_id> with 1-hour TTL.
    The raw audio is not persisted.
    """
    try:
        import librosa
        audio, sr = _read_audio(audio_bytes)
        mfcc      = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=20)
        fingerprint = mfcc.mean(axis=1).tolist()

        if redis_client:
            import json
            redis_client.setex(
                f"voice:{session_id}", 3600, json.dumps(fingerprint)
            )
        return {"success": True, "fingerprint_dims": len(fingerprint)}
    except Exception as exc:
        logger.error("Voice enrollment failed: %s", exc)
        return {"success": False, "reason": str(exc)}


def process_audio(
    audio_bytes: bytes,
    session_id: str,
    language: Optional[str] = None,
    mode: str = "letter",          # "letter" | "direction" | "free"
    redis_client=None,
) -> dict:
    """
    Full audio processing pipeline:

      1. Read .wav bytes
      2. RNNoise denoising (xiph/rnnoise)  — or VAD fallback
      3. Whisper transcription (ggerganov/whisper.cpp small weights)
      4. Post-process: letter correction / direction mapping

    Returns:
        {
          transcript: str,
          confidence: float,
          duration_ms: int,
          language: str,
          letter: str,       # if mode=="letter"
          direction: str,    # if mode=="direction"
          noise_reduced: bool,
          error: str | None,
        }
    """
    try:
        audio, sr     = _read_audio(audio_bytes)
        duration_ms   = int(len(audio) / sr * 1000)

        # ── Step 1: Noise suppression ────────────────────────────────────
        rnn = _get_rnnoise()
        if rnn is not None:
            audio = _apply_rnnoise(audio, sr)
            noise_reduced = True
        else:
            audio = _apply_vad_fallback(audio, sr)
            noise_reduced = False

        # ── Step 2: Transcription ────────────────────────────────────────
        whisper = _get_whisper()
        if whisper is None:
            return {
                "transcript": "", "confidence": 0.0,
                "duration_ms": duration_ms, "language": "unknown",
                "letter": "", "direction": "",
                "noise_reduced": noise_reduced,
                "error": "Whisper model not available",
            }

        # Resample to 16kHz (Whisper requirement)
        if sr != 16000:
            import librosa
            audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)

        base_result = whisper.transcribe(audio, language=language)

        # ── Step 3: Post-processing ──────────────────────────────────────
        letter    = ""
        direction = ""

        if mode == "letter":
            letter_result = whisper.transcribe_single_letter(audio, language=language)
            letter        = letter_result.get("letter", "")
        elif mode == "direction":
            dir_result = whisper.transcribe_direction(audio, language=language)
            direction  = dir_result.get("direction", "")

        return {
            "transcript":    base_result["text"],
            "confidence":    base_result["confidence"],
            "duration_ms":   duration_ms,
            "language":      base_result["language"],
            "letter":        letter,
            "direction":     direction,
            "noise_reduced": noise_reduced,
            "error":         None,
        }

    except Exception as exc:
        logger.error("Audio processing failed: %s", exc)
        return {
            "transcript": "", "confidence": 0.0,
            "duration_ms": 0, "language": "unknown",
            "letter": "", "direction": "",
            "noise_reduced": False,
            "error": str(exc),
        }


def analyze_response(
    transcript: str,
    expected: str,
    response_time_ms: int,
) -> dict:
    """
    Match transcribed response to expected Snellen letter.
    Flags hesitation if response_time_ms > 3000.
    """
    transcript_clean = transcript.strip().upper().replace(".", "").replace(",", "")
    expected_clean   = expected.strip().upper()

    is_correct = (
        transcript_clean == expected_clean
        or transcript_clean.startswith(expected_clean)
        or (len(transcript_clean) == 1 and transcript_clean == expected_clean[0])
    )

    hesitation_score = min(1.0, response_time_ms / (HESITATION_THRESHOLD_MS * 2))
    guessing         = response_time_ms > HESITATION_THRESHOLD_MS

    confidence = 0.95 if is_correct else 0.85
    if guessing:
        confidence -= 0.15

    return {
        "correct":          is_correct,
        "expected":         expected_clean,
        "heard":            transcript_clean,
        "response_time_ms": response_time_ms,
        "hesitation_score": round(hesitation_score, 3),
        "guessing_flag":    guessing,
        "confidence":       round(max(0.0, confidence), 3),
    }


def cleanup_session(session_id: str, redis_client=None) -> None:
    """
    Delete voice fingerprint from Redis.
    Raw audio is never stored — only text transcripts are persisted.
    """
    try:
        if redis_client:
            redis_client.delete(f"voice:{session_id}")
        logger.info("Voice session cleaned up: %s", session_id)
    except Exception as exc:
        logger.warning("Voice cleanup failed: %s", exc)


def integration_status() -> dict:
    """Return current status of both voice integrations (for /health endpoint)."""
    return {
        "whisper": {
            "loaded":     _whisper_integration is not None,
            "model_size": WHISPER_MODEL_SIZE,
            "repo":       "ggerganov/whisper.cpp (openai-whisper weights)",
        },
        "rnnoise": {
            "loaded":     _rnnoise_integration is not None,
            "unavailable": _rnnoise_unavailable,
            "repo":       "xiph/rnnoise (compiled C library)",
        },
    }
