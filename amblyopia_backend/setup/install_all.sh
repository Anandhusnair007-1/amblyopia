#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Full Dependency Installer
# Aravind Eye Hospital, Coimbatore, India
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=============================================="
echo " AMBLYOPIA CARE SYSTEM — Dependency Installer"
echo "=============================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# ─── STEP 1: System dependencies ───────────────────────────────────────────
echo "[1/9] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    autoconf \
    automake \
    libtool \
    pkg-config
echo "✓ System dependencies installed"

# ─── STEP 2: Python virtual environment ────────────────────────────────────
echo ""
echo "[2/9] Creating Python virtual environment..."
python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate
echo "✓ Virtual environment created and activated"

# ─── STEP 3: Python packages ───────────────────────────────────────────────
echo ""
echo "[3/9] Installing Python packages..."
pip install --upgrade pip setuptools wheel

echo "  → Installing PyTorch (CPU)..."
pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cpu

echo "  → Installing Real-ESRGAN stack..."
pip install basicsr facexlib gfpgan realesrgan

echo "  → Installing vision + audio packages..."
pip install \
    opencv-python \
    numpy \
    Pillow \
    ultralytics \
    openai-whisper \
    soundfile \
    librosa \
    scipy \
    mlflow \
    pytest \
    pytest-asyncio

echo "✓ Python packages installed"

# ─── STEP 4: Clone Real-ESRGAN ─────────────────────────────────────────────
echo ""
echo "[4/9] Cloning Real-ESRGAN..."
mkdir -p integrations
cd integrations

if [ -d "Real-ESRGAN" ]; then
    echo "  Real-ESRGAN already cloned, pulling latest..."
    cd Real-ESRGAN && git pull && cd ..
else
    git clone https://github.com/xinntao/Real-ESRGAN
    cd Real-ESRGAN
    pip install -r requirements.txt
    python setup.py develop
    cd ..
fi
cd "$PROJECT_ROOT"
echo "✓ Real-ESRGAN ready"

# ─── STEP 5: Clone Zero-DCE ────────────────────────────────────────────────
echo ""
echo "[5/9] Cloning Zero-DCE..."
cd integrations
if [ -d "Zero-DCE" ]; then
    echo "  Zero-DCE already cloned, pulling latest..."
    cd Zero-DCE && git pull && cd ..
else
    git clone https://github.com/Thehunk1206/Zero-DCE
fi
cd "$PROJECT_ROOT"
echo "✓ Zero-DCE ready"

# ─── STEP 6: Clone DeblurGAN-v2 ────────────────────────────────────────────
echo ""
echo "[6/9] Cloning DeblurGAN-v2..."
cd integrations
if [ -d "DeblurGANv2" ]; then
    echo "  DeblurGANv2 already cloned, pulling latest..."
    cd DeblurGANv2 && git pull && cd ..
else
    git clone https://github.com/KAIR-IBD/DeblurGANv2
    cd DeblurGANv2
    # Install requirements, skip errors for optional deps
    pip install -r requirements.txt || true
    cd ..
fi
cd "$PROJECT_ROOT"
echo "✓ DeblurGAN-v2 ready"

# ─── STEP 7: Clone and build RNNoise ───────────────────────────────────────
echo ""
echo "[7/9] Cloning and building RNNoise..."
cd integrations
if [ -d "rnnoise" ]; then
    echo "  rnnoise already cloned"
else
    git clone https://github.com/xiph/rnnoise
fi
cd rnnoise
if [ ! -f "configure" ]; then
    ./autogen.sh
fi
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
cd "$PROJECT_ROOT"
echo "✓ RNNoise built and installed"

# ─── STEP 8: Clone and build whisper.cpp ───────────────────────────────────
echo ""
echo "[8/9] Cloning whisper.cpp..."
cd integrations
if [ -d "whisper.cpp" ]; then
    echo "  whisper.cpp already cloned, pulling latest..."
    cd whisper.cpp && git pull && make -j"$(nproc)" && cd ..
else
    git clone https://github.com/ggerganov/whisper.cpp
    cd whisper.cpp
    make -j"$(nproc)"
    cd ..
fi
cd "$PROJECT_ROOT"
echo "✓ whisper.cpp built"

# ─── STEP 9: Final message ─────────────────────────────────────────────────
echo ""
echo "=============================================="
echo " ALL DEPENDENCIES INSTALLED SUCCESSFULLY ✓"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Download ML model weights:"
echo "       bash setup/download_models.sh"
echo ""
echo "  2. Verify your installation:"
echo "       bash setup/verify_installation.sh"
echo ""
echo "  3. Run all integration tests:"
echo "       bash setup/test_all_integrations.sh"
