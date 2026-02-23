#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Installation Verifier
# Checks all dependencies, model files, cloned repos, and integration health
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

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)); }
fail() { echo "  ✗ $1"; ((FAIL++)); }

check_python_package() {
    local pkg="$1" label="${2:-$1}"
    if python3 -c "import $pkg" 2>/dev/null; then
        pass "Python: $label"
    else
        fail "Python: $label (pip install $pkg)"
    fi
}

check_file() {
    local path="$1" label="$2"
    if [ -f "$path" ] && [ -s "$path" ]; then
        local size; size=$(du -sh "$path" | cut -f1)
        pass "File: $label ($size)"
    else
        fail "File: $label — MISSING at $path"
    fi
}

check_dir() {
    local path="$1" label="$2"
    if [ -d "$path" ]; then
        pass "Repo: $label"
    else
        fail "Repo: $label — not cloned at $path"
    fi
}

echo "================================================"
echo " AMBLYOPIA CARE SYSTEM — Dependency Report"
echo " $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================"

# ─── CHECK 1: Python packages ───────────────────────────────────────────────
echo ""
echo "── Python Packages ────────────────────────────"
check_python_package "torch"        "PyTorch"
check_python_package "torchvision"  "torchvision"
check_python_package "cv2"          "OpenCV"
check_python_package "realesrgan"   "Real-ESRGAN"
check_python_package "whisper"      "OpenAI Whisper"
check_python_package "ultralytics"  "YOLOv8 (ultralytics)"
check_python_package "mlflow"       "MLflow"
check_python_package "soundfile"    "SoundFile"
check_python_package "librosa"      "librosa"
check_python_package "scipy"        "scipy"
check_python_package "numpy"        "numpy"
check_python_package "PIL"          "Pillow"

# ─── CHECK 2: Model files ───────────────────────────────────────────────────
echo ""
echo "── Model Weights ──────────────────────────────"
check_file "models/real_esrgan/RealESRGAN_x4plus.pth"       "RealESRGAN_x4plus.pth"
check_file "models/real_esrgan/RealESRGAN_x4plus_anime_6B.pth" "RealESRGAN_anime_6B.pth"
check_file "models/zero_dce/zero_dce_weights.pth"           "Zero-DCE weights"
check_file "models/deblurgan/fpn_inception.h5"               "DeblurGAN FPN Inception"
check_file "models/whisper/ggml-tiny.bin"                    "Whisper tiny (GGML)"
check_file "models/whisper/ggml-small.bin"                   "Whisper small (GGML)"
check_file "models/yolo/yolov8n.pt"                          "YOLOv8-nano"

# ─── CHECK 3: Cloned repos ──────────────────────────────────────────────────
echo ""
echo "── Cloned Repositories ────────────────────────"
check_dir "integrations/Real-ESRGAN"   "Real-ESRGAN"
check_dir "integrations/Zero-DCE"      "Zero-DCE"
check_dir "integrations/DeblurGANv2"   "DeblurGAN-v2"
check_dir "integrations/rnnoise"       "RNNoise"
check_dir "integrations/whisper.cpp"   "whisper.cpp"

# ─── CHECK 4: RNNoise compiled ─────────────────────────────────────────────
echo ""
echo "── Compiled Libraries ─────────────────────────"
RNNOISE_FOUND=false
for lib_path in \
    "/usr/local/lib/librnnoise.so" \
    "/usr/local/lib/librnnoise.so.0" \
    "/usr/lib/librnnoise.so" \
    "integrations/rnnoise/.libs/librnnoise.so"
do
    if [ -f "$lib_path" ]; then
        pass "RNNoise compiled — $lib_path"
        RNNOISE_FOUND=true
        break
    fi
done
if [ "$RNNOISE_FOUND" = false ]; then
    fail "RNNoise — librnnoise.so not found (run: cd integrations/rnnoise && make && sudo make install)"
fi

# ─── CHECK 5: Integration self-tests ───────────────────────────────────────
echo ""
echo "── Integration Health Checks ──────────────────"
declare -A INTEGRATION_STATUS

# Real-ESRGAN
if python3 -c "
import sys, os
sys.path.insert(0, '.')
from integrations.real_esrgan_integration import RealESRGANIntegration
model_path = 'models/real_esrgan/RealESRGAN_x4plus.pth'
if os.path.exists(model_path):
    r = RealESRGANIntegration(model_path)
    print('OK')
else:
    print('MODEL_MISSING')
" 2>/dev/null | grep -q "OK"; then
    pass "Real-ESRGAN integration"
    INTEGRATION_STATUS["real_esrgan"]="READY"
else
    fail "Real-ESRGAN integration (model missing or import error)"
    INTEGRATION_STATUS["real_esrgan"]="NOT READY"
fi

# Zero-DCE
if python3 -c "
import sys
sys.path.insert(0, '.')
from integrations.zero_dce_integration import ZeroDCEIntegration
import os
model_path = 'models/zero_dce/zero_dce_weights.pth'
if os.path.exists(model_path):
    z = ZeroDCEIntegration(model_path)
    print('OK')
else:
    print('MODEL_MISSING')
" 2>/dev/null | grep -q "OK"; then
    pass "Zero-DCE integration"
    INTEGRATION_STATUS["zero_dce"]="READY"
else
    fail "Zero-DCE integration (model missing or import error)"
    INTEGRATION_STATUS["zero_dce"]="NOT READY"
fi

# DeblurGAN
if python3 -c "
import sys
sys.path.insert(0, '.')
from integrations.deblurgan_integration import DeblurGANIntegration
import os
model_path = 'models/deblurgan/fpn_inception.h5'
if os.path.exists(model_path):
    d = DeblurGANIntegration(model_path)
    print('OK')
else:
    print('MODEL_MISSING')
" 2>/dev/null | grep -q "OK"; then
    pass "DeblurGAN integration"
    INTEGRATION_STATUS["deblurgan"]="READY"
else
    fail "DeblurGAN integration (model missing or import error)"
    INTEGRATION_STATUS["deblurgan"]="NOT READY"
fi

# Whisper
if python3 -c "
import sys
sys.path.insert(0, '.')
from integrations.whisper_integration import WhisperIntegration
w = WhisperIntegration(model_size='tiny')
print('OK')
" 2>/dev/null | grep -q "OK"; then
    pass "Whisper integration"
    INTEGRATION_STATUS["whisper"]="READY"
else
    fail "Whisper integration (import error)"
    INTEGRATION_STATUS["whisper"]="NOT READY"
fi

# RNNoise
if python3 -c "
import sys
sys.path.insert(0, '.')
from integrations.rnnoise_integration import RNNoiseIntegration
try:
    r = RNNoiseIntegration()
    print('OK')
except RuntimeError:
    print('LIB_MISSING')
" 2>/dev/null | grep -q "OK"; then
    pass "RNNoise integration"
    INTEGRATION_STATUS["rnnoise"]="READY"
else
    fail "RNNoise integration (library not compiled)"
    INTEGRATION_STATUS["rnnoise"]="NOT READY"
fi

# YOLO
if python3 -c "
import sys
sys.path.insert(0, '.')
from integrations.yolo_integration import YOLOIntegration
import os
model_path = 'models/yolo/yolov8n.pt'
if os.path.exists(model_path):
    y = YOLOIntegration(model_path)
    print('OK')
else:
    print('MODEL_MISSING')
" 2>/dev/null | grep -q "OK"; then
    pass "YOLO integration"
    INTEGRATION_STATUS["yolo"]="READY"
else
    fail "YOLO integration (model missing or import error)"
    INTEGRATION_STATUS["yolo"]="NOT READY"
fi

# ─── Final report ───────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo ""
echo "================================================"
echo " AMBLYOPIA SYSTEM — DEPENDENCY REPORT"
echo "================================================"
printf "  Real-ESRGAN:    [%s]\n" "${INTEGRATION_STATUS[real_esrgan]:-UNKNOWN}"
printf "  Zero-DCE:       [%s]\n" "${INTEGRATION_STATUS[zero_dce]:-UNKNOWN}"
printf "  DeblurGAN:      [%s]\n" "${INTEGRATION_STATUS[deblurgan]:-UNKNOWN}"
printf "  Whisper:        [%s]\n" "${INTEGRATION_STATUS[whisper]:-UNKNOWN}"
printf "  RNNoise:        [%s]\n" "${INTEGRATION_STATUS[rnnoise]:-UNKNOWN}"
printf "  YOLOv8:         [%s]\n" "${INTEGRATION_STATUS[yolo]:-UNKNOWN}"
echo "------------------------------------------------"
echo "  Checks: $PASS/$TOTAL passed"
if [ "$FAIL" -eq 0 ]; then
    echo "  OVERALL: ALL READY ✓"
else
    echo "  OVERALL: $FAIL checks need attention ✗"
    echo "  Run: bash setup/install_all.sh"
    echo "  Then: bash setup/download_models.sh"
fi
echo "================================================"
