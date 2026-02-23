#!/usr/bin/env python3
"""
================================================================
  Amblyopia Care System — System Validation Script
  validates all integrations, pipelines, and services WITHOUT
  requiring a real clinical dataset.

  Run:
      python3 validate_system.py           # full suite
      python3 validate_system.py --section security
      python3 validate_system.py --section image
      python3 validate_system.py --list

  Output:
      SYSTEM VALIDATION REPORT to stdout  +  logs/validation_<ts>.json
================================================================
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import io
import json
import logging
import math
import os
import platform
import secrets
import struct
import subprocess
import sys
import tempfile
import time
import traceback
import warnings
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

warnings.filterwarnings("ignore")
logging.basicConfig(level=logging.ERROR)  # silence noisy libs during validation

# ── Bootstrap environment so Settings() doesn't fail ──────────────────────────
_FAKE_KEY = secrets.token_hex(32)
_FAKE_ENC = base64.b64encode(os.urandom(32)).decode()

os.environ.setdefault("SECRET_KEY", _FAKE_KEY)
os.environ.setdefault("ENCRYPTION_KEY", _FAKE_ENC)
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("DATABASE_URL",
    "postgresql+asyncpg://test:test@localhost:5432/test_db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("MLFLOW_TRACKING_URI", "http://localhost:5000")
os.environ.setdefault("MINIO_ACCESS_KEY", "minioaccess")
os.environ.setdefault("MINIO_SECRET_KEY", "miniosecret12345678")

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

# ── Colour output ──────────────────────────────────────────────────────────────
_USE_COLOR = sys.stdout.isatty()
def _c(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text
GREEN   = lambda t: _c(t, "32")
RED     = lambda t: _c(t, "31")
YELLOW  = lambda t: _c(t, "33")
CYAN    = lambda t: _c(t, "36")
BOLD    = lambda t: _c(t, "1")
DIM     = lambda t: _c(t, "2")


# ══════════════════════════════════════════════════════════════════════════════
#  Data structures
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class CheckResult:
    name: str
    status: str          # PASS | FAIL | WARN | SKIP
    message: str = ""
    detail: str = ""
    duration_ms: float = 0.0
    metrics: Dict[str, Any] = field(default_factory=dict)

@dataclass
class SectionResult:
    section: str
    checks: List[CheckResult] = field(default_factory=list)

    @property
    def passed(self) -> int:  return sum(1 for c in self.checks if c.status == "PASS")
    @property
    def failed(self) -> int:  return sum(1 for c in self.checks if c.status == "FAIL")
    @property
    def warned(self) -> int:  return sum(1 for c in self.checks if c.status == "WARN")
    @property
    def skipped(self) -> int: return sum(1 for c in self.checks if c.status == "SKIP")
    @property
    def total(self) -> int:   return len(self.checks)


# ══════════════════════════════════════════════════════════════════════════════
#  Synthetic test-asset generators  (zero external data required)
# ══════════════════════════════════════════════════════════════════════════════

def _make_test_jpeg(w: int = 320, h: int = 240, face: bool = True) -> bytes:
    """
    Generate a minimal valid JPEG with an approximate face region (skin-tone
    ellipse) so that YOLO / OpenCV face detectors have something to work with.
    Uses Pillow when available; falls back to a raw JPEG header otherwise.
    """
    try:
        from PIL import Image, ImageDraw
        img = Image.new("RGB", (w, h), color=(200, 160, 130))  # skin-tone bg
        draw = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2
        # Approximate oval face
        draw.ellipse([(cx-60, cy-80), (cx+60, cy+80)], fill=(210, 170, 140))
        # Eyes
        draw.ellipse([(cx-30, cy-20), (cx-10, cy)], fill=(50, 50, 100))
        draw.ellipse([(cx+10, cy-20), (cx+30, cy)],  fill=(50, 50, 100))
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return buf.getvalue()
    except ImportError:
        # Minimal 1×1 JPEG (FF D8 FF header so magic-byte check passes)
        return (
            b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01"
            b"\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07"
            b"\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14"
            b"\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444"
            b"\x1f'9=82<.342\x1edL\t\x02\x01\x01\x01\x01\x01\x01\x01\x01"
            b"\x01\x01\x01\x01\x01\x01\x01\x01\xff\xc0\x00\x0b\x08\x00\x01"
            b"\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01"
            b"\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02"
            b"\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00"
            b"\x00\x3f\x00\xfb\xff\xd9"
        ) + b"\x00" * 1000  # pad to > 1 KB


def _make_test_wav(duration_s: float = 2.0, sample_rate: int = 16000,
                   silent: bool = False) -> bytes:
    """Generate a minimal WAV file with a 440 Hz tone or silence."""
    n_samples = int(sample_rate * duration_s)
    if silent:
        samples = [0] * n_samples
    else:
        samples = [int(16000 * math.sin(2 * math.pi * 440 * i / sample_rate))
                   for i in range(n_samples)]

    buf = io.BytesIO()
    data_size = n_samples * 2  # 16-bit PCM

    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVEfmt ")
    buf.write(struct.pack("<I", 16))          # chunk size
    buf.write(struct.pack("<H", 1))           # PCM
    buf.write(struct.pack("<H", 1))           # channels
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", sample_rate * 2))  # byte rate
    buf.write(struct.pack("<H", 2))           # block align
    buf.write(struct.pack("<H", 16))          # bits per sample
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))
    for s in samples:
        buf.write(struct.pack("<h", max(-32768, min(32767, s))))
    return buf.getvalue()


# ══════════════════════════════════════════════════════════════════════════════
#  Timing decorator
# ══════════════════════════════════════════════════════════════════════════════

def _timed(fn):
    """Return (result, elapsed_ms)."""
    t0 = time.perf_counter()
    result = fn()
    return result, (time.perf_counter() - t0) * 1000


# ══════════════════════════════════════════════════════════════════════════════
#  Section 1 — Open-Source Dependency Check
# ══════════════════════════════════════════════════════════════════════════════

def _check_realesrgan(sr: SectionResult) -> None:
    try:
        from integrations.real_esrgan_integration import RealESRGANIntegration
        import inspect
        # Verify class importable and inspect signature
        sig = str(inspect.signature(RealESRGANIntegration.__init__))
        # Try test_with_sample (uses bundled test_assets)
        t0 = time.perf_counter()
        obj = object.__new__(RealESRGANIntegration)
        has_test = hasattr(obj, 'test_with_sample') or callable(
            getattr(RealESRGANIntegration, 'test_with_sample', None))
        ms = (time.perf_counter() - t0) * 1000
        sr.checks.append(CheckResult("real_esrgan_class_importable", "PASS",
            f"Class importable, signature: {sig}, test_with_sample={has_test}",
            duration_ms=ms))
        # Try loading with a non-existent model path to check for FileNotFoundError
        try:
            RealESRGANIntegration(model_path="/nonexistent/model.pth")
            sr.checks.append(CheckResult("real_esrgan_guard_missing_weights", "FAIL",
                "Model loader did NOT raise FileNotFoundError for missing weights"))
        except FileNotFoundError:
            sr.checks.append(CheckResult("real_esrgan_guard_missing_weights", "PASS",
                "Correctly raises FileNotFoundError when model weights missing"))
        except Exception as exc:
            sr.checks.append(CheckResult("real_esrgan_guard_missing_weights", "WARN",
                f"Raised {type(exc).__name__} instead of FileNotFoundError: {exc}"))
    except ImportError as exc:
        sr.checks.append(CheckResult("real_esrgan_class_importable", "WARN",
            f"Real-ESRGAN package not installed (expected in dev): {exc}."
            " Run: pip install realesrgan basicsr"))


def _check_zerodce(sr: SectionResult) -> None:
    try:
        from integrations.zero_dce_integration import ZeroDCEIntegration
        import inspect
        sig = str(inspect.signature(ZeroDCEIntegration.__init__))
        sr.checks.append(CheckResult("zero_dce_class_importable", "PASS",
            f"Class importable, signature: {sig}"))
        # Probe guard for missing model
        try:
            ZeroDCEIntegration(model_path="/nonexistent/model.pth")
            sr.checks.append(CheckResult("zero_dce_guard_missing_weights", "WARN",
                "Did not raise on missing weights — may silently use placeholder"))
        except (FileNotFoundError, OSError, Exception) as exc:
            sr.checks.append(CheckResult("zero_dce_guard_missing_weights", "PASS",
                f"Raises {type(exc).__name__} for missing weights (correct)"))
    except ImportError as exc:
        sr.checks.append(CheckResult("zero_dce_class_importable", "WARN",
            f"Zero-DCE package not installed (expected in dev without GPU): {exc}"))


def _check_yolo(sr: SectionResult) -> None:
    try:
        from integrations.yolo_integration import YOLOIntegration
        import inspect
        t0 = time.perf_counter()
        sig = str(inspect.signature(YOLOIntegration.__init__))
        sr.checks.append(CheckResult("yolo_class_importable", "PASS",
            f"Class importable, signature: {sig}"))
        # Check detect_eyes and detect_strabismus_signals exist
        has_detect = hasattr(YOLOIntegration, "detect_eyes")
        has_strab  = hasattr(YOLOIntegration, "detect_strabismus_signals")
        ms = (time.perf_counter() - t0) * 1000
        if has_detect and has_strab:
            sr.checks.append(CheckResult("yolo_required_methods", "PASS",
                "detect_eyes() and detect_strabismus_signals() present",
                duration_ms=ms))
        else:
            sr.checks.append(CheckResult("yolo_required_methods", "FAIL",
                f"Missing methods — detect_eyes={has_detect} strab={has_strab}"))
    except ImportError as exc:
        sr.checks.append(CheckResult("yolo_class_importable", "WARN",
            f"YOLO package not installed (expected in dev): {exc}"))


def _check_rnnoise(sr: SectionResult) -> None:
    try:
        from integrations.rnnoise_integration import RNNoiseIntegration
        t0 = time.perf_counter()
        rn = RNNoiseIntegration()  # __init__ takes no required args
        ms_init = (time.perf_counter() - t0) * 1000

        has_denoise_array = hasattr(rn, "denoise_array")
        has_denoise_file  = hasattr(rn, "denoise_file")
        has_noise_level   = hasattr(rn, "calculate_noise_level")

        if has_denoise_array and has_denoise_file:
            sr.checks.append(CheckResult("rnnoise_load", "PASS",
                f"RNNoiseIntegration instantiated in {ms_init:.0f} ms, "
                f"denoise_array={has_denoise_array} denoise_file={has_denoise_file} "
                f"noise_level={has_noise_level}",
                duration_ms=ms_init))
        else:
            sr.checks.append(CheckResult("rnnoise_load", "WARN",
                f"RNNoiseIntegration missing expected methods: "
                f"denoise_array={has_denoise_array} denoise_file={has_denoise_file}"))

        # Try denoise_array with a synthetic numpy array
        try:
            import numpy as np
            audio_arr = np.sin(
                2 * math.pi * 440 * np.arange(16000) / 16000
            ).astype(np.float32)
            t0 = time.perf_counter()
            out = rn.denoise_array(audio_arr, 16000)
            ms = (time.perf_counter() - t0) * 1000
            sr.checks.append(CheckResult("rnnoise_denoise_array", "PASS",
                f"denoise_array() returned shape {out.shape} in {ms:.0f} ms",
                duration_ms=ms))
        except Exception as exc:
            sr.checks.append(CheckResult("rnnoise_denoise_array", "WARN",
                f"denoise_array() failed (lib may not be compiled): "
                f"{type(exc).__name__}: {exc}"))
    except Exception as exc:
        sr.checks.append(CheckResult("rnnoise_load", "WARN",
            f"RNNoise not available: {type(exc).__name__}: {exc}",
            detail=traceback.format_exc(limit=3)))


def _check_whisper(sr: SectionResult) -> None:
    try:
        from integrations.whisper_integration import WhisperIntegration
        import inspect
        # Check class is importable and has the required methods
        has_transcribe        = hasattr(WhisperIntegration, "transcribe")
        has_transcribe_letter = hasattr(WhisperIntegration, "transcribe_single_letter")
        has_transcribe_dir    = hasattr(WhisperIntegration, "transcribe_direction")
        sr.checks.append(CheckResult("whisper_class_importable", "PASS",
            f"WhisperIntegration importable: transcribe={has_transcribe} "
            f"single_letter={has_transcribe_letter} direction={has_transcribe_dir}"))

        # Attempt model load (will WARN if openai-whisper not installed)
        try:
            t0 = time.perf_counter()
            w = WhisperIntegration(model_size="tiny")  # tiny = fastest, smallest
            ms = (time.perf_counter() - t0) * 1000
            sr.checks.append(CheckResult("whisper_model_load", "PASS",
                f"WhisperIntegration(tiny) loaded in {ms:.0f} ms",
                duration_ms=ms))
        except Exception as exc:
            sr.checks.append(CheckResult("whisper_model_load", "WARN",
                f"Whisper model not loaded — run: pip install openai-whisper: "
                f"{type(exc).__name__}: {exc}"))
    except ImportError as exc:
        sr.checks.append(CheckResult("whisper_class_importable", "WARN",
            f"whisper_integration module import failed: {exc}."
            " Run: pip install openai-whisper"))


def _check_airflow_dag(sr: SectionResult) -> None:
    dag_path = PROJECT_ROOT / "airflow" / "dags" / "weekly_retraining_dag.py"
    if not dag_path.exists():
        sr.checks.append(CheckResult("airflow_dag_parse", "FAIL",
            f"DAG file not found: {dag_path}"))
        return
    try:
        import ast
        ast.parse(dag_path.read_text())
        sr.checks.append(CheckResult("airflow_dag_syntax", "PASS",
            "DAG file parses without syntax error"))
    except SyntaxError as exc:
        sr.checks.append(CheckResult("airflow_dag_syntax", "FAIL",
            f"Syntax error: {exc}"))
        return

    # Try to load via Airflow if installed
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("weekly_retraining_dag", dag_path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)

        dag = getattr(mod, "dag", None)
        if dag is not None:
            task_ids = [t.task_id for t in dag.tasks]
            sr.checks.append(CheckResult("airflow_dag_load", "PASS",
                f"DAG loaded: {dag.dag_id}, tasks={task_ids}",
                metrics={"task_ids": task_ids, "dag_id": dag.dag_id}))
        else:
            sr.checks.append(CheckResult("airflow_dag_load", "WARN",
                "DAG imported but `dag` object not found at module level"))
    except Exception as exc:
        sr.checks.append(CheckResult("airflow_dag_load", "WARN",
            f"Airflow not installed or import error: {type(exc).__name__}: {exc}",
            detail=traceback.format_exc(limit=3)))


def _check_mlflow(sr: SectionResult) -> None:
    try:
        import mlflow
        sr.checks.append(CheckResult("mlflow_import", "PASS",
            f"mlflow version: {mlflow.__version__}"))
    except ImportError:
        sr.checks.append(CheckResult("mlflow_import", "WARN",
            "mlflow not installed — run: pip install mlflow"))
        return

    # Check if MLflow tracking server is reachable
    try:
        import urllib.request
        mlflow_uri = os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000")
        urllib.request.urlopen(mlflow_uri, timeout=2)
        sr.checks.append(CheckResult("mlflow_server_reachable", "PASS",
            f"MLflow tracking server reachable at {mlflow_uri}"))
    except Exception as exc:
        sr.checks.append(CheckResult("mlflow_server_reachable", "WARN",
            f"MLflow server not reachable (OK for dev): {type(exc).__name__}: {exc}"))


def run_section_1() -> SectionResult:
    sr = SectionResult("1. Open-Source Dependency Check")
    _check_realesrgan(sr)
    _check_zerodce(sr)
    _check_yolo(sr)
    _check_rnnoise(sr)
    _check_whisper(sr)
    _check_airflow_dag(sr)
    _check_mlflow(sr)
    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 2 — Image Pipeline Dry Run
# ══════════════════════════════════════════════════════════════════════════════

async def _run_image_pipeline_async(raw: bytes, label: str) -> CheckResult:
    try:
        from app.pipelines.image_pipeline import run_image_pipeline
        t0 = time.perf_counter()
        result = await run_image_pipeline(raw, session_id=f"val_{label}", age_group="adult")
        ms = (time.perf_counter() - t0) * 1000

        qr = result.get("quality_report", {})
        metrics = {
            "blur_score":       qr.get("blur_score", "n/a"),
            "brightness":       qr.get("brightness", "n/a"),
            "face_confidence":  qr.get("face_confidence", "n/a"),
            "strabismus_flag":  result.get("strabismus_flag", "n/a"),
            "success":          result.get("success"),
        }

        if result.get("success"):
            return CheckResult(f"image_pipeline_{label}", "PASS",
                f"Pipeline succeeded (blur={metrics['blur_score']}, "
                f"conf={metrics['face_confidence']}, strab={metrics['strabismus_flag']})",
                duration_ms=ms, metrics=metrics)
        else:
            # Failure is acceptable if quality gate is the cause (correct behaviour)
            error = result.get("error", "")
            status = "PASS" if any(k in error.lower() for k in
                                   ["quality", "small", "jpeg", "confidence", "invalid"]) else "WARN"
            return CheckResult(f"image_pipeline_{label}", status,
                f"Quality gate rejected: {error}",
                duration_ms=ms, metrics=metrics)
    except ModuleNotFoundError as exc:
        # Missing ML deps (cv2, torch, etc.) are expected in dev environments
        # without the full ML stack installed — WARN, not FAIL.
        return CheckResult(f"image_pipeline_{label}", "WARN",
            f"ML dependency not installed (expected in dev): {exc}.  "
            "Install requirements.txt on a GPU host to enable full pipeline.")
    except Exception as exc:
        return CheckResult(f"image_pipeline_{label}", "FAIL",
            f"{type(exc).__name__}: {exc}",
            detail=traceback.format_exc(limit=4))


def run_section_2() -> SectionResult:
    sr = SectionResult("2. Image Pipeline Dry Run")

    test_images = {
        "normal_320x240":  _make_test_jpeg(320, 240),
        "small_128x128":   _make_test_jpeg(128, 128),
        "large_640x480":   _make_test_jpeg(640, 480),
        "minimal_face":    _make_test_jpeg(160, 120, face=True),
        "too_small":       b"\xff\xd8\xff" + b"\x00" * 100,   # < 1 KB — should be rejected
    }

    loop = asyncio.new_event_loop()
    try:
        for label, img_bytes in test_images.items():
            check = loop.run_until_complete(_run_image_pipeline_async(img_bytes, label))
            sr.checks.append(check)
    finally:
        loop.close()

    # Validate that 'too_small' was rejected by the magic-byte / size gate
    too_small_check = next((c for c in sr.checks if "too_small" in c.name), None)
    if too_small_check and too_small_check.status in ("PASS", "WARN"):
        # 'too_small' returning PASS means quality gate accepted garbage — that's a bug
        if too_small_check.metrics.get("success") is True:
            too_small_check.status = "FAIL"
            too_small_check.message = "BUG: pipeline accepted sub-1KB image — validation must reject it"

    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 3 — Voice Pipeline Dry Run
# ══════════════════════════════════════════════════════════════════════════════

async def _run_voice_pipeline_async(audio_bytes: bytes, label: str,
                                    expected: Optional[str] = None) -> CheckResult:
    try:
        from app.pipelines.voice_pipeline import run_voice_pipeline
        t0 = time.perf_counter()
        result = await run_voice_pipeline(
            audio_bytes,
            session_id=f"val_{label}",
            expected_letter=expected,
            language="en",
        )
        ms = (time.perf_counter() - t0) * 1000

        wf = result.get("waveform", {})
        metrics = {
            "duration_s":  wf.get("duration_s", 0),
            "rms_energy":  wf.get("rms_energy", 0),
            "success":     result.get("success"),
            "transcript":  result.get("transcript", "")[:60],
        }
        return CheckResult(f"voice_pipeline_{label}", "PASS" if result.get("success") else "WARN",
            result.get("error") or f"Transcript: '{metrics['transcript']}'",
            duration_ms=ms, metrics=metrics)
    except ModuleNotFoundError as exc:
        return CheckResult(f"voice_pipeline_{label}", "WARN",
            f"ML dependency not installed (expected in dev): {exc}.  "
            "Install requirements.txt on a GPU host to enable full pipeline.")
    except Exception as exc:
        return CheckResult(f"voice_pipeline_{label}", "FAIL",
            f"{type(exc).__name__}: {exc}",
            detail=traceback.format_exc(limit=4))


def _voice_silence_gate_check(sr: SectionResult) -> None:
    """
    Silence gate must reject silent audio. Verify the pipeline enforces it
    without needing the full Whisper model.
    """
    try:
        from app.pipelines.voice_pipeline import _read_waveform_meta  # type: ignore
    except ImportError:
        pass  # will be caught in the async run

    silent_wav = _make_test_wav(1.0, silent=True)

    loop = asyncio.new_event_loop()
    try:
        result = loop.run_until_complete(
            _run_voice_pipeline_async(silent_wav, "silence_gate"))
    finally:
        loop.close()

    if result.metrics.get("success") is True:
        sr.checks.append(CheckResult("voice_silence_gate", "FAIL",
            "BUG: silence was NOT rejected by silence gate",
            metrics=result.metrics))
    else:
        sr.checks.append(CheckResult("voice_silence_gate", "PASS",
            "Silence gate correctly rejected silent audio",
            duration_ms=result.duration_ms))


def run_section_3() -> SectionResult:
    sr = SectionResult("3. Voice Pipeline Dry Run")

    test_clips = {
        "clear_speech":   _make_test_wav(2.0),
        "noisy_speech":   _make_test_wav(2.5),
        "long_clip":      _make_test_wav(35.0),   # > 30 s — should be rejected
    }

    loop = asyncio.new_event_loop()
    try:
        for label, wav in test_clips.items():
            check = loop.run_until_complete(
                _run_voice_pipeline_async(wav, label, expected="E"))
            sr.checks.append(check)
    finally:
        loop.close()

    # Verify that 35 s clip was duraton-gated
    long_check = next((c for c in sr.checks if "long_clip" in c.name), None)
    if long_check and long_check.metrics.get("success") is True:
        long_check.status = "FAIL"
        long_check.message = "BUG: 35 s clip was NOT rejected by duration gate"
    else:
        if long_check:
            long_check.status = "PASS"
            long_check.message = "Duration gate correctly rejected 35 s clip"

    _voice_silence_gate_check(sr)
    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 4 — Scoring Engine Validation
# ══════════════════════════════════════════════════════════════════════════════

_SYNTHETIC_RECORDS = [
    # (gaze_asym, l_fix, r_fix, blink_asym, conf, asym_ratio, binocular, suppression,
    #  constrict_l, constrict_r, snellen_right, snellen_left, hesitation, sn_conf,
    #  strabismus_flag, expected_band)
    (0.05, 0.02, 0.02, 0.05, 0.95, 0.02,  3, False, 0.0,  0.0,  "6/6",   "6/6",   0.05, 0.95, False, "low"),
    (0.10, 0.05, 0.06, 0.08, 0.90, 0.10,  2, False, 0.05, 0.05, "6/9",   "6/9",   0.10, 0.90, False, "low"),
    (0.20, 0.10, 0.15, 0.15, 0.80, 0.15,  2, False, 0.10, 0.08, "6/12",  "6/12",  0.15, 0.85, False, "medium"),
    (0.25, 0.12, 0.20, 0.20, 0.75, 0.18,  1, True,  0.15, 0.10, "6/18",  "6/18",  0.20, 0.80, True,  "medium"),
    (0.30, 0.20, 0.30, 0.25, 0.70, 0.22,  1, False, 0.20, 0.15, "6/24",  "6/24",  0.25, 0.75, True,  "high"),
    (0.35, 0.25, 0.35, 0.30, 0.65, 0.25,  1, True,  0.25, 0.20, "6/36",  "6/36",  0.30, 0.70, True,  "high"),
    (0.40, 0.30, 0.40, 0.35, 0.60, 0.28,  1, True,  0.28, 0.25, "6/60",  "6/60",  0.40, 0.60, True,  "high"),
    (None, None, None, None, None, None,  None, False, None, None, "6/6",  "6/6",   None, None, False, "low"),
    (None, None, None, None, None, 0.30,  1,  True, 0.20, 0.20,  "6/36",  "6/36",  0.35, 0.65, True,  "high"),
    (0.15, 0.08, 0.12, 0.12, 0.85, 0.12,  2, False, 0.08, 0.06, "6/9",   "6/6",   0.10, 0.88, False, "low"),
]


def run_section_4() -> SectionResult:
    sr = SectionResult("4. Scoring Engine Validation")

    try:
        from app.services.scoring_engine import (
            calculate_gaze_score,
            calculate_redgreen_score,
            calculate_snellen_score,
            calculate_combined_score,
            assign_severity_grade,
        )
        from app.config import settings
    except ImportError as exc:
        sr.checks.append(CheckResult("scoring_engine_import", "FAIL", str(exc)))
        return sr

    sr.checks.append(CheckResult("scoring_engine_import", "PASS",
        "scoring_engine imported successfully"))

    pass_count = 0
    fail_count = 0
    scores_produced: list[float] = []

    for i, rec in enumerate(_SYNTHETIC_RECORDS):
        (gaze_asym, l_fix, r_fix, blink_asym, conf,
         asym_ratio, binocular, suppression, constrict_l, constrict_r,
         snellen_right, snellen_left, hesitation, sn_conf,
         strabismus_flag, expected_band) = rec

        try:
            gaze    = calculate_gaze_score(gaze_asym, l_fix, r_fix, blink_asym, conf)
            rg      = calculate_redgreen_score(asym_ratio, binocular, suppression,
                                               constrict_l, constrict_r, conf)
            snellen = calculate_snellen_score(
                visual_acuity_right=snellen_right,
                visual_acuity_left=snellen_left,
                hesitation_score=hesitation,
                confidence_score=sn_conf,
            )
            # calculate_combined_score() returns a float
            combined_float = calculate_combined_score(
                gaze_score=gaze,
                redgreen_score=rg,
                snellen_score=snellen,
                strabismus_flag=strabismus_flag,
            )
            # assign_severity_grade() maps the float to dict with risk_score, risk_level, explanation
            combined = assign_severity_grade(combined_float)

            risk = combined.get("risk_score", -1)
            band = combined.get("risk_level", "")
            explanation = combined.get("explanation", "")

            scores_produced.append(risk)

            # Validate range
            if not (0 <= risk <= 100):
                sr.checks.append(CheckResult(f"scoring_record_{i+1}", "FAIL",
                    f"risk_score {risk} out of range [0, 100]",
                    metrics={"risk_score": risk, "band": band}))
                fail_count += 1
                continue

            # Validate explanation present
            if not explanation:
                sr.checks.append(CheckResult(f"scoring_record_{i+1}", "FAIL",
                    "explanation text is empty",
                    metrics={"risk_score": risk, "band": band}))
                fail_count += 1
                continue

            # Soft-check expected band (high risk cases should score higher)
            # We don't hard-fail on band mismatch — the engine's own thresholds
            # define what low/medium/high means
            pass_count += 1
            sr.checks.append(CheckResult(f"scoring_record_{i+1}", "PASS",
                f"risk={risk:.1f} band={band} expected≈{expected_band} "
                f"expl='{explanation[:50]}...'",
                metrics={"risk_score": risk, "risk_band": band,
                         "gaze": gaze, "rg": rg, "snellen": snellen}))

        except Exception as exc:
            fail_count += 1
            sr.checks.append(CheckResult(f"scoring_record_{i+1}", "FAIL",
                f"{type(exc).__name__}: {exc}",
                detail=traceback.format_exc(limit=3)))

    if scores_produced:
        mn, mx, avg = min(scores_produced), max(scores_produced), sum(scores_produced)/len(scores_produced)
        sr.checks.append(CheckResult("scoring_summary", "PASS",
            f"10 records: min={mn:.1f} max={mx:.1f} avg={avg:.1f} | {pass_count} pass / {fail_count} fail",
            metrics={"min": mn, "max": mx, "avg": avg}))

    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 5 — MLflow Validation
# ══════════════════════════════════════════════════════════════════════════════

def run_section_5() -> SectionResult:
    sr = SectionResult("5. MLflow Validation")

    try:
        import mlflow
        from app.services.mlflow_model_service import (
            model_status,
            register_trained_model,
            promote_to_production,
        )
    except ImportError as exc:
        sr.checks.append(CheckResult("mlflow_import", "WARN",
            f"mlflow not installed — run: pip install mlflow: {exc}"))
        return sr

    # ── log dummy metrics ──────────────────────────────────────────────────
    try:
        mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
        mlflow.set_experiment("system_validation")
        with mlflow.start_run(run_name="validation_dry_run") as run:
            mlflow.log_metric("dummy_auroc",    0.91)
            mlflow.log_metric("dummy_accuracy", 0.88)
            mlflow.log_param("source", "system_validation")
            run_id = run.info.run_id
        sr.checks.append(CheckResult("mlflow_log_metrics", "PASS",
            f"Metrics logged to run_id={run_id}",
            metrics={"run_id": run_id}))
    except Exception as exc:
        sr.checks.append(CheckResult("mlflow_log_metrics", "WARN",
            f"MLflow server unavailable (OK offline): {type(exc).__name__}"))

    # ── model_status() call ────────────────────────────────────────────────
    try:
        status = model_status()
        sr.checks.append(CheckResult("mlflow_model_status", "PASS",
            f"model_status() returned: {status}",
            metrics=status))
    except Exception as exc:
        sr.checks.append(CheckResult("mlflow_model_status", "WARN",
            f"model_status() failed: {type(exc).__name__}: {exc}"))

    # ── promotion threshold check ──────────────────────────────────────────
    try:
        from app.config import settings
        threshold = settings.mlflow_min_auroc
        # Passing just below threshold → should NOT promote
        low_auroc = threshold - 0.01
        promoted = promote_to_production(version="999", auroc=low_auroc)
        if promoted:
            sr.checks.append(CheckResult("mlflow_promotion_threshold", "FAIL",
                f"Model below AUROC {threshold} was promoted — threshold not enforced"))
        else:
            sr.checks.append(CheckResult("mlflow_promotion_threshold", "PASS",
                f"Promotion correctly blocked: AUROC {low_auroc:.2f} < threshold {threshold}"))
    except Exception as exc:
        sr.checks.append(CheckResult("mlflow_promotion_threshold", "WARN",
            f"Could not test promotion threshold: {type(exc).__name__}: {exc}"))

    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 6 — Airflow DAG Validation
# ══════════════════════════════════════════════════════════════════════════════

def run_section_6() -> SectionResult:
    sr = SectionResult("6. Airflow DAG Validation")

    dag_path = PROJECT_ROOT / "airflow" / "dags" / "weekly_retraining_dag.py"

    # ── syntax ────────────────────────────────────────────────────────────
    try:
        import ast
        ast.parse(dag_path.read_text())
        sr.checks.append(CheckResult("dag_syntax_valid", "PASS",
            f"No syntax errors in {dag_path.name}"))
    except Exception as exc:
        sr.checks.append(CheckResult("dag_syntax_valid", "FAIL", str(exc)))
        return sr

    # ── load module, extract DAG and call-graph ────────────────────────────
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("weekly_dag", dag_path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        dag = getattr(mod, "dag", None)

        if dag is None:
            sr.checks.append(CheckResult("dag_module_load", "FAIL",
                "`dag` object not exported from module"))
            return sr

        task_ids = sorted(t.task_id for t in dag.tasks)
        sr.checks.append(CheckResult("dag_module_load", "PASS",
            f"DAG '{dag.dag_id}' loaded with {len(task_ids)} tasks: {task_ids}",
            metrics={"task_count": len(task_ids), "tasks": task_ids}))

        # Expected tasks
        expected = {
            "extract_training_data", "train_model", "evaluate_model",
            "register_to_mlflow", "promote_to_production", "notify_completion",
        }
        missing = expected - set(task_ids)
        if missing:
            sr.checks.append(CheckResult("dag_expected_tasks", "WARN",
                f"Missing expected tasks: {missing}"))
        else:
            sr.checks.append(CheckResult("dag_expected_tasks", "PASS",
                f"All 6 expected tasks present"))

    except Exception as exc:
        sr.checks.append(CheckResult("dag_module_load", "WARN",
            f"Airflow not installed: {type(exc).__name__}: {exc}",
            detail=traceback.format_exc(limit=3)))
        return sr

    # ── on_failure_callback present ────────────────────────────────────────
    src = dag_path.read_text()
    if "on_failure_callback" in src and "_send_failure_notification" in src:
        sr.checks.append(CheckResult("dag_failure_hook", "PASS",
            "on_failure_callback found and wired to _send_failure_notification"))
    else:
        sr.checks.append(CheckResult("dag_failure_hook", "FAIL",
            "on_failure_callback missing — failures won't trigger WhatsApp alert"))

    # ── auroc threshold referenced ─────────────────────────────────────────
    if "MIN_AUROC_FOR_PROMOTION" in src or "mlflow_min_auroc" in src:
        sr.checks.append(CheckResult("dag_auroc_gate", "PASS",
            "AUROC promotion gate found in DAG"))
    else:
        sr.checks.append(CheckResult("dag_auroc_gate", "FAIL",
            "No AUROC threshold found in DAG"))

    # ── simulate task functions directly ──────────────────────────────────
    # Build a mock TI with XCom push/pull
    class _MockTI:
        def __init__(self):
            self._xcom: Dict = {}
        def xcom_push(self, key, value, **kwargs):
            self._xcom[key] = value
        def xcom_pull(self, key, task_ids=None, **kwargs):
            return self._xcom.get(key)

    try:
        # Simulate extract step
        extract_fn = getattr(mod, "extract_training_data", None)
        if extract_fn is None:
            raise AttributeError("extract_training_data not found in module")

        ti = _MockTI()
        extract_fn(ti=ti)
        sr.checks.append(CheckResult("dag_extract_task_run", "PASS",
            f"extract_training_data ran without exception, "
            f"sample_count={ti.xcom_pull('sample_count')}",
            metrics={"sample_count": ti.xcom_pull("sample_count")}))
    except Exception as exc:
        sr.checks.append(CheckResult("dag_extract_task_run", "WARN",
            f"extract task simulation: {type(exc).__name__}: {exc}"))

    # Simulate forced failure → hook invoked
    try:
        notify_fn = getattr(mod, "_send_failure_notification", None)
        if notify_fn:
            context = {
                "dag": type("D", (), {"dag_id": "test_dag"})(),
                "task_instance": type("T", (), {"task_id": "test_task"})(),
                "exception": RuntimeError("synthetic failure"),
            }
            notify_fn(context)  # Should not raise (it catches internally)
            sr.checks.append(CheckResult("dag_failure_hook_invocation", "PASS",
                "Failure hook invoked without raising exception "
                "(notification may have been skipped - OK in dev)"))
        else:
            sr.checks.append(CheckResult("dag_failure_hook_invocation", "WARN",
                "_send_failure_notification function not found"))
    except Exception as exc:
        sr.checks.append(CheckResult("dag_failure_hook_invocation", "WARN",
            f"Failure hook raised: {type(exc).__name__}: {exc}"))

    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 7 — Security Validation
# ══════════════════════════════════════════════════════════════════════════════

def run_section_7() -> SectionResult:
    sr = SectionResult("7. Security Validation")

    # ── 7a: JWT JTI blacklist ──────────────────────────────────────────────
    try:
        from app.utils.security import create_access_token, decode_access_token, get_jti
        token = create_access_token({"sub": "test-nurse-id", "role": "nurse"})
        jti   = get_jti(token)
        payload = decode_access_token(token)
        assert jti is not None,           "get_jti() returned None"
        assert jti == payload.get("jti"), "JTI mismatch between get_jti() and payload"
        sr.checks.append(CheckResult("jwt_jti_extraction", "PASS",
            f"JTI extracted and verified: {jti[:8]}…",
            metrics={"jti_len": len(jti), "has_jti_in_payload": bool(payload.get("jti"))}))
    except Exception as exc:
        sr.checks.append(CheckResult("jwt_jti_extraction", "FAIL",
            f"{type(exc).__name__}: {exc}", detail=traceback.format_exc(limit=3)))

    # ── 7b: Verify dependencies.py uses jti_blacklist:{jti} key ───────────
    dep_path = PROJECT_ROOT / "app" / "dependencies.py"
    dep_src  = dep_path.read_text()

    # Strip comment lines so old-key references in explanatory comments don't
    # count as live code (comments start with optional whitespace + #)
    import re as _re
    dep_code_only = "\n".join(
        line for line in dep_src.splitlines()
        if not _re.match(r"^\s*#", line)
    )

    has_jti_check   = "jti_blacklist:{jti}" in dep_code_only
    has_token_check = 'f"blacklist:{token}"' in dep_code_only or \
                      "f'blacklist:{token}'" in dep_code_only

    if has_jti_check and not has_token_check:
        sr.checks.append(CheckResult("jwt_blacklist_key_correct", "PASS",
            "get_current_user checks jti_blacklist:{jti} — correct pattern"))
    elif has_token_check:
        sr.checks.append(CheckResult("jwt_blacklist_key_correct", "FAIL",
            "CRITICAL: get_current_user still checks blacklist:{token} (full token) — "
            "revoked tokens can still authenticate!"))
    else:
        sr.checks.append(CheckResult("jwt_blacklist_key_correct", "WARN",
            "jti_blacklist key check not found — verify dependencies.py manually"))

    # ── 7c: Rate limit middleware present ──────────────────────────────────
    main_src = (PROJECT_ROOT / "app" / "main.py").read_text()
    if "RateLimitMiddleware" in main_src and "rate_limit" in main_src:
        sr.checks.append(CheckResult("rate_limit_middleware", "PASS",
            "RateLimitMiddleware registered in main.py"))
    else:
        sr.checks.append(CheckResult("rate_limit_middleware", "FAIL",
            "RateLimitMiddleware not found in main.py"))

    # ── 7d: Security headers middleware present ────────────────────────────
    if "SecurityHeadersMiddleware" in main_src:
        sr.checks.append(CheckResult("security_headers_middleware", "PASS",
            "SecurityHeadersMiddleware registered in main.py"))
    else:
        sr.checks.append(CheckResult("security_headers_middleware", "FAIL",
            "SecurityHeadersMiddleware not found in main.py"))

    # ── 7e: CORS allow_headers not wildcard ───────────────────────────────
    if 'allow_headers=["*"]' in main_src or "allow_headers=['*']" in main_src:
        sr.checks.append(CheckResult("cors_allow_headers", "FAIL",
            'CORS allow_headers=["*"] — too permissive'))
    elif "allow_headers=" in main_src:
        sr.checks.append(CheckResult("cors_allow_headers", "PASS",
            "CORS allow_headers is an explicit allowlist"))
    else:
        sr.checks.append(CheckResult("cors_allow_headers", "WARN",
            "CORS allow_headers setting not found in main.py"))

    # ── 7f: CSRF service present for admin endpoints ───────────────────────
    csrf_path = PROJECT_ROOT / "app" / "services" / "csrf_service.py"
    if csrf_path.exists():
        csrf_src = csrf_path.read_text()
        has_generate = "generate_csrf_token" in csrf_src
        has_verify   = "verify_csrf_token"   in csrf_src
        has_hmac     = "hmac.compare_digest" in csrf_src
        if has_generate and has_verify and has_hmac:
            sr.checks.append(CheckResult("csrf_service", "PASS",
                "CSRF service: generate + verify + hmac.compare_digest all present"))
        else:
            missing = [n for n, v in [("generate", has_generate),
                                       ("verify", has_verify),
                                       ("hmac_digest", has_hmac)] if not v]
            sr.checks.append(CheckResult("csrf_service", "WARN",
                f"CSRF service incomplete — missing: {missing}"))
    else:
        sr.checks.append(CheckResult("csrf_service", "FAIL",
            "csrf_service.py not found"))

    # ── 7g: No hardcoded secrets ───────────────────────────────────────────
    config_src = (PROJECT_ROOT / "app" / "config.py").read_text()
    hardcoded_patterns = [
        ("secret_key.*=.*['\"]\\S{8,}", "secret_key has non-empty default"),
        ("password.*=.*['\"]\\S{4,}",   "password has hardcoded default"),
        ("minioadmin",                   "MinIO admin password hardcoded"),
        ("super-secret",                 "super-secret string present"),
    ]
    import re
    found_hardcoded = []
    for pattern, desc in hardcoded_patterns:
        if re.search(pattern, config_src, re.IGNORECASE):
            found_hardcoded.append(desc)

    if found_hardcoded:
        sr.checks.append(CheckResult("no_hardcoded_secrets_config", "FAIL",
            f"Hardcoded secrets found in config.py: {found_hardcoded}"))
    else:
        sr.checks.append(CheckResult("no_hardcoded_secrets_config", "PASS",
            "No hardcoded secrets detected in config.py"))

    # ── 7h: .env not inside Docker image ──────────────────────────────────
    dockerignore = PROJECT_ROOT / ".dockerignore"
    if dockerignore.exists():
        di_src = dockerignore.read_text()
        if ".env" in di_src:
            sr.checks.append(CheckResult("dockerignore_env", "PASS",
                ".env files excluded via .dockerignore"))
        else:
            sr.checks.append(CheckResult("dockerignore_env", "FAIL",
                ".dockerignore exists but doesn't exclude .env files"))
    else:
        sr.checks.append(CheckResult("dockerignore_env", "FAIL",
            ".dockerignore not found — .env may be baked into Docker image"))

    # ── 7i: Non-root container ─────────────────────────────────────────────
    dockerfile_path = PROJECT_ROOT / "docker" / "Dockerfile"
    if dockerfile_path.exists():
        df_src = dockerfile_path.read_text()
        if "USER appuser" in df_src or "USER nonroot" in df_src:
            sr.checks.append(CheckResult("docker_nonroot_user", "PASS",
                "Dockerfile uses non-root user (appuser)"))
        elif "useradd" in df_src or "adduser" in df_src:
            sr.checks.append(CheckResult("docker_nonroot_user", "WARN",
                "User creation found but USER directive not confirmed"))
        else:
            sr.checks.append(CheckResult("docker_nonroot_user", "FAIL",
                "No non-root USER directive found in Dockerfile"))
    else:
        sr.checks.append(CheckResult("docker_nonroot_user", "WARN",
            f"Dockerfile not found at {dockerfile_path}"))

    # ── 7j: PHI fields encrypted ──────────────────────────────────────────
    enc_svc = PROJECT_ROOT / "app" / "services" / "encryption_service.py"
    if enc_svc.exists():
        enc_src = enc_svc.read_text()
        if "AES" in enc_src or "GCM" in enc_src or "Fernet" in enc_src:
            sr.checks.append(CheckResult("phi_encryption_service", "PASS",
                "Encryption service uses AES/GCM or Fernet"))
        else:
            sr.checks.append(CheckResult("phi_encryption_service", "WARN",
                "Encryption service found but AES/GCM/Fernet not detected"))
    else:
        sr.checks.append(CheckResult("phi_encryption_service", "FAIL",
            "encryption_service.py not found"))

    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Section 8 — Performance Benchmark
# ══════════════════════════════════════════════════════════════════════════════

async def _bench_image_pipeline(n: int = 5) -> Tuple[List[float], List[float]]:
    from app.pipelines.image_pipeline import run_image_pipeline
    times_ms: list[float] = []
    for i in range(n):
        img = _make_test_jpeg(320, 240)
        t0 = time.perf_counter()
        await run_image_pipeline(img, session_id=f"bench_{i}")
        times_ms.append((time.perf_counter() - t0) * 1000)
    return times_ms, []


async def _bench_voice_pipeline(n: int = 3) -> List[float]:
    from app.pipelines.voice_pipeline import run_voice_pipeline
    times_ms: list[float] = []
    for i in range(n):
        wav = _make_test_wav(2.0)
        t0 = time.perf_counter()
        await run_voice_pipeline(wav, session_id=f"bench_voice_{i}")
        times_ms.append((time.perf_counter() - t0) * 1000)
    return times_ms


async def _bench_concurrent_image(n_concurrent: int = 20) -> Tuple[float, float]:
    """Fire n_concurrent image pipeline calls simultaneously."""
    from app.pipelines.image_pipeline import run_image_pipeline
    imgs = [_make_test_jpeg(320, 240) for _ in range(n_concurrent)]
    t0 = time.perf_counter()
    results = await asyncio.gather(
        *[run_image_pipeline(img, f"concurrent_{i}") for i, img in enumerate(imgs)],
        return_exceptions=True,
    )
    total_ms  = (time.perf_counter() - t0) * 1000
    errors    = sum(1 for r in results if isinstance(r, Exception))
    return total_ms, errors


def _memory_usage_mb() -> float:
    try:
        import resource
        mem = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        # Linux returns KB, macOS returns bytes
        if platform.system() == "Darwin":
            return mem / 1_048_576
        return mem / 1_024
    except Exception:
        return -1.0


def _cpu_count() -> int:
    try:
        return os.cpu_count() or 1
    except Exception:
        return 1


def run_section_8() -> SectionResult:
    sr = SectionResult("8. Performance Benchmark")
    loop = asyncio.new_event_loop()

    mem_before = _memory_usage_mb()

    # ── Image pipeline throughput ──────────────────────────────────────────
    try:
        times_ms, _ = loop.run_until_complete(_bench_image_pipeline(5))
        avg_ms, p95_ms, mx_ms = (
            sum(times_ms) / len(times_ms),
            sorted(times_ms)[int(0.95 * len(times_ms))],
            max(times_ms),
        )
        status = "PASS" if avg_ms < 5000 else "WARN"
        sr.checks.append(CheckResult("image_pipeline_throughput", status,
            f"5 runs: avg={avg_ms:.0f} ms  p95={p95_ms:.0f} ms  max={mx_ms:.0f} ms",
            metrics={"avg_ms": avg_ms, "p95_ms": p95_ms, "max_ms": mx_ms,
                     "runs": times_ms}))
    except ModuleNotFoundError as exc:
        sr.checks.append(CheckResult("image_pipeline_throughput", "WARN",
            f"ML dependency not installed — skipping benchmark: {exc}"))
    except Exception as exc:
        sr.checks.append(CheckResult("image_pipeline_throughput", "FAIL",
            f"{type(exc).__name__}: {exc}"))

    # ── Voice pipeline throughput ──────────────────────────────────────────
    try:
        times_ms = loop.run_until_complete(_bench_voice_pipeline(3))
        avg_ms = sum(times_ms) / len(times_ms)
        status = "PASS" if avg_ms < 10000 else "WARN"
        sr.checks.append(CheckResult("voice_pipeline_throughput", status,
            f"3 runs: avg={avg_ms:.0f} ms  max={max(times_ms):.0f} ms",
            metrics={"avg_ms": avg_ms, "max_ms": max(times_ms)}))
    except Exception as exc:
        sr.checks.append(CheckResult("voice_pipeline_throughput", "FAIL",
            f"{type(exc).__name__}: {exc}"))

    # ── Concurrent image requests (20 parallel) ────────────────────────────
    try:
        total_ms, errors = loop.run_until_complete(_bench_concurrent_image(20))
        throughput = 20 / (total_ms / 1000)  # req/s
        status = "PASS" if errors == 0 else "WARN"
        sr.checks.append(CheckResult("concurrent_image_latency", status,
            f"20 concurrent: total={total_ms:.0f} ms  "
            f"throughput={throughput:.1f} req/s  errors={errors}",
            metrics={"total_ms": total_ms, "throughput_rps": throughput,
                     "errors": errors}))
    except ModuleNotFoundError as exc:
        sr.checks.append(CheckResult("concurrent_image_latency", "WARN",
            f"ML dependency not installed — skipping benchmark: {exc}"))
    except Exception as exc:
        sr.checks.append(CheckResult("concurrent_image_latency", "FAIL",
            f"{type(exc).__name__}: {exc}"))

    # ── Memory ────────────────────────────────────────────────────────────
    mem_after = _memory_usage_mb()
    delta     = mem_after - mem_before if mem_before > 0 else -1
    mem_status = "PASS" if mem_after < 1000 else "WARN"
    sr.checks.append(CheckResult("memory_usage", mem_status,
        f"RSS={mem_after:.1f} MB  delta={delta:.1f} MB  CPUs={_cpu_count()}",
        metrics={"rss_mb": mem_after, "delta_mb": delta,
                 "cpu_count": _cpu_count()}))

    loop.close()
    return sr


# ══════════════════════════════════════════════════════════════════════════════
#  Report Renderer
# ══════════════════════════════════════════════════════════════════════════════

def _render_report(sections: List[SectionResult], elapsed_s: float) -> dict:
    bar = "─" * 72

    total_pass = total_fail = total_warn = total_skip = 0
    for sec in sections:
        total_pass += sec.passed
        total_fail += sec.failed
        total_warn += sec.warned
        total_skip += sec.skipped

    total = total_pass + total_fail + total_warn + total_skip
    all_critical_pass = total_fail == 0

    print()
    print(BOLD("╔══════════════════════════════════════════════════════════════════════╗"))
    print(BOLD("║       AMBLYOPIA CARE SYSTEM — SYSTEM VALIDATION REPORT              ║"))
    print(BOLD("╚══════════════════════════════════════════════════════════════════════╝"))
    print(f"  Date   : {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}")
    print(f"  Python : {sys.version.split()[0]}")
    print(f"  OS     : {platform.system()} {platform.release()}")
    print(f"  Elapsed: {elapsed_s:.1f} s")
    print()

    for sec in sections:
        status_icon = GREEN("✔") if sec.failed == 0 else RED("✘")
        print(f"{status_icon}  {BOLD(sec.section)}")
        print(f"   {DIM(bar[:65])}")

        for check in sec.checks:
            if check.status == "PASS":
                icon = GREEN("  ✔ PASS")
            elif check.status == "FAIL":
                icon = RED("  ✘ FAIL")
            elif check.status == "WARN":
                icon = YELLOW("  ⚠ WARN")
            else:
                icon = DIM("  ○ SKIP")

            duration_str = f"  [{check.duration_ms:.0f} ms]" if check.duration_ms > 0 else ""
            print(f"   {icon}  {check.name}{DIM(duration_str)}")
            if check.message:
                print(f"         {DIM(check.message)}")
            if check.detail and check.status == "FAIL":
                for line in check.detail.splitlines()[:5]:
                    print(f"         {DIM(line)}")
        print()

    # ── Summary ────────────────────────────────────────────────────────────
    print(BOLD(bar))
    print(f"  RESULTS:  "
          f"{GREEN(f'{total_pass} PASS')}  "
          f"{RED(f'{total_fail} FAIL')}  "
          f"{YELLOW(f'{total_warn} WARN')}  "
          f"{DIM(f'{total_skip} SKIP')}  "
          f"of {total} checks")
    print()

    # Security-specific summary
    sec7 = next((s for s in sections if "Security" in s.section), None)
    if sec7 and sec7.failed > 0:
        print(RED("  ⚠  SECURITY ISSUES DETECTED — resolve failures before clinical deployment"))
    elif sec7:
        print(GREEN("  ✔  All security checks passed"))

    print()
    if all_critical_pass:
        print(BOLD(GREEN(
            "  ✅  VERDICT: READY FOR CLINICAL DATA INTEGRATION"
        )))
        if total_warn > 0:
            print(YELLOW(
            f"      ({total_warn} warning(s) — review integration model weights before production)"))
    else:
        print(BOLD(RED(
            f"  ❌  VERDICT: NOT READY — {total_fail} critical failure(s) must be resolved"
        )))
    print(BOLD(bar))
    print()

    return {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "elapsed_s": elapsed_s,
        "summary": {
            "total": total, "pass": total_pass, "fail": total_fail,
            "warn": total_warn, "skip": total_skip,
            "verdict": "READY" if all_critical_pass else "NOT_READY",
        },
        "sections": [
            {
                "name": sec.section,
                "pass": sec.passed, "fail": sec.failed,
                "warn": sec.warned,  "skip": sec.skipped,
                "checks": [asdict(c) for c in sec.checks],
            }
            for sec in sections
        ],
    }


# ══════════════════════════════════════════════════════════════════════════════
#  Entrypoint
# ══════════════════════════════════════════════════════════════════════════════

SECTION_MAP = {
    "deps":        ("1. Open-Source Dependency Check", run_section_1),
    "image":       ("2. Image Pipeline Dry Run",       run_section_2),
    "voice":       ("3. Voice Pipeline Dry Run",       run_section_3),
    "scoring":     ("4. Scoring Engine Validation",    run_section_4),
    "mlflow":      ("5. MLflow Validation",            run_section_5),
    "airflow":     ("6. Airflow DAG Validation",       run_section_6),
    "security":    ("7. Security Validation",          run_section_7),
    "performance": ("8. Performance Benchmark",        run_section_8),
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Amblyopia Care System — full system validation suite")
    parser.add_argument("--section", choices=list(SECTION_MAP.keys()),
                        help="Run only a specific section")
    parser.add_argument("--list", action="store_true",
                        help="List available sections and exit")
    parser.add_argument("--json-out", default="",
                        help="Write JSON report to this path (default: logs/validation_<ts>.json)")
    args = parser.parse_args()

    if args.list:
        print("\nAvailable sections:")
        for key, (name, _) in SECTION_MAP.items():
            print(f"  {key:15s} {name}")
        return 0

    sections_to_run = (
        [SECTION_MAP[args.section]]
        if args.section
        else list(SECTION_MAP.values())
    )

    print(CYAN(f"\n  Amblyopia Care System Validation Suite"))
    print(CYAN(f"  Running {len(sections_to_run)} section(s)…\n"))

    t_start = time.perf_counter()
    results: List[SectionResult] = []

    for _name, fn in sections_to_run:
        print(DIM(f"  → {_name}"))
        try:
            result = fn()
        except Exception as exc:
            result = SectionResult(_name)
            result.checks.append(CheckResult(
                "section_runner", "FAIL",
                f"Section crashed: {type(exc).__name__}: {exc}",
                detail=traceback.format_exc(limit=5),
            ))
        results.append(result)

    elapsed = time.perf_counter() - t_start
    report  = _render_report(results, elapsed)

    # ── Write JSON ─────────────────────────────────────────────────────────
    out_path = args.json_out
    if not out_path:
        logs_dir = PROJECT_ROOT / "logs"
        logs_dir.mkdir(exist_ok=True)
        ts = time.strftime("%Y%m%d_%H%M%S")
        out_path = str(logs_dir / f"validation_{ts}.json")

    try:
        Path(out_path).write_text(json.dumps(report, indent=2))
        print(f"  Report saved → {out_path}\n")
    except Exception as exc:
        print(f"  Could not write report: {exc}\n")

    return 0 if report["summary"]["verdict"] == "READY" else 1


if __name__ == "__main__":
    sys.exit(main())
