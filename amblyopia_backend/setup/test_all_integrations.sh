#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Full Integration Test Runner
# Creates test assets, then runs all 6 pytest suites
# =============================================================================
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ── Activate venv if present
if [ -f "venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source venv/bin/activate
    echo "[venv] Activated: $(which python3)"
else
    echo "[venv] No venv — using system python3"
fi

echo "================================================"
echo " AMBLYOPIA CARE SYSTEM — Integration Test Suite"
echo " $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================"

# ─── STEP 1: Create test assets ─────────────────────────────────────────────
echo ""
echo "[1/3] Creating test assets..."
mkdir -p test_assets

python3 - <<'PYEOF'
import numpy as np
import os

assets = 'test_assets'
os.makedirs(assets, exist_ok=True)

# ── Try to use cv2; fall back to PIL which is always available ────────────
try:
    import cv2
    _HAS_CV2 = True
except ImportError:
    _HAS_CV2 = False
    from PIL import Image

def save_image(arr: np.ndarray, path: str) -> None:
    """Save uint8 HxWx3 BGR (or RGB when no cv2) array."""
    if _HAS_CV2:
        cv2.imwrite(path, arr)
    else:
        # arr is already RGB when _HAS_CV2=False; just save with PIL
        Image.fromarray(arr).save(path)

def circle(img, cx, cy, r, color):
    """Draw a filled circle without cv2."""
    if _HAS_CV2:
        cv2.circle(img, (cx, cy), r, color[::-1] if _HAS_CV2 else color, -1)
        return
    # Pure-numpy rasterisation
    y, x = np.ogrid[:img.shape[0], :img.shape[1]]
    mask = (x - cx)**2 + (y - cy)**2 <= r**2
    img[mask] = color

# ── synthetic eye image ──────────────────────────────────────────────────
img = np.zeros((480, 640, 3), dtype=np.uint8)
circle(img, 200, 240, 60, (240, 240, 240))  # sclera L
circle(img, 440, 240, 60, (240, 240, 240))  # sclera R
circle(img, 200, 240, 35, (80,  50,  20))   # iris L
circle(img, 440, 240, 35, (80,  50,  20))   # iris R
circle(img, 200, 240, 15, (10,  10,  10))   # pupil L
circle(img, 440, 240, 15, (10,  10,  10))   # pupil R
circle(img, 195, 233,  5, (255, 255, 255))  # reflex L
circle(img, 435, 233,  5, (255, 255, 255))  # reflex R
save_image(img, os.path.join(assets, 'sample_eye_image.jpg'))
print('  \u2713 sample_eye_image.jpg created (480x640)')

# ── dark version ─────────────────────────────────────────────────────────
dark = (img.astype(np.float32) * 0.08).astype(np.uint8)
save_image(dark, os.path.join(assets, 'sample_dark_image.jpg'))
print('  \u2713 sample_dark_image.jpg (mean:', round(float(dark.mean()), 1), ')')

# ── blurry version — simulate blur with neighbour averaging ───────────────
from scipy.ndimage import uniform_filter
blurry = uniform_filter(img.astype(np.float64), size=15).astype(np.uint8)
save_image(blurry, os.path.join(assets, 'sample_blurry_image.jpg'))
print('  \u2713 sample_blurry_image.jpg created')

# ── audio: 1s sine wave at 440 Hz + gaussian noise ───────────────────────
try:
    import soundfile as sf
    sample_rate = 48000
    duration    = 1.5
    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
    signal  = 0.6 * np.sin(2 * np.pi * 440 * t)
    signal += 0.3 * np.sin(2 * np.pi * 880 * t)
    noise   = np.random.normal(0, 0.12, t.shape)
    audio   = np.clip((signal + noise).astype(np.float32), -1.0, 1.0)
    sf.write(os.path.join(assets, 'sample_audio.wav'), audio, sample_rate)
    print('  \u2713 sample_audio.wav created (48kHz,', duration, 's)')
except ImportError:
    print('  ! soundfile not installed — skipping sample_audio.wav')
    print('    Run: pip install soundfile   then re-run this script')

print('Test assets ready.')
PYEOF

# ─── STEP 2: Run pytest suites ─────────────────────────────────────────────
echo ""
echo "[2/3] Running integration tests..."
echo ""

SUITES=(
    "tests/test_real_esrgan.py"
    "tests/test_zero_dce.py"
    "tests/test_deblurgan.py"
    "tests/test_whisper.py"
    "tests/test_rnnoise.py"
    "tests/test_yolo.py"
)

PASSED_SUITES=()
FAILED_SUITES=()

for suite in "${SUITES[@]}"; do
    name=$(basename "$suite" .py)
    echo "───────────────────────────────────────────────"
    echo " Running: $suite"
    echo "───────────────────────────────────────────────"
    if python3 -m pytest "$suite" -v --tb=short --no-header 2>&1; then
        PASSED_SUITES+=("$name")
    else
        FAILED_SUITES+=("$name")
    fi
    echo ""
done

# ─── STEP 3: Summary ────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo " ALL INTEGRATION TESTS COMPLETE"
echo "================================================"
echo ""
echo "  PASSED (${#PASSED_SUITES[@]}):"
for s in "${PASSED_SUITES[@]}"; do
    echo "    ✓ $s"
done
if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
    echo ""
    echo "  FAILED (${#FAILED_SUITES[@]}):"
    for s in "${FAILED_SUITES[@]}"; do
        echo "    ✗ $s"
    done
    echo ""
    echo "TIP: 'SKIP' is normal for uninstalled libraries."
    echo "Run: bash setup/install_all.sh  then  bash setup/download_models.sh"
fi
echo ""
echo "================================================"
