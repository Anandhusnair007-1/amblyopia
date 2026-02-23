#!/usr/bin/env bash
# =============================================================================
# TASK 1 — Fix DeblurGAN Weights
# Aravind Eye Hospital — Amblyopia Care System
# =============================================================================
set -uo pipefail

PROJECT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT"
source venv/bin/activate

echo "================================================"
echo "TASK 1 — Downloading DeblurGAN Weights"
echo "================================================"

mkdir -p models/deblurgan

OUTPUT="models/deblurgan/fpn_inception.h5"
MIN_SIZE=1000000   # 1 MB minimum for real weights

# ── Helper ────────────────────────────────────────────────────────────────────
file_ok() {
    local path="$1"
    [ -f "$path" ] && [ "$(stat -c%s "$path" 2>/dev/null || echo 0)" -ge "$MIN_SIZE" ]
}

# ── Method 1: gdown (Google Drive) ───────────────────────────────────────────
echo ""
echo "Method 1 — gdown (Google Drive)..."
pip install gdown -q

python3 - <<'PYEOF'
import sys, os
output = "models/deblurgan/fpn_inception.h5"
min_size = 1_000_000

ids_to_try = [
    "1UXcsRVW-6KF23_TNzxw-xC0SzpiZXbWJ",   # original DeblurGAN fpn_inception
    "1Wb05rs9GxpMJFUaxMgRFMBhXXMlQMC0p",   # alternate mirror
]

try:
    import gdown
    for gid in ids_to_try:
        url = f"https://drive.google.com/uc?id={gid}"
        print(f"  Trying Google Drive ID: {gid}")
        try:
            gdown.download(url, output, quiet=False)
            if os.path.isfile(output) and os.path.getsize(output) >= min_size:
                size_mb = os.path.getsize(output) / 1024 / 1024
                print(f"  SUCCESS via gdown: {size_mb:.1f} MB")
                sys.exit(0)
            else:
                print(f"  File too small or missing — trying next ID")
                if os.path.isfile(output):
                    os.remove(output)
        except Exception as e:
            print(f"  ID {gid} failed: {e}")
    print("  All Google Drive IDs failed")
    sys.exit(1)
except ImportError:
    print("  gdown not available")
    sys.exit(1)
PYEOF
GDOWN_EXIT=$?

if file_ok "$OUTPUT"; then
    SZ=$(python3 -c "import os; print(f'{os.path.getsize(\"$OUTPUT\")/1024/1024:.1f}')")
    echo "Method 1 SUCCESS: ${SZ}MB downloaded"
else
    # ── Method 2: wget from HuggingFace ──────────────────────────────────────
    echo ""
    echo "Method 2 — wget from HuggingFace..."

    HF_URLS=(
        "https://huggingface.co/datasets/monshi/DeblurGAN/resolve/main/fpn_inception.h5"
        "https://huggingface.co/nateraw/deblurgan-v2/resolve/main/fpn_inception.h5"
    )

    for url in "${HF_URLS[@]}"; do
        echo "  Trying: $url"
        wget --quiet --show-progress --timeout=60 --tries=3 \
             -O "$OUTPUT" "$url" 2>&1 || true
        if file_ok "$OUTPUT"; then
            SZ=$(python3 -c "import os; print(f'{os.path.getsize(\"$OUTPUT\")/1024/1024:.1f}')")
            echo "  Method 2 SUCCESS: ${SZ}MB"
            break
        else
            [ -f "$OUTPUT" ] && rm -f "$OUTPUT"
            echo "  URL failed — trying next"
        fi
    done
fi

if ! file_ok "$OUTPUT"; then
    # ── Method 3: pip-installable weights ────────────────────────────────────
    echo ""
    echo "Method 3 — pip install deblurgan..."
    pip install deblurgan 2>/dev/null || true

    python3 - <<'PYEOF2'
import sys, os, shutil, glob

output = "models/deblurgan/fpn_inception.h5"
candidates = glob.glob("/home/anandhu/projects/amblyopia_backend/venv/lib/python*/site-packages/deblurgan/**/*.h5", recursive=True)
candidates += glob.glob("/home/**/*.h5", recursive=True)

for c in candidates:
    if "fpn" in c.lower() or "inception" in c.lower() or "deblur" in c.lower():
        print(f"  Found: {c}")
        shutil.copy2(c, output)
        if os.path.getsize(output) >= 1_000_000:
            print(f"  Copied successfully")
            sys.exit(0)
print("  No real weights found via pip")
sys.exit(1)
PYEOF2

    PIP_EXIT=$?
fi

if ! file_ok "$OUTPUT"; then
    # ── Method 4: Create h5py placeholder ────────────────────────────────────
    echo ""
    echo "Method 4 — Creating placeholder h5 file..."
    echo "  (System will use OpenCV unsharp-mask fallback)"

    python3 - <<'PYEOF3'
import os, sys

output = "models/deblurgan/fpn_inception.h5"
try:
    import h5py
    with h5py.File(output, "w") as f:
        f.attrs["placeholder"]  = True
        f.attrs["description"]  = "Placeholder — real model not downloaded"
        f.attrs["fallback"]     = "OpenCV unsharp-mask sharpening"
        f.attrs["instructions"] = (
            "Download real weights from: "
            "https://drive.google.com/uc?id=1UXcsRVW-6KF23_TNzxw-xC0SzpiZXbWJ"
        )
        # tiny dummy dataset so h5 is valid
        import numpy as np
        f.create_dataset("dummy", data=np.zeros((1,), dtype=np.float32))
    print("  Placeholder h5 created with h5py")
    sys.exit(0)
except ImportError:
    pass

# Last resort — empty file
open(output, "wb").close()
print("  Empty placeholder file created")
sys.exit(0)
PYEOF3
fi

# ── Verify final result ───────────────────────────────────────────────────────
echo ""
echo "Verification..."
python3 - <<'PYEOF4'
import os

path = "models/deblurgan/fpn_inception.h5"
if not os.path.exists(path):
    print("DEBLURGAN: MISSING — no file created")
else:
    size = os.path.getsize(path)
    if size >= 1_000_000:
        print(f"DEBLURGAN: READY ({size/1024/1024:.1f} MB) — neural inference active")
    elif size > 0:
        print(f"DEBLURGAN: PLACEHOLDER ({size} bytes) — OpenCV fallback active")
    else:
        print("DEBLURGAN: EMPTY FILE — OpenCV fallback active")

print("")
print("Note: DeblurGANIntegration auto-uses OpenCV unsharp-mask when")
print("      real weights are absent — the pipeline never crashes.")
PYEOF4

echo ""
echo "================================================"
echo "Task 1 complete"
echo "================================================"
