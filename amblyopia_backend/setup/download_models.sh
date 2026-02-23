#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Model Download Script
# Downloads all pretrained ML model weights
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ── Activate venv if present (so packages installed by install_all.sh are used)
if [ -f "venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source venv/bin/activate
    echo "[venv] Activated: $(which python3)"
else
    echo "[venv] No venv found — using system python3"
fi

echo "=============================================="
echo " AMBLYOPIA CARE SYSTEM — Model Downloader"
echo "=============================================="

FAILED_DOWNLOADS=()

download_file() {
    local url="$1"
    local dest="$2"
    local name="$3"
    echo "  → Downloading $name..."
    if wget -q --show-progress -O "$dest" "$url"; then
        local size
        size=$(du -sh "$dest" | cut -f1)
        echo "    ✓ $name downloaded ($size)"
    else
        echo "    ✗ FAILED: $name"
        echo "      URL: $url"
        echo "      Manual: wget -O $dest '$url'"
        FAILED_DOWNLOADS+=("$name")
        rm -f "$dest"
    fi
}

# ─── STEP 1: Create model directories ──────────────────────────────────────
echo ""
echo "[1/7] Creating model directories..."
mkdir -p models/real_esrgan
mkdir -p models/zero_dce
mkdir -p models/deblurgan
mkdir -p models/whisper
mkdir -p models/yolo
echo "✓ Model directories created"

# ─── STEP 2: Real-ESRGAN ───────────────────────────────────────────────────
echo ""
echo "[2/7] Downloading Real-ESRGAN weights..."

if [ ! -f "models/real_esrgan/RealESRGAN_x4plus.pth" ]; then
    download_file \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
        "models/real_esrgan/RealESRGAN_x4plus.pth" \
        "RealESRGAN_x4plus.pth"
else
    echo "  ✓ RealESRGAN_x4plus.pth already exists, skipping"
fi

if [ ! -f "models/real_esrgan/RealESRGAN_x4plus_anime_6B.pth" ]; then
    download_file \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth" \
        "models/real_esrgan/RealESRGAN_x4plus_anime_6B.pth" \
        "RealESRGAN_x4plus_anime_6B.pth"
else
    echo "  ✓ RealESRGAN_x4plus_anime_6B.pth already exists, skipping"
fi

# ─── STEP 3: Zero-DCE ────────────────────────────────────────────────
echo ""
echo "[3/7] Downloading Zero-DCE weights..."

# Canonical source: Li-Chongyi/Zero-DCE official repo (Epoch99.pth)
# Thehunk1206's fork does not host a downloadable snapshot publicly.
ZERO_DCE_URL="https://github.com/Li-Chongyi/Zero-DCE/raw/master/Zero-DCE_code/snapshots/Epoch99.pth"
ZERO_DCE_ALT="https://github.com/Li-Chongyi/Zero-DCE/releases/download/v1.0/best_model.pth"

if [ ! -f "models/zero_dce/zero_dce_weights.pth" ]; then
    echo "  → Trying Li-Chongyi/Zero-DCE official weights..."
    if wget -q --show-progress -O models/zero_dce/zero_dce_weights.pth "$ZERO_DCE_URL" 2>/dev/null && [ -s models/zero_dce/zero_dce_weights.pth ]; then
        size=$(du -sh models/zero_dce/zero_dce_weights.pth | cut -f1)
        echo "    ✓ zero_dce_weights.pth downloaded ($size)"
    else
        rm -f models/zero_dce/zero_dce_weights.pth
        echo "    ✗ Primary URL failed. SKIP: Zero-DCE weights (model not publicly released)"
        echo "      The Zero-DCE integration uses a built-in re-implementation."
        echo "      Download manually from: https://github.com/Li-Chongyi/Zero-DCE"
        echo "      Save to: models/zero_dce/zero_dce_weights.pth"
        FAILED_DOWNLOADS+=("Zero-DCE weights (optional — fallback available)")
    fi
else
    echo "  ✓ zero_dce_weights.pth already exists, skipping"
fi

# ─── STEP 4: DeblurGAN-v2 ──────────────────────────────────────────────────
echo ""
echo "[4/7] Downloading DeblurGAN-v2 weights..."

if [ ! -f "models/deblurgan/fpn_inception.h5" ]; then
    echo "  → DeblurGAN requires gdown (Google Drive download)..."
    pip install gdown -q || true
    if python3 -c "import gdown" 2>/dev/null; then
        python3 -c "
import gdown
gdown.download(
    'https://drive.google.com/uc?id=1UXcsRVW-6KF23_TNzxw-xC0SzpiZXbWJ',
    'models/deblurgan/fpn_inception.h5',
    quiet=False
)
print('DeblurGAN weights downloaded')
" || {
            echo "    ✗ FAILED: fpn_inception.h5"
            echo "      Manual: Visit https://drive.google.com/file/d/1UXcsRVW-6KF23_TNzxw-xC0SzpiZXbWJ"
            echo "      Save to: models/deblurgan/fpn_inception.h5"
            FAILED_DOWNLOADS+=("DeblurGAN fpn_inception.h5")
        }
    else
        echo "    ✗ gdown not available. Manual download required."
        FAILED_DOWNLOADS+=("DeblurGAN fpn_inception.h5")
    fi
else
    echo "  ✓ fpn_inception.h5 already exists, skipping"
fi

# ─── STEP 5: Whisper ───────────────────────────────────────────────────────
echo ""
echo "[5/7] Downloading Whisper models..."

# Download via OpenAI Whisper Python package
echo "  → Downloading via Python whisper package..."
python3 -c "
import whisper, os
os.makedirs('models/whisper', exist_ok=True)

for model_size in ['tiny', 'small']:
    print(f'  Downloading whisper {model_size}...')
    try:
        m = whisper.load_model(model_size, download_root='models/whisper')
        print(f'  ✓ whisper-{model_size} downloaded')
    except Exception as e:
        print(f'  ✗ whisper-{model_size} failed: {e}')
" || {
    echo "    ✗ Whisper Python download failed"
    FAILED_DOWNLOADS+=("Whisper models")
}

# Also download via whisper.cpp if available
if [ -d "integrations/whisper.cpp" ]; then
    echo "  → Downloading whisper.cpp GGML models..."
    cd integrations/whisper.cpp
    bash ./models/download-ggml-model.sh tiny  || true
    bash ./models/download-ggml-model.sh small || true
    [ -f "models/ggml-tiny.bin"  ] && cp models/ggml-tiny.bin  ../../models/whisper/ && echo "  ✓ ggml-tiny.bin copied"
    [ -f "models/ggml-small.bin" ] && cp models/ggml-small.bin ../../models/whisper/ && echo "  ✓ ggml-small.bin copied"
    cd "$PROJECT_ROOT"
fi

# ─── STEP 6: YOLOv8 ────────────────────────────────────────────────
echo ""
echo "[6/7] Downloading YOLOv8 weights..."

if [ ! -f "models/yolo/yolov8n.pt" ]; then
    if python3 -c "from ultralytics import YOLO" 2>/dev/null; then
        python3 -c "
from ultralytics import YOLO
import shutil, os
os.makedirs('models/yolo', exist_ok=True)
model = YOLO('yolov8n.pt')  # auto-downloads
src = 'yolov8n.pt'
if os.path.exists(src):
    shutil.copy(src, 'models/yolo/yolov8n.pt')
    print('YOLOv8n downloaded to models/yolo/yolov8n.pt')
" || { echo "    ✗ FAILED: yolov8n.pt"; FAILED_DOWNLOADS+=("YOLOv8n"); }
    else
        # Direct download from GitHub releases as fallback
        echo "  → ultralytics not installed — downloading yolov8n.pt directly..."
        download_file \
            "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt" \
            "models/yolo/yolov8n.pt" \
            "yolov8n.pt"
    fi
else
    echo "  ✓ yolov8n.pt already exists, skipping"
fi

# ─── STEP 7: Verify all downloads ──────────────────────────────────────────
echo ""
echo "[7/7] Verifying downloads..."
echo ""

verify_file() {
    local path="$1"
    local name="$2"
    if [ -f "$path" ] && [ -s "$path" ]; then
        local size
        size=$(du -sh "$path" | cut -f1)
        local checksum
        checksum=$(md5sum "$path" | cut -d' ' -f1)
        echo "  ✓ $name ($size) — MD5: $checksum"
    else
        echo "  ✗ MISSING: $name"
    fi
}

verify_file "models/real_esrgan/RealESRGAN_x4plus.pth"       "RealESRGAN_x4plus.pth"
verify_file "models/real_esrgan/RealESRGAN_x4plus_anime_6B.pth" "RealESRGAN_anime.pth"
verify_file "models/zero_dce/zero_dce_weights.pth"           "Zero-DCE weights"
verify_file "models/deblurgan/fpn_inception.h5"               "DeblurGAN weights"
verify_file "models/whisper/ggml-tiny.bin"                    "Whisper tiny (GGML)"
verify_file "models/whisper/ggml-small.bin"                   "Whisper small (GGML)"
verify_file "models/yolo/yolov8n.pt"                          "YOLOv8n"

echo ""
if [ ${#FAILED_DOWNLOADS[@]} -eq 0 ]; then
    echo "=============================================="
    echo " ALL MODELS DOWNLOADED SUCCESSFULLY ✓"
    echo "=============================================="
else
    echo "=============================================="
    echo " DOWNLOAD COMPLETE — ${#FAILED_DOWNLOADS[@]} failed:"
    for f in "${FAILED_DOWNLOADS[@]}"; do
        echo "   ✗ $f"
    done
    echo "=============================================="
    echo " Re-run after fixing network/permissions."
fi
