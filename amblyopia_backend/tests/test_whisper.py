"""
Tests for Whisper integration.
Skips gracefully if openai-whisper is not installed.
"""
from __future__ import annotations

import os
import sys
from unittest.mock import patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

ASSET_DIR = "test_assets"


def _whisper_available() -> bool:
    try:
        import whisper  # noqa
        return True
    except ImportError:
        return False


skip_no_whisper = pytest.mark.skipif(
    not _whisper_available(),
    reason="openai-whisper not installed — run: pip install openai-whisper",
)


@skip_no_whisper
def test_whisper_loads():
    """WhisperIntegration(model_size='tiny') must load without exception."""
    from integrations.whisper_integration import WhisperIntegration
    w = WhisperIntegration(model_size="tiny")
    assert w is not None
    assert w._model is not None
    print("\nPASS — Whisper loaded (tiny)")


@skip_no_whisper
def test_whisper_transcribes_audio():
    """Transcribing a sample .wav must return a non-empty result dict."""
    audio_path = os.path.join(ASSET_DIR, "sample_audio.wav")
    if not os.path.exists(audio_path):
        pytest.skip(f"Test asset missing: {audio_path}")

    from integrations.whisper_integration import WhisperIntegration
    w = WhisperIntegration(model_size="tiny")
    result = w.transcribe(audio_path)

    assert isinstance(result, dict)
    assert "text" in result
    assert "language" in result
    assert "confidence" in result
    assert "processing_time_ms" in result
    assert 0.0 <= result["confidence"] <= 1.0
    assert result["processing_time_ms"] > 0
    print(f"\nPASS — Transcription: '{result['text']}' lang={result['language']}")


# mock-based tests: whisper.cpp model install NOT required — we instantiate
# WhisperIntegration via __new__ (bypasses __init__) and patch transcribe().
def test_letter_correction():
    """transcribe_single_letter() must apply mishearing correction table."""
    # Direct import of the module — we don't need the whisper package for this
    try:
        from integrations.whisper_integration import WhisperIntegration
    except Exception as e:
        pytest.skip(f"Cannot import WhisperIntegration: {e}")

    w = WhisperIntegration.__new__(WhisperIntegration)

    test_cases = {
        "see":  "C",
        "are":  "R",
        "you":  "U",
        "why":  "Y",
        "tea":  "T",
        "pee":  "P",
        "be":   "B",
        "dee":  "D",
        "eff":  "F",
        "jay":  "J",
    }

    for phrase, expected_letter in test_cases.items():
        with patch.object(
            w, "transcribe",
            return_value={"text": phrase, "language": "en", "confidence": 0.9, "processing_time_ms": 10},
        ):
            result = w.transcribe_single_letter("fake_audio.wav")
            assert result["letter"] == expected_letter, (
                f"'{phrase}' → expected '{expected_letter}', got '{result['letter']}'"
            )

    print("\nPASS — Letter correction working for all 10 mishearing cases")


def test_direction_mapping():
    """transcribe_direction() must map spoken words to cardinal directions."""
    try:
        from integrations.whisper_integration import WhisperIntegration
    except Exception as e:
        pytest.skip(f"Cannot import WhisperIntegration: {e}")

    w = WhisperIntegration.__new__(WhisperIntegration)

    test_cases = {
        "above":  "up",
        "below":  "down",
        "up":     "up",
        "down":   "down",
        "left":   "left",
        "right":  "right",
    }

    for phrase, expected_dir in test_cases.items():
        with patch.object(
            w, "transcribe",
            return_value={"text": phrase, "language": "en", "confidence": 0.9, "processing_time_ms": 5},
        ):
            result = w.transcribe_direction("fake_audio.wav")
            assert result["direction"] == expected_dir, (
                f"'{phrase}' → expected '{expected_dir}', got '{result['direction']}'"
            )

    print("\nPASS — Direction mapping working for 6 direction words")



@skip_no_whisper
def test_whisper_detects_language():
    """Language field in transcribe() result must be a valid ISO code."""
    audio_path = os.path.join(ASSET_DIR, "sample_audio.wav")
    if not os.path.exists(audio_path):
        pytest.skip(f"Test asset missing: {audio_path}")

    from integrations.whisper_integration import WhisperIntegration
    w = WhisperIntegration(model_size="tiny")
    result = w.transcribe(audio_path)

    # Sine wave may produce any language — just verify field is present
    assert result["language"] != ""
    assert len(result["language"]) in (2, 3)  # ISO 639-1 or 639-2
    print(f"\nPASS — Language detection working: detected '{result['language']}'")
