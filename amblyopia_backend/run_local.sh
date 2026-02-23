#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Local Run Script (NO DOCKER)
# Aravind Eye Hospital, Coimbatore, India
#
# What this does:
#   1. Creates & activates Python venv
#   2. Installs all pip packages
#   3. Sets up local PostgreSQL (if installed)
#   4. Runs Alembic DB migrations
#   5. Starts MLflow UI (local file store)
#   6. Starts FastAPI with uvicorn
#
# Requirements (install these once):
#   sudo apt install postgresql postgresql-contrib redis-server python3.11-venv
# =============================================================================
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${BLUE} $*${NC}"; \
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}"; }

# ── PID file storage for cleanup ─────────────────────────────────────────────
PIDS=()
cleanup() {
    echo ""
    warn "Shutting down all services..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null && info "Killed PID $pid"
    done
    success "Shutdown complete."
}
trap cleanup EXIT INT TERM

# ═══════════════════════════════════════════════════════════════════
# STEP 1 — Python venv
# ═══════════════════════════════════════════════════════════════════
header "STEP 1 — Python Virtual Environment"

if [ ! -d "venv" ]; then
    info "Creating venv..."
    python3 -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate
success "venv activated: $(which python3)"

# ═══════════════════════════════════════════════════════════════════
# STEP 2 — Install Python packages
# ═══════════════════════════════════════════════════════════════════
header "STEP 2 — Installing Python Dependencies"

pip install --upgrade pip setuptools wheel -q

info "Installing core requirements..."
# Remove Docker-only packages for local install
pip install \
    "fastapi==0.115.8" \
    "starlette==0.45.3" \
    "uvicorn[standard]==0.34.0" \
    "sqlalchemy==2.0.23" \
    "alembic==1.12.1" \
    "psycopg2-binary==2.9.9" \
    "asyncpg==0.29.0" \
    "redis==5.0.1" \
    "python-jose[cryptography]==3.3.0" \
    "passlib[bcrypt]==1.7.4" \
    "python-multipart==0.0.6" \
    "pydantic==2.5.0" \
    "pydantic-settings==2.1.0" \
    "python-dotenv==1.0.0" \
    "httpx==0.25.2" \
    "aiofiles==23.2.1" \
    "greenlet==3.0.3" \
    "pytz==2023.3.post1" \
    -q

info "Installing ML/vision packages..."
pip install \
    "numpy>=1.24.0" \
    "opencv-python>=4.8.0" \
    "Pillow>=10.0.0" \
    "scipy>=1.11.0" \
    "scikit-learn>=1.3.0" \
    "librosa>=0.10.0" \
    "soundfile>=0.12.1" \
    -q

info "Installing ML tracking (local file store, no server needed)..."
pip install "mlflow>=2.8.0" -q

info "Installing reporting packages..."
pip install \
    "reportlab>=4.0.0" \
    "qrcode>=7.4.0" \
    "cryptography>=41.0.0" \
    "prometheus-fastapi-instrumentator>=6.1.0" \
    "sentry-sdk>=1.38.0" \
    -q

info "Installing test runner..."
pip install "pytest>=7.4.0" "pytest-asyncio>=0.21.0" -q

# Optional: webrtcvad (may fail on some systems — graceful skip)
pip install "webrtcvad==2.0.10" -q 2>/dev/null || warn "webrtcvad not installed (optional — VAD will be skipped)"

success "All packages installed"

# ═══════════════════════════════════════════════════════════════════
# STEP 3 — Load .env
# ═══════════════════════════════════════════════════════════════════
header "STEP 3 — Environment Configuration"

if [ -f ".env" ]; then
    # Use set -a to auto-export only valid KEY=VALUE lines
    set -a
    # shellcheck disable=SC1091
    source <(grep -E '^[A-Z_][A-Z0-9_]*=' .env | grep -v '^#')
    set +a
    success ".env loaded"
else
    warn ".env not found — using defaults from app/config.py"
fi

info "Environment: ${ENVIRONMENT:-development}"
info "Debug:       ${DEBUG:-true}"
info "DB URL:      ${DATABASE_URL:-not set}"
info "MLflow:      ${MLFLOW_TRACKING_URI:-file:./mlruns}"

# ═══════════════════════════════════════════════════════════════════
# STEP 4 — PostgreSQL setup (local)
# ═══════════════════════════════════════════════════════════════════
header "STEP 4 — Local PostgreSQL"

if command -v psql &>/dev/null; then
    info "PostgreSQL found — ensuring DB and user exist..."

    # Start PostgreSQL if not running
    if ! pg_isready -q 2>/dev/null; then
        sudo service postgresql start 2>/dev/null || sudo systemctl start postgresql 2>/dev/null || true
        sleep 2
    fi

    if pg_isready -q 2>/dev/null; then
        # Create user + database silently
        sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='amblyopia_user'" 2>/dev/null | grep -q 1 || \
            sudo -u postgres psql -c "CREATE USER amblyopia_user WITH PASSWORD 'amblyopia_pass';" 2>/dev/null || true

        sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='amblyopia_db'" 2>/dev/null | grep -q 1 || \
            sudo -u postgres psql -c "CREATE DATABASE amblyopia_db OWNER amblyopia_user;" 2>/dev/null || true

        success "PostgreSQL ready at localhost:5432"
    else
        warn "PostgreSQL not running — install with: sudo apt install postgresql"
        warn "App will start but DB-dependent endpoints will fail."
    fi
else
    warn "PostgreSQL not found — install with: sudo apt install postgresql postgresql-contrib"
    warn "App will start but DB-dependent endpoints will return 500."
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 5 — Redis (local)
# ═══════════════════════════════════════════════════════════════════
header "STEP 5 — Local Redis"

if command -v redis-cli &>/dev/null; then
    if ! redis-cli ping &>/dev/null; then
        sudo service redis-server start 2>/dev/null || sudo systemctl start redis 2>/dev/null || \
        redis-server --daemonize yes --loglevel warning 2>/dev/null || true
        sleep 1
    fi
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        success "Redis ready at localhost:6379"
    else
        warn "Redis not responding — install with: sudo apt install redis-server"
    fi
else
    warn "Redis not found — install with: sudo apt install redis-server"
    warn "Session-dependent features will be unavailable."
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 6 — Alembic DB Migrations
# ═══════════════════════════════════════════════════════════════════
header "STEP 6 — Database Migrations"

if pg_isready -q 2>/dev/null; then
    info "Running Alembic migrations..."
    # PYTHONPATH must include project root so 'app' module is found
    if PYTHONPATH="$PROJECT_ROOT" alembic upgrade head 2>&1; then
        success "Database schema up to date"
    else
        warn "Migration had issues — you may need to run:"
        warn "  PYTHONPATH=. alembic upgrade head"
    fi
else
    warn "Skipping migrations — PostgreSQL not available"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 7 — MLflow (local file store — NO server needed)
# ═══════════════════════════════════════════════════════════════════
header "STEP 7 — MLflow (Local File Store)"

mkdir -p mlruns
info "MLflow tracking: file:./mlruns"
info "To view runs in browser, run in another terminal:"
info "  source venv/bin/activate && mlflow ui --port 5050"
info "  Then open: http://localhost:5050"
success "MLflow local store ready (no server needed)"

# ═══════════════════════════════════════════════════════════════════
# STEP 8 — Check model weights
# ═══════════════════════════════════════════════════════════════════
header "STEP 8 — Model Weights Check"

check_model() {
    local path="$1" name="$2"
    if [ -f "$path" ] && [ -s "$path" ]; then
        local sz; sz=$(du -sh "$path" | cut -f1)
        success "$name ($sz)"
    else
        warn "$name — NOT FOUND at $path"
        warn "  Run: bash setup/download_models.sh"
    fi
}

check_model "models/real_esrgan/RealESRGAN_x4plus.pth" "Real-ESRGAN"
check_model "models/zero_dce/zero_dce_weights.pth"     "Zero-DCE"
check_model "models/deblurgan/fpn_inception.h5"         "DeblurGAN"
check_model "models/yolo/yolov8n.pt"                    "YOLOv8-nano"
info "Note: Models load lazily on first request — missing models use classical fallback"

# ═══════════════════════════════════════════════════════════════════
# STEP 9 — Start FastAPI
# ═══════════════════════════════════════════════════════════════════
header "STEP 9 — Starting FastAPI Server"

API_HOST="${API_HOST:-0.0.0.0}"
API_PORT="${API_PORT:-8000}"

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   AMBLYOPIA CARE SYSTEM — LOCAL MODE     ║${NC}"
echo -e "${GREEN}${BOLD}║   Aravind Eye Hospital, Coimbatore        ║${NC}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║  API:     http://localhost:${API_PORT}          ║${NC}"
echo -e "${GREEN}${BOLD}║  Docs:    http://localhost:${API_PORT}/docs      ║${NC}"
echo -e "${GREEN}${BOLD}║  Health:  http://localhost:${API_PORT}/health    ║${NC}"
echo -e "${GREEN}${BOLD}║  MLflow:  file:./mlruns (no UI server)   ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
info "Press Ctrl+C to stop"
echo ""

uvicorn app.main:app \
    --host "$API_HOST" \
    --port "$API_PORT" \
    --reload \
    --log-level info \
    --workers 1
