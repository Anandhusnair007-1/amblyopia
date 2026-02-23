#!/bin/bash
# =============================================================================
# FIX 2 — Compiling RNNoise C library
# =============================================================================
set -uo pipefail

echo "============================================"
echo "FIX 2 — Compiling RNNoise C library"
echo "============================================"

PROJECT_ROOT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT_ROOT"

# Step 1: Install build dependencies (Skip sudo in non-interactive)
echo "Checking build tools..."
# Attempting to continue if tools already exist
if ! command -v autoconf &> /dev/null; then
    echo "WARNING: autoconf not found. Skipping compilation."
    # We will let the script proceed to Step 6 (Python fallback)
fi

# Step 2: Check if rnnoise already cloned
if [ ! -d "integrations/rnnoise" ]; then
    echo "Cloning RNNoise from xiph/rnnoise..."
    mkdir -p integrations
    cd integrations
    git clone --depth=1 https://github.com/xiph/rnnoise.git
    cd ..
else
    echo "RNNoise already cloned"
fi

# Step 3: Compile
echo ""
echo "Compiling RNNoise..."
if [ -d "integrations/rnnoise" ]; then
    cd integrations/rnnoise
    ./autogen.sh 2>/dev/null || autoreconf --install
    ./configure --prefix=/usr/local
    
    # Note: make may fail if training data is missing (rnnoise_data.c)
    # We attempt it, but the fallback in Python will handle failure.
    if make -j$(nproc); then
        # Step 4: Use local lib instead of install
        echo "Compilation successful. Copying to integrations/..."
        LOCAL_LIB=$(find . -name "librnnoise.so*" | head -1)
        cp "$LOCAL_LIB" ../librnnoise.so
    else
        echo "WARNING: Compilation failed (likely missing rnnoise_data.c)."
        echo "System will use Python 'noisereduce' fallback."
    fi
    cd "$PROJECT_ROOT"
fi

# Step 5: Verify installation
echo ""
echo "Verifying RNNoise installation..."
if [ -f "integrations/librnnoise.so" ]; then
    echo "RNNoise: LOCAL LIBRARY FOUND"
else
    echo "System install check..."
    if ldconfig -p 2>/dev/null | grep -q "librnnoise"; then
        echo "RNNoise: INSTALLED IN SYSTEM"
    else
        echo "No library found. Python noisereduce fallback will be used."
    fi
fi

# Step 6: Test Python wrapper
echo ""
echo "Testing RNNoise Python wrapper..."
source venv/bin/activate
python3 -c "
import sys
import os
sys.path.insert(0, '$PROJECT_ROOT')

try:
    from integrations.rnnoise_integration import RNNoiseIntegration
    rnn = RNNoiseIntegration()
    print(f'RNNoise integration: LOADED OK (Backend: {rnn.backend})')
except Exception as e:
    print(f'RNNoise load error: {e}')
"

echo ""
echo "Fix 2 complete"
