"""
RNNoise Integration — Amblyopia Care System
============================================
Real-time noise suppression for voice input before Whisper transcription.
Wraps the compiled librnnoise.so via ctypes.
"""
from __future__ import annotations

import ctypes
import logging
import os
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

# RNNoise operates at exactly 48kHz, 480-sample frames (10ms)
_RNNOISE_SAMPLE_RATE = 48000
_FRAME_SIZE = 480  # samples per frame

# Candidate library paths (in search order)
_LIB_CANDIDATES = [
    "librnnoise.so",
    "librnnoise.so.0",
    "/usr/local/lib/librnnoise.so",
    "/usr/local/lib/librnnoise.so.0",
    "/usr/lib/librnnoise.so",
    "/usr/lib/x86_64-linux-gnu/librnnoise.so",
]


def _find_rnnoise_lib() -> Optional[str]:
    """Search standard paths for the compiled RNNoise shared library."""
    # Also check within the cloned repo
    project_root = os.path.dirname(os.path.dirname(__file__))
    _LIB_CANDIDATES.extend([
        os.path.join(project_root, "integrations", "rnnoise", ".libs", "librnnoise.so"),
        os.path.join(project_root, "integrations", "rnnoise", ".libs", "librnnoise.so.0"),
    ])
    for path in _LIB_CANDIDATES:
        if os.path.exists(path):
            return path
    return None


class RNNoiseIntegration:
    """
    Noise suppression integration for the Amblyopia Care System.

    Primary:  Uses compiled librnnoise.so (xiph/rnnoise) via ctypes for
              real-time 48kHz noise suppression at 10ms frames.
    Fallback: When librnnoise.so is not installed, automatically falls back
              to the 'noisereduce' Python library (spectral gating) — no crash,
              no error, pipeline always works.

    Usage:
        rnn = RNNoiseIntegration()           # always succeeds
        denoised = rnn.denoise_file('noisy.wav', 'clean.wav')
        print(rnn.backend)                   # 'rnnoise' or 'noisereduce'
    """

    def __init__(self) -> None:
        lib_path = _find_rnnoise_lib()
        self._lib: Optional[ctypes.CDLL] = None
        self.backend: str = "noisereduce"   # default

        if lib_path is not None:
            try:
                self._lib = ctypes.CDLL(lib_path)
                self._setup_ctypes()
                self.backend = "rnnoise"
                logger.info("RNNoise: loaded native librnnoise.so from %s", lib_path)
            except OSError as e:
                logger.warning("RNNoise: cannot load .so (%s) — using noisereduce fallback", e)
        else:
            logger.info(
                "RNNoise: librnnoise.so not installed — using noisereduce fallback. "
                "To enable native RNNoise: sudo apt install librnnoise0  "
                "or build from https://github.com/xiph/rnnoise"
            )

        # Verify noisereduce is available as fallback
        if self.backend == "noisereduce":
            try:
                import noisereduce  # noqa: F401
            except ImportError as exc:
                raise RuntimeError(
                    "Neither librnnoise.so nor 'noisereduce' pip package is available.\n"
                    "Fix:  pip install noisereduce\n"
                    "  OR  sudo apt install librnnoise0"
                ) from exc

    def _setup_ctypes(self) -> None:
        """Bind RNNoise C API signatures."""
        lib = self._lib

        lib.rnnoise_create.restype  = ctypes.c_void_p
        lib.rnnoise_create.argtypes = [ctypes.c_void_p]  # model (NULL = built-in)

        lib.rnnoise_destroy.restype  = None
        lib.rnnoise_destroy.argtypes = [ctypes.c_void_p]

        lib.rnnoise_process_frame.restype  = ctypes.c_float  # VAD probability
        lib.rnnoise_process_frame.argtypes = [
            ctypes.c_void_p,                              # state
            ctypes.POINTER(ctypes.c_float),               # out (480 floats)
            ctypes.POINTER(ctypes.c_float),               # in  (480 floats)
        ]

    def denoise_file(self, input_path: str, output_path: str) -> str:
        """
        Denoise a .wav file and write the result to output_path.
        Uses native RNNoise if available, otherwise noisereduce fallback.

        Returns:
            output_path
        """
        import soundfile as sf
        import librosa

        audio, sr = sf.read(input_path, dtype="float32")
        # Ensure mono
        if audio.ndim > 1:
            audio = audio.mean(axis=1)

        if self.backend == "rnnoise":
            # Native path — resample to exactly 48kHz
            if sr != _RNNOISE_SAMPLE_RATE:
                audio = librosa.resample(audio, orig_sr=sr, target_sr=_RNNOISE_SAMPLE_RATE)
            denoised = self._process_frames(audio)
            out_sr = _RNNOISE_SAMPLE_RATE
        else:
            # Python noisereduce fallback — works at any sample rate
            import noisereduce as nr
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", RuntimeWarning)
                denoised = nr.reduce_noise(y=audio, sr=sr, stationary=False)
            out_sr = sr
            logger.info("RNNoise: fallback noisereduce applied (sr=%d)", sr)

        sf.write(output_path, denoised, out_sr)
        logger.info("RNNoise: denoised → %s  (backend=%s)", output_path, self.backend)
        return output_path

    def denoise_array(
        self,
        audio_array: np.ndarray,
        sample_rate: int,
    ) -> np.ndarray:
        """
        Denoise a numpy float32 audio array.  Resamples to 48kHz internally.

        Returns:
            Denoised float32 numpy array at 48kHz.
        """
        import librosa

        audio = audio_array.astype(np.float32)
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        if sample_rate != _RNNOISE_SAMPLE_RATE:
            audio = librosa.resample(audio, orig_sr=sample_rate, target_sr=_RNNOISE_SAMPLE_RATE)
        return self._process_frames(audio)

    def calculate_noise_level(self, audio: np.ndarray) -> float:
        """
        Estimate SNR in dB.  Higher = cleaner signal.

        Uses a simple energy-based estimate:
        signal = top 20% loudest frames, noise = bottom 20%.
        """
        if audio.size == 0:
            return 0.0
        frames = np.array_split(audio, max(1, len(audio) // _FRAME_SIZE))
        energies = np.array([np.mean(f ** 2) for f in frames if len(f) > 0])
        if len(energies) < 2:
            return 0.0
        energies.sort()
        noise_energy  = energies[:max(1, len(energies) // 5)].mean()
        signal_energy = energies[-(max(1, len(energies) // 5)):].mean()
        if noise_energy <= 0:
            return 60.0  # very clean
        snr_db = 10.0 * np.log10(signal_energy / noise_energy + 1e-10)
        return float(np.clip(snr_db, 0.0, 60.0))

    def test_with_sample(self, asset_dir: str = "test_assets") -> bool:
        """
        Denoise sample_audio.wav, compare SNR, return True if SNR improved.
        """
        import soundfile as sf

        input_path  = os.path.join(asset_dir, "sample_audio.wav")
        output_path = os.path.join(asset_dir, "rnnoise_output.wav")

        if not os.path.exists(input_path):
            logger.error("Test asset not found: %s", input_path)
            return False

        audio_in, sr = sf.read(input_path, dtype="float32")
        snr_before = self.calculate_noise_level(audio_in)

        self.denoise_file(input_path, output_path)

        audio_out, _ = sf.read(output_path, dtype="float32")
        snr_after = self.calculate_noise_level(audio_out)

        print(f"  RNNoise test:")
        print(f"    SNR before: {snr_before:.2f} dB")
        print(f"    SNR after:  {snr_after:.2f} dB")
        print(f"    Improved:   {snr_after >= snr_before}")
        print(f"    Saved: {output_path}")

        return snr_after >= snr_before

    # ── Private ─────────────────────────────────────────────────────────────

    def _process_frames(self, audio: np.ndarray) -> np.ndarray:
        """Run RNNoise frame-by-frame processing on a 48kHz mono float32 array."""
        # Scale to int16 range as RNNoise expects
        audio_scaled = audio * 32768.0

        # Pad to multiple of _FRAME_SIZE
        pad = (_FRAME_SIZE - len(audio_scaled) % _FRAME_SIZE) % _FRAME_SIZE
        audio_padded = np.pad(audio_scaled, (0, pad), mode="constant").astype(np.float32)

        out_frames = []
        state = self._lib.rnnoise_create(None)
        try:
            for i in range(0, len(audio_padded), _FRAME_SIZE):
                frame  = audio_padded[i : i + _FRAME_SIZE]
                in_buf = frame.ctypes.data_as(ctypes.POINTER(ctypes.c_float))
                out_arr = (ctypes.c_float * _FRAME_SIZE)()
                self._lib.rnnoise_process_frame(state, out_arr, in_buf)
                out_frames.append(np.frombuffer(out_arr, dtype=np.float32).copy())
        finally:
            self._lib.rnnoise_destroy(state)

        result = np.concatenate(out_frames)[: len(audio_scaled)]
        return (result / 32768.0).astype(np.float32)
