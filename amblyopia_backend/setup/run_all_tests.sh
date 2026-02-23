#!/usr/bin/env bash
# =============================================================================
# TASK 2 — Run All Integration Tests
# Aravind Eye Hospital — Amblyopia Care System
# =============================================================================
set -uo pipefail

PROJECT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT"
source venv/bin/activate

echo "================================================"
echo "TASK 2 — Running All Integration Tests"
echo "================================================"
echo ""

# ── Create test assets first ──────────────────────────────────────────────────
echo "Step 1: Creating test assets..."
PYTHONPATH="$PROJECT" python3 setup/create_test_assets.py
echo ""

# ── Ensure pytest is installed ────────────────────────────────────────────────
pip install pytest pytest-asyncio -q

# ── Track results ─────────────────────────────────────────────────────────────
PASS=0
FAIL=0
declare -A TEST_RESULTS

mkdir -p logs

run_test() {
    local name="$1"
    local file="$2"

    echo "──────────────────────────────────────────────"
    echo "Testing: $name"
    echo "File:    $file"
    echo ""

    if [ ! -f "$file" ]; then
        echo "  SKIP — file not found: $file"
        TEST_RESULTS["$name"]="SKIP"
        return
    fi

    # Run pytest, capture output, show inline
    PYTHONPATH="$PROJECT" pytest "$file" \
        -v \
        --tb=short \
        --no-header \
        -p no:warnings \
        2>&1 | tee -a "logs/test_${name}.log"

    local exit_code=${PIPESTATUS[0]}

    if [ "$exit_code" -eq 0 ]; then
        echo ""
        echo "RESULT: ✓ PASS — $name"
        TEST_RESULTS["$name"]="PASS"
        PASS=$((PASS + 1))
    else
        echo ""
        echo "RESULT: ✗ FAIL — $name  (exit $exit_code)"
        TEST_RESULTS["$name"]="FAIL"
        FAIL=$((FAIL + 1))
    fi
    echo ""
}

# ── Run each integration test suite ──────────────────────────────────────────
echo "Step 2: Running test suites..."
echo ""

run_test "real_esrgan" "tests/test_real_esrgan.py"
run_test "zero_dce"    "tests/test_zero_dce.py"
run_test "deblurgan"   "tests/test_deblurgan.py"
run_test "whisper"     "tests/test_whisper.py"
run_test "rnnoise"     "tests/test_rnnoise.py"
run_test "yolo"        "tests/test_yolo.py"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))

echo ""
echo "================================================"
echo "INTEGRATION TEST SUMMARY"
echo "================================================"
for name in "${!TEST_RESULTS[@]}"; do
    result="${TEST_RESULTS[$name]}"
    if [ "$result" = "PASS" ]; then
        echo "  ✓ PASS — $name"
    elif [ "$result" = "SKIP" ]; then
        echo "  - SKIP — $name"
    else
        echo "  ✗ FAIL — $name"
    fi
done
echo "──────────────────────────────────────────────"
echo "  PASSED:  $PASS / $TOTAL"
echo "  FAILED:  $FAIL / $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "  STATUS: ✓ ALL TESTS PASSED"
else
    echo "  STATUS: $FAIL SUITE(S) NEED ATTENTION"
    echo ""
    echo "  Common reasons for SKIP (not failures):"
    echo "    → Model weights not downloaded (SKIP expected)"
    echo "    → RNNoise not compiled (SKIP expected)"
    echo "    → Whisper package not installed (SKIP expected)"
    echo "  These are handled by classical fallbacks."
fi
echo "================================================"
echo ""
echo "Logs saved to: $PROJECT/logs/test_*.log"
