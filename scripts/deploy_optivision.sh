#!/usr/bin/env bash
# Deploy AmbyoAI to https://optivision.me (Azure VM at 20.41.123.91).
# Usage from repo root:
#   bash scripts/deploy_optivision.sh
#
# Requires: optivision-server_key.pem in repo root (chmod 600), Docker on server.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KEY="${OPTIVISION_SSH_KEY:-$ROOT/optivision-server_key.pem}"
HOST="${OPTIVISION_HOST:-azureuser@20.41.123.91}"
REMOTE_DIR="${OPTIVISION_REMOTE_DIR:-/opt/ambyoai}"

if [[ ! -f "$KEY" ]]; then
  echo "Missing SSH key: $KEY"
  exit 1
fi
chmod 600 "$KEY"

RSYNC_EXCLUDES=(
  --exclude '.git'
  --exclude 'node_modules'
  --exclude 'frontend/build'
  --exclude 'backend/.env'
  --exclude '.env'
  --exclude 'ssl'
  --exclude 'docker-compose.production.yml'
  --exclude 'logs'
  --exclude 'certbot'
  --exclude 'backend/models'
  --exclude 'ambyo_dataset_clean'
  --exclude 'ambyo_dataset_model'
  --exclude 'extracted_xlsx'
  --exclude 'et_doctor_review_pack'
  --exclude '*.pem'
  --exclude 'optivision-server_key.pem'
  --exclude '.venv'
  --exclude '__pycache__'
  --exclude 'eye.ipynb'
)

echo "=== Syncing code to $HOST:$REMOTE_DIR ==="
rsync -avz --delete "${RSYNC_EXCLUDES[@]}" -e "ssh -i $KEY -o StrictHostKeyChecking=accept-new" \
  "$ROOT/" "$HOST:$REMOTE_DIR/"

echo "=== Rebuilding and restarting Docker stack ==="
ssh -i "$KEY" -o BatchMode=yes "$HOST" bash -s <<EOF
set -euo pipefail
cd "$REMOTE_DIR"
if [[ ! -f backend/.env ]]; then
  echo "ERROR: backend/.env missing on server — copy from backend/.env.production.example and configure secrets."
  exit 1
fi
COMPOSE_OPTS="-f docker-compose.yml -f docker-compose.optivision.production.yml"
docker compose \$COMPOSE_OPTS up -d --build
sleep 4
docker compose \$COMPOSE_OPTS ps
curl -fsS -m 20 https://optivision.me/api/health || curl -fsS -m 5 http://127.0.0.1:8001/api/health
echo ""
echo "Deploy finished. Open https://optivision.me/"
EOF
