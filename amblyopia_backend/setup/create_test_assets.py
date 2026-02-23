"""
TASK 2 (Part 1) — Create All Test Assets
Aravind Eye Hospital — Amblyopia Care System
Generates synthetic eye images and audio for integration tests.
"""
from __future__ import annotations

import os
import sys

import numpy as np

PROJECT = "/home/anandhu/projects/amblyopia_backend"
os.chdir(PROJECT)
ASSETS = "test_assets"
os.makedirs(ASSETS, exist_ok=True)

print("================================================")
print("Creating test assets for integration tests")
print("================================================")


# ── helpers ───────────────────────────────────────────────────────────────────

def save_image(path: str, img: np.ndarray) -> None:
    try:
        import cv2
        cv2.imwrite(path, img)
        kb = os.path.getsize(path) / 1024
        print(f"  Created: {path} ({kb:.0f} KB)")
    except ImportError:
        from PIL import Image as PILImage
        rgb = img[:, :, ::-1]  # BGR → RGB
        PILImage.fromarray(rgb).save(path)
        kb = os.path.getsize(path) / 1024
        print(f"  Created: {path} ({kb:.0f} KB) [PIL]")


def make_eye_image(brightness: int = 240) -> np.ndarray:
    """Synthetic two-eye face image."""
    img = np.full((480, 640, 3), brightness, dtype=np.uint8)
    try:
        import cv2
        # Left eye white
        cv2.circle(img, (200, 240), 70, (255, 255, 255), -1)
        # Right eye white
        cv2.circle(img, (440, 240), 70, (255, 255, 255), -1)
        # Left iris dark
        cv2.circle(img, (200, 240), 35, (55, 55, 55), -1)
        # Right iris dark
        cv2.circle(img, (440, 240), 35, (55, 55, 55), -1)
        # Left pupil highlight
        cv2.circle(img, (195, 235), 10, (255, 255, 255), -1)
        # Right pupil highlight
        cv2.circle(img, (435, 235), 10, (255, 255, 255), -1)
        # Nose bridge hint
        cv2.line(img, (320, 260), (320, 380), (brightness - 30, brightness - 30, brightness - 30), 4)
    except ImportError:
        pass
    return img


# ── Asset 1: Normal eye image ─────────────────────────────────────────────────
img_normal = make_eye_image(230)
save_image(f"{ASSETS}/sample_eye_image.jpg", img_normal)

# ── Asset 2: Dark eye image (mean ≈ 18) ───────────────────────────────────────
img_dark = (make_eye_image(230) * 0.08).clip(0, 255).astype(np.uint8)
save_image(f"{ASSETS}/sample_dark_image.jpg", img_dark)

# ── Asset 3: Blurry eye image ─────────────────────────────────────────────────
try:
    import cv2 as cv2_blur
    img_blurry = cv2_blur.GaussianBlur(make_eye_image(230), (25, 25), 0)
except ImportError:
    # PIL / scipy fallback blur
    try:
        from PIL import ImageFilter, Image as PIL
        pil_img = PIL.fromarray(make_eye_image(230)[:, :, ::-1])
        pil_blur = pil_img.filter(ImageFilter.GaussianBlur(radius=12))
        img_blurry = np.array(pil_blur)[:, :, ::-1]
    except Exception:
        img_blurry = make_eye_image(230)
save_image(f"{ASSETS}/sample_blurry_image.jpg", img_blurry)

# ── Asset 4: Bright image (for Zero-DCE skip test, mean ≈ 220) ────────────────
img_bright = np.full((480, 640, 3), 220, dtype=np.uint8)
save_image(f"{ASSETS}/sample_bright_image.jpg", img_bright)

# ── Asset 5: Sharp image (for DeblurGAN skip test, Laplacian var > threshold) ─
img_sharp = make_eye_image(230).copy()
try:
    import cv2
    for i in range(0, 640, 10):
        cv2.line(img_sharp, (i, 0), (i, 480), (200, 200, 200), 1)
    for j in range(0, 480, 10):
        cv2.line(img_sharp, (0, j), (640, j), (200, 200, 200), 1)
except ImportError:
    pass
save_image(f"{ASSETS}/sample_sharp_image.jpg", img_sharp)

# ── Asset 6: Audio — 48kHz sine + noise for RNNoise/Whisper ──────────────────
SAMPLE_RATE = 48000
DURATION    = 2.0
t           = np.linspace(0, DURATION, int(SAMPLE_RATE * DURATION), endpoint=False)
signal      = 0.6 * np.sin(2 * np.pi * 440 * t)
noise       = 0.15 * np.random.default_rng(42).standard_normal(t.shape)
audio       = np.clip(signal + noise, -1.0, 1.0).astype(np.float32)

try:
    import soundfile as sf
    sf.write(f"{ASSETS}/sample_audio.wav", audio, SAMPLE_RATE)
    kb = os.path.getsize(f"{ASSETS}/sample_audio.wav") / 1024
    print(f"  Created: {ASSETS}/sample_audio.wav ({kb:.0f} KB, 48kHz, {DURATION}s)")
except ImportError:
    # fallback — write minimal WAV by hand
    import wave, struct
    pcm = (audio * 32767).astype(np.int16)
    with wave.open(f"{ASSETS}/sample_audio.wav", "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    print(f"  Created: {ASSETS}/sample_audio.wav (wave fallback)")

# ── Asset 7: 16kHz audio for Whisper (Whisper expects 16kHz) ──────────────────
SR16 = 16000
t16  = np.linspace(0, DURATION, int(SR16 * DURATION), endpoint=False)
a16  = np.clip(0.6 * np.sin(2 * np.pi * 440 * t16) + 0.05 * np.random.default_rng(42).standard_normal(t16.shape), -1.0, 1.0).astype(np.float32)
try:
    import soundfile as sf
    sf.write(f"{ASSETS}/sample_audio_16k.wav", a16, SR16)
    kb = os.path.getsize(f"{ASSETS}/sample_audio_16k.wav") / 1024
    print(f"  Created: {ASSETS}/sample_audio_16k.wav ({kb:.0f} KB, 16kHz)")
except Exception as e:
    print(f"  Warning: 16kHz audio skipped — {e}")

print("")
print("All test assets created:")
for fname in sorted(os.listdir(ASSETS)):
    size = os.path.getsize(f"{ASSETS}/{fname}")
    print(f"  {ASSETS}/{fname}  ({size/1024:.0f} KB)")

print("")
print("================================================")
print("Asset creation complete")
print("================================================")
