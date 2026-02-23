#!/bin/bash
# =============================================================================
# AMBLYOPIA SYSTEM — Running all fixes
# Target: 88% → 100%
# =============================================================================
set -uo pipefail

echo "============================================"
echo "AMBLYOPIA SYSTEM — Running all fixes"
echo "Project Path: /home/anandhu/projects/amblyopia_backend"
echo "============================================"
echo ""

PROJECT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT"

# Ensure venv exists
if [ ! -d "venv" ]; then
    echo "ERROR: Virtual environment not found. Please run setup first."
    exit 1
fi

source venv/bin/activate
mkdir -p fixes logs

# Make all fixes executable
chmod +x fixes/*.sh 2>/dev/null || true

PASS=0
FAIL=0

run_fix() {
    local name=$1
    local cmd=$2
    echo "--- FIX: $name ---"
    if eval "$cmd"; then
        echo "RESULT: COMPLETED — $name"
        PASS=$((PASS+1))
    else
        echo "RESULT: FAILED — $name"
        FAIL=$((FAIL+1))
    fi
    echo ""
}

# 1. RealESRGAN
run_fix "RealESRGAN torchvision" \
    "bash fixes/fix_realesrgan.sh"

# 2. RNNoise
run_fix "RNNoise C library" \
    "bash fixes/fix_rnnoise.sh"

# 3. API Paths
run_fix "API paths correction" \
    "python3 fixes/fix_api_paths.py"

# 4. Zero-DCE Test
run_fix "Zero-DCE brightness test" \
    "python3 fixes/fix_zero_dce_test.py"

# 5. YOLOv8 Test
run_fix "YOLOv8 synthetic eye test" \
    "python3 fixes/fix_yolo_test.py"

# 6. MLflow UI
# We run this last as it stays in background
run_fix "MLflow UI" \
    "bash fixes/fix_mlflow.sh"

echo "============================================"
echo "Running updated test suite..."
echo "============================================"

# Seed test data
echo "Seeding test database..."
python3 fixes/seed_test_data.py || true

# Run pytest on all integrations
pytest tests/ -v --tb=short -q | tee logs/final_test_results.txt

echo ""
echo "============================================"
echo "Running final health check..."
echo "============================================"

# Note: We use PYTHONPATH=. to ensure imports work
PYTHONPATH=. python3 setup/full_health_check.py | tee logs/final_health_report.txt

echo ""
echo "============================================"
echo "ALL FIXES COMPLETE"
echo "============================================"
echo "Fixes attempted: $((PASS+FAIL))"
echo "Passed:          $PASS"
echo "Failed:          $FAIL"
echo ""
echo "Reports saved:"
echo "  - logs/final_test_results.txt"
echo "  - logs/final_health_report.txt"
echo "  - logs/corrected_routes.json"
echo ""
echo "SERVICES LIVE:"
echo "  - API:    http://localhost:8000"
echo "  - Docs:   http://localhost:8000/docs"
echo "  - MLflow: http://localhost:5050"
echo "============================================"
