#!/bin/bash
# =============================================================================
# FIX 1 — Installing torchvision for RealESRGAN
# =============================================================================
set -uo pipefail

echo "============================================"
echo "FIX 1 — Installing torchvision for RealESRGAN"
echo "============================================"

PROJECT_ROOT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT_ROOT"

if [ ! -d "venv" ]; then
    echo "ERROR: Virtual environment not found at $PROJECT_ROOT/venv"
    exit 1
fi

source venv/bin/activate

# Step 1: Check current torch version
echo "Current torch version:"
python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "torch not installed"

# Step 2: Get matching torchvision version
echo ""
echo "Installing matching torchvision..."
python3 -c "
import subprocess
import sys

# Get current torch version
try:
    import torch
    torch_ver = torch.__version__
    print(f'Torch version: {torch_ver}')
    
    # Map torch version to torchvision version
    # Extended version map for robustness
    version_map = {
        '2.10': 'torchvision', # Latest
        '2.5' : 'torchvision==0.20.1',
        '2.4' : 'torchvision==0.19.1',
        '2.3' : 'torchvision==0.18.0',
        '2.2' : 'torchvision==0.17.2',
        '2.1' : 'torchvision==0.16.2',
        '2.0' : 'torchvision==0.15.2',
        '1.13': 'torchvision==0.14.1',
        '1.12': 'torchvision==0.13.1',
    }
    
    matched = None
    for ver_prefix, tv_pkg in version_map.items():
        if torch_ver.startswith(ver_prefix):
            matched = tv_pkg
            break
    
    if matched:
        print(f'Installing: {matched}')
        subprocess.check_call([
            sys.executable, '-m', 'pip',
            'install', matched, '--index-url', 'https://download.pytorch.org/whl/cpu', '-q'
        ])
    else:
        print(f'Unknown torch version: {torch_ver}')
        print('Trying generic install...')
        subprocess.check_call([
            sys.executable, '-m', 'pip',
            'install', 'torchvision', '--index-url', 'https://download.pytorch.org/whl/cpu', '-q'
        ])
        
except ImportError:
    print('Torch not found, installing CPU version...')
    subprocess.check_call([
        sys.executable, '-m', 'pip', 'install',
        'torch', 'torchvision', 'torchaudio',
        '--index-url',
        'https://download.pytorch.org/whl/cpu',
        '-q'
    ])
"

# Step 3: Verify torchvision installed
echo ""
echo "Verifying torchvision..."
python3 -c "
try:
    import torchvision
    print(f'torchvision version: {torchvision.__version__}')
    print('torchvision: INSTALLED OK')
except ImportError:
    print('torchvision: FAILED TO INSTALL')
"

# Step 4: Verify RealESRGAN integration loads
echo ""
echo "Testing RealESRGAN integration..."
python3 -c "
import sys
import os
sys.path.insert(0, '/home/anandhu/projects/amblyopia_backend')
os.chdir('/home/anandhu/projects/amblyopia_backend')

# Monkey-patch basicsr compatibility for torchvision 0.17+
try:
    import torchvision.transforms.functional as F
    sys.modules['torchvision.transforms.functional_tensor'] = F
except:
    pass

try:
    from integrations.real_esrgan_integration import (
        RealESRGANIntegration
    )
    model_path = 'models/real_esrgan/RealESRGAN_x4plus.pth'
    
    if os.path.exists(model_path):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            r = RealESRGANIntegration(model_path)
            print('RealESRGAN: LOADED SUCCESSFULLY')
    else:
        print(f'Model missing: {model_path}')
        print('Run: bash setup/download_models.sh')
except Exception as e:
    print(f'RealESRGAN load error: {e}')
"

echo ""
echo "Fix 1 complete"
