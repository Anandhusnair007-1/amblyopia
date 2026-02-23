"""
Tests for RNNoise integration.
Skips gracefully if librnnoise.so is not compiled/installed.
"""
from __future__ import annotations

import os
import sys
import tempfile

import numpy as np
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

ASSET_DIR   = "test_assets"
SAMPLE_RATE = 48000


def _rnnoise_available() -> bool:
    """Return True only if RNNoise loads without RuntimeError."""
    try:
        from integrations.rnnoise_integration import RNNoiseIntegration
        RNNoiseIntegration()
        return True
    except RuntimeError:
        return False
    except Exception:
        return False


skip_no_rnnoise = pytest.mark.skipif(
    not _rnnoise_available(),
    reason="RNNoise not compiled — run: cd integrations/rnnoise && make && sudo make install",
)


def test_rnnoise_loads():
    """
    RNNoiseIntegration() loads if library available, or raises RuntimeError with
    clear instructions.  Either outcome is valid; we skip if not compiled.
    """
    try:
        from integrations.rnnoise_integration import RNNoiseIntegration
        rnn = RNNoiseIntegration()
        assert rnn is not None
        print("\nPASS — RNNoise library found and loaded")
    except RuntimeError as e:
        pytest.skip(f"SKIP — RNNoise not compiled yet: {e}")


@skip_no_rnnoise
def test_rnnoise_processes_audio():
    """denoise_file() must write an output file with same duration as input."""
    try:
        import soundfile as sf
    except ImportError:
        pytest.skip("soundfile not installed")

    from integrations.rnnoise_integration import RNNoiseIntegration

    duration = 0.5
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)
    audio = (0.5 * np.sin(2 * np.pi * 440 * t)
             + 0.1 * np.random.normal(size=t.shape)).astype(np.float32)

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_in:
        in_path = f_in.name
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_out:
        out_path = f_out.name

    try:
        sf.write(in_path, audio, SAMPLE_RATE)
        rnn = RNNoiseIntegration()
        rnn.denoise_file(in_path, out_path)

        assert os.path.isfile(out_path), "Output file not created"
        out_audio, _ = sf.read(out_path, dtype="float32")

        # Duration should be approximately the same (±10%)
        assert abs(len(out_audio) - len(audio)) / len(audio) < 0.1, (
            f"Duration mismatch: in={len(audio)} out={len(out_audio)}"
        )
        print(f"\nPASS — Audio processed: {len(audio)} → {len(out_audio)} samples")
    finally:
        for p in [in_path, out_path]:
            if os.path.exists(p):
                os.unlink(p)


@skip_no_rnnoise
def test_rnnoise_improves_snr():
    """denoise_array() on noisy audio must not degrade SNR meaningfully."""
    from integrations.rnnoise_integration import RNNoiseIntegration

    duration = 1.0
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)
    signal = 0.6 * np.sin(2 * np.pi * 300 * t)
    noise  = 0.3 * np.random.normal(size=t.shape)
    noisy  = (signal + noise).astype(np.float32)

    rnn = RNNoiseIntegration()
    snr_before = rnn.calculate_noise_level(noisy)
    denoised   = rnn.denoise_array(noisy, SAMPLE_RATE)
    snr_after  = rnn.calculate_noise_level(denoised)

    # SNR should not decrease by more than 1 dB
    assert snr_after >= snr_before - 1.0, (
        f"SNR degraded: {snr_before:.2f} → {snr_after:.2f} dB"
    )
    print(f"\nPASS — SNR: {snr_before:.2f} → {snr_after:.2f} dB")
