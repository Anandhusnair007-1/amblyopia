#!/usr/bin/env bash
# Timestamped gzip archive via mongodump. Reads MONGO_URL and DB_NAME from the environment
# or from backend/.env next to the repo root (parent of scripts/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$ROOT/backend/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
  set +a
fi

: "${MONGO_URL:?MONGO_URL must be set (export it or define it in backend/.env)}"
DB_NAME="${DB_NAME:-ambyoai}"

STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUTDIR="$ROOT/backups"
mkdir -p "$OUTDIR"

SAFE_DB="$(echo "$DB_NAME" | tr '/ ' '__')"
ARCHIVE="$OUTDIR/ambyoai_${SAFE_DB}_${STAMP}.archive.gz"

mongodump --uri="$MONGO_URL" --db="$DB_NAME" --archive="$ARCHIVE" --gzip

echo "Backup written: $ARCHIVE"
