"""
Whisper Integration — Amblyopia Care System
============================================
Multi-language speech-to-text for Snellen voicing tests.
Wraps OpenAI Whisper for Tamil / Malayalam / English responses.
"""
from __future__ import annotations

import logging
import os
import re
import time
from typing import Dict, Optional, Union

import numpy as np

logger = logging.getLogger(__name__)

# ── Letter mishearing corrections ────────────────────────────────────────────
_LETTER_CORRECTIONS: Dict[str, str] = {
    "see":   "C", "sea":   "C",
    "are":   "R",
    "you":   "U", "eew":   "U",
    "why":   "Y",
    "tea":   "T", "tee":   "T",
    "pee":   "P",
    "be":    "B", "bee":   "B",
    "dee":   "D",
    "eff":   "F",
    "jay":   "J", "jae":   "J",
    "aye":   "A",
    "eye":   "I", "hi":    "H",
    "que":   "Q", "cue":   "Q",
    "ex":    "X",
    "kay":   "K",
    "em":    "M", "en":    "N",
    "oh":    "O",
    "el":    "L",
    "gee":   "G",
    "wye":   "Y",
    "vee":   "V",
    "zee":   "Z", "zed":   "Z",
    "double you": "W",
}

# ── Direction word mapping (incl. Tamil) ─────────────────────────────────────
_DIRECTION_MAP: Dict[str, str] = {
    # English
    "up":      "up",   "above":    "up",   "top":    "up",   "upward":  "up",
    "down":    "down", "below":    "down", "bottom": "down", "downward": "down",
    "left":    "left", "leftward": "left",
    "right":   "right","rightward":"right",
    # Tamil transliterations
    "மேலே":   "up",   "மேல":    "up",    "கீழே":  "down",
    "கீழ":    "down", "இடது":   "left",  "வலது":  "right",
    # Malayalam
    "മുകളിൽ": "up",  "താഴെ":   "down",  "ഇടത്ത്": "left",  "വലത്ത്": "right",
}


class WhisperIntegration:
    """
    OpenAI Whisper wrapper for Snellen voicing tests.

    Supports Tamil, Malayalam, English auto-detection.
    Provides letter correction and direction mapping post-processors.

    Usage:
        w = WhisperIntegration(model_size='small')
        result = w.transcribe('audio.wav')
        letter = w.transcribe_single_letter('audio.wav')
    """

    def __init__(self, model_size: str = "small") -> None:
        valid = {"tiny", "base", "small", "medium", "large"}
        if model_size not in valid:
            raise ValueError(f"model_size must be one of {valid}, got '{model_size}'")

        try:
            import whisper as _whisper  # type: ignore
            self._whisper = _whisper
        except ImportError as e:
            raise ImportError(
                f"openai-whisper not installed: {e}\n"
                f"Run: pip install openai-whisper"
            ) from e

        logger.info("Loading Whisper model '%s' (this may take a moment)...", model_size)
        self._model = _whisper.load_model(model_size)
        self._model_size = model_size

        # Log approximate model size
        param_count = sum(p.numel() for p in self._model.parameters())
        logger.info(
            "Whisper '%s' loaded — %.1fM parameters", model_size, param_count / 1e6
        )

    def transcribe(
        self,
        audio: Union[str, np.ndarray],
        language: Optional[str] = None,
        sample_rate: int = 16000,
    ) -> Dict:
        """
        Transcribe audio file or numpy array.

        Args:
            audio:       .wav file path or float32 numpy array at 16kHz.
            language:    ISO code e.g. 'ta', 'ml', 'en'. None = auto detect.
            sample_rate: Only used when audio is numpy array.

        Returns:
            {
              "text": str,
              "language": str,
              "confidence": float,       # average log-prob
              "processing_time_ms": float
            }
        """
        t0 = time.perf_counter()

        decode_options: Dict = {}
        if language:
            decode_options["language"] = language

        if isinstance(audio, np.ndarray):
            audio = self._prepare_array(audio, sample_rate)

        result = self._model.transcribe(
            audio,
            **decode_options,
            fp16=False,
            verbose=False,
        )

        # Average log-probability → confidence proxy
        segs = result.get("segments", [])
        if segs:
            avg_lp = float(np.mean([s.get("avg_logprob", -1.0) for s in segs]))
        else:
            avg_lp = -1.0
        confidence = float(np.clip(np.exp(avg_lp), 0.0, 1.0))

        elapsed_ms = (time.perf_counter() - t0) * 1000
        logger.info(
            "Whisper transcribed [%s]: '%s' (conf=%.2f, %.0fms)",
            result.get("language", "?"), result["text"].strip(), confidence, elapsed_ms,
        )

        return {
            "text": result["text"].strip(),
            "language": result.get("language", "en"),
            "confidence": round(confidence, 4),
            "processing_time_ms": round(elapsed_ms, 1),
        }

    def transcribe_single_letter(
        self,
        audio: Union[str, np.ndarray],
        language: Optional[str] = None,
    ) -> Dict:
        """
        Transcribe and extract a single Snellen letter.

        Returns:
            {"letter": "E", "confidence": 0.93}
        """
        result = self.transcribe(audio, language=language)
        raw = result["text"].strip().lower()

        # Check corrections table first
        for phrase, letter in _LETTER_CORRECTIONS.items():
            if phrase in raw:
                return {"letter": letter, "confidence": result["confidence"]}

        # Extract first uppercase letter in raw output
        cleaned = re.sub(r"[^A-Za-z]", "", raw).upper()
        if cleaned:
            return {"letter": cleaned[0], "confidence": result["confidence"]}

        return {"letter": "", "confidence": 0.0}

    def transcribe_direction(
        self,
        audio: Union[str, np.ndarray],
        language: Optional[str] = None,
    ) -> Dict:
        """
        Transcribe and map to a cardinal direction for Tumbling-E chart.

        Returns:
            {"direction": "up", "confidence": 0.88}
        """
        result = self.transcribe(audio, language=language)
        raw = result["text"].strip().lower()

        for keyword, direction in _DIRECTION_MAP.items():
            if keyword in raw:
                return {"direction": direction, "confidence": result["confidence"]}

        return {"direction": "", "confidence": 0.0}

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Transcribe sample_audio.wav, return True if non-empty text produced.
        """
        audio_path = os.path.join(asset_dir, "sample_audio.wav")
        if not os.path.exists(audio_path):
            logger.error("Test asset not found: %s", audio_path)
            return False

        result = self.transcribe(audio_path)
        print(f"  Whisper test:")
        print(f"    Language detected: {result['language']}")
        print(f"    Transcription:     '{result['text']}'")
        print(f"    Confidence:        {result['confidence']:.3f}")
        print(f"    Time:              {result['processing_time_ms']:.0f}ms")

        return len(result["text"]) > 0

    # ── Helpers ─────────────────────────────────────────────────────────────

    def _prepare_array(self, audio: np.ndarray, sample_rate: int) -> np.ndarray:
        """Resample to 16kHz mono float32 as required by Whisper."""
        import librosa  # type: ignore
        if audio.dtype != np.float32:
            audio = audio.astype(np.float32)
        if sample_rate != 16000:
            audio = librosa.resample(audio, orig_sr=sample_rate, target_sr=16000)
        if audio.ndim > 1:
            audio = audio.mean(axis=0)
        return audio
