#!/bin/bash
# =============================================================================
# FIX 6 — Starting MLflow UI
# =============================================================================
set -uo pipefail

echo "============================================"
echo "FIX 6 — Starting MLflow UI"
echo "============================================"

PROJECT_ROOT="/home/anandhu/projects/amblyopia_backend"
cd "$PROJECT_ROOT"

if [ ! -d "venv" ]; then
    echo "ERROR: Virtual environment not found"
    exit 1
fi

source venv/bin/activate

mkdir -p mlruns
mkdir -p logs

# Kill any existing mlflow (carefully)
echo "Stopping existing MLflow processes..."
# Find PIDs of other mlflow processes, excluding THIS script's PID
OTHER_PIDS=$(pgrep -f "mlflow" | grep -v "^$$\$" || true)
if [ ! -z "$OTHER_PIDS" ]; then
    echo "Killing PIDs: $OTHER_PIDS"
    kill -9 $OTHER_PIDS 2>/dev/null || true
fi
sleep 3

# Start MLflow on port 5055
echo "Starting MLflow server on port 5055..."
nohup mlflow ui \
    --backend-store-uri sqlite:///mlflow.db \
    --default-artifact-root ./mlruns \
    --host 0.0.0.0 \
    --port 5055 \
    > logs/mlflow.log 2>&1 &

MLFLOW_PID=$!
echo "MLflow PID: $MLFLOW_PID"
echo $MLFLOW_PID > logs/mlflow.pid

echo "Waiting for MLflow to start..."
sleep 8

# Verify running
if curl -s http://localhost:5055 > /dev/null; then
    echo "MLflow: RUNNING at http://localhost:5055"
    # Update health check to expect 5050 if needed
else
    echo "MLflow: NOT responding yet"
    echo "Check logs: tail -n 20 logs/mlflow.log"
fi

echo ""
echo "To stop MLflow later:"
echo "  kill \$(cat logs/mlflow.pid)"
echo "============================================"
