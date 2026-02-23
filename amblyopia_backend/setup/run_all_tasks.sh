#!/usr/bin/env bash
# =============================================================================
# MASTER — Run All 6 Tasks in Order
# Aravind Eye Hospital — Amblyopia Care System
# =============================================================================
set -uo pipefail

PROJECT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT"
source venv/bin/activate

LOG_DIR="$PROJECT/logs"
mkdir -p "$LOG_DIR"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m';  BOLD='\033[1m';   NC='\033[0m'

task_header() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $*${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"
}

task_pass() { echo -e "${GREEN}✓ TASK $1 COMPLETE — $2${NC}"; }
task_fail() { echo -e "${RED}✗ TASK $1 HAD ISSUES — $2${NC}"; }

declare -A TASK_STATUS

run_task() {
    local num="$1" label="$2" cmd="$3"
    task_header "TASK $num/6 — $label"

    if eval "$cmd"; then
        TASK_STATUS[$num]="PASS"
        task_pass "$num" "$label"
    else
        TASK_STATUS[$num]="FAIL"
        task_fail "$num" "$label"
    fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   AMBLYOPIA CARE SYSTEM — FULL SETUP RUNNER      ║${NC}"
echo -e "${BOLD}║   Aravind Eye Hospital, Coimbatore, India         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  6 tasks will run in sequence."
echo "  Total estimated time: 3–10 minutes"
echo "  Logs: $LOG_DIR/"
echo ""

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 1 — Fix DeblurGAN
# └────────────────────────────────────────────────────────────────────────────
run_task 1 "Fix DeblurGAN Weights" \
    "bash setup/fix_deblurgan.sh 2>&1 | tee $LOG_DIR/task1_deblurgan.log"

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 2 — Integration Tests
# └────────────────────────────────────────────────────────────────────────────
run_task 2 "Integration Tests" \
    "bash setup/run_all_tests.sh 2>&1 | tee $LOG_DIR/task2_integration_tests.log"

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 3 — API Tests  (backend must be running)
# └────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}  Checking if backend is running for Task 3...${NC}"
if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}Backend is running ✓${NC}"
    run_task 3 "API Tests" \
        "PYTHONPATH=$PROJECT python3 setup/test_all_apis.py 2>&1 | tee $LOG_DIR/task3_api_tests.log"
else
    echo -e "  ${YELLOW}Backend not running — starting it in background for Task 3...${NC}"
    PYTHONPATH="$PROJECT" uvicorn app.main:app \
        --host 127.0.0.1 --port 8000 \
        --log-level warning \
        > "$LOG_DIR/task3_uvicorn.log" 2>&1 &
    UVICORN_PID=$!
    echo "  Uvicorn PID: $UVICORN_PID"
    sleep 6

    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}Backend started ✓${NC}"
        run_task 3 "API Tests" \
            "PYTHONPATH=$PROJECT python3 setup/test_all_apis.py 2>&1 | tee $LOG_DIR/task3_api_tests.log"
        # Leave it running — user may want it
    else
        echo -e "  ${RED}Backend failed to start — skipping Task 3${NC}"
        echo -e "  Run manually: bash run_local.sh"
        TASK_STATUS[3]="SKIP"
        task_fail "3" "Backend not available — run: bash run_local.sh first, then re-run Task 3"
    fi
fi

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 4 — Make Persistent
# └────────────────────────────────────────────────────────────────────────────
run_task 4 "Make Backend Persistent" \
    "bash setup/make_persistent.sh 2>&1 | tee $LOG_DIR/task4_persistence.log"

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 5 — Verify Database
# └────────────────────────────────────────────────────────────────────────────
run_task 5 "Verify 14 Database Tables" \
    "PYTHONPATH=$PROJECT python3 setup/verify_database.py 2>&1 | tee $LOG_DIR/task5_database.log"

# ┌────────────────────────────────────────────────────────────────────────────
# │ TASK 6 — Full Health Check
# └────────────────────────────────────────────────────────────────────────────
run_task 6 "Full Health Check" \
    "PYTHONPATH=$PROJECT python3 setup/full_health_check.py 2>&1 | tee $LOG_DIR/task6_health_check.log"

# ── Final Summary ─────────────────────────────────────────────────────────────
ALL_PASS=true
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  ALL TASKS SUMMARY${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

for num in 1 2 3 4 5 6; do
    status="${TASK_STATUS[$num]:-SKIP}"
    labels=( "" "Fix DeblurGAN" "Integration Tests" "API Tests" "Make Persistent" "Verify Database" "Health Check" )
    label="${labels[$num]}"
    if [ "$status" = "PASS" ]; then
        echo -e "  ${GREEN}✓ TASK $num — $label${NC}"
    elif [ "$status" = "SKIP" ]; then
        echo -e "  ${YELLOW}- TASK $num — $label (SKIPPED)${NC}"
    else
        echo -e "  ${RED}✗ TASK $num — $label (FAILED — check logs)${NC}"
        ALL_PASS=false
    fi
done

echo ""
echo "  Log files:"
for f in "$LOG_DIR"/task*.log; do
    [ -f "$f" ] && echo "    $f"
done
echo ""

if $ALL_PASS; then
    echo -e "  ${GREEN}${BOLD}STATUS: ALL TASKS COMPLETE ✓${NC}"
else
    echo -e "  ${YELLOW}${BOLD}STATUS: SOME TASKS HAD ISSUES — fix FAIL items above${NC}"
fi

echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  NEXT STEPS${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo "  1. View full health report:"
echo "     cat $LOG_DIR/health_report.json"
echo ""
echo "  2. API documentation:"
echo "     http://localhost:8000/docs"
echo ""
echo "  3. Service management:"
echo "     bash manage.sh status    — check service"
echo "     bash manage.sh start     — start after reboot"
echo "     bash manage.sh health    — quick health check"
echo ""
echo "  4. MLflow runs viewer (optional):"
echo "     source venv/bin/activate && mlflow ui --port 5050"
echo "     http://localhost:5050"
echo ""
echo "  5. Connect Flutter app:"
echo "     API base URL: http://localhost:8000"
echo "     WebSocket:    ws://localhost:8000/ws"
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
