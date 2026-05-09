#!/usr/bin/env bash
# Restore from mongodump gzip archive. Requires explicit confirmation unless --yes is passed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

YES=false
DROP=false
ARCHIVE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) YES=true; shift ;;
    --drop) DROP=true; shift ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      ARCHIVE="$1"
      shift
      ;;
  esac
done

if [[ -z "$ARCHIVE" ]]; then
  echo "Usage: $0 [--yes] [--drop] <path-to.archive.gz>" >&2
  echo "  Restores from mongodump archive. Add --drop to drop collections first (destructive)." >&2
  exit 2
fi

if [[ ! -f "$ARCHIVE" ]]; then
  echo "File not found: $ARCHIVE" >&2
  exit 1
fi

if [[ -f "$ROOT/backend/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
  set +a
fi

: "${MONGO_URL:?MONGO_URL must be set (export it or define it in backend/.env)}"

if [[ "$YES" != true ]]; then
  echo "WARNING: This will restore into MongoDB at:"
  echo "  URI (host redacted): ${MONGO_URL%%\?*}"
  echo "  Archive: $ARCHIVE"
  read -r -p "Type RESTORE to continue: " ans
  if [[ "$ans" != "RESTORE" ]]; then
    echo "Aborted." >&2
    exit 1
  fi
fi

ARGS=(--uri="$MONGO_URL" --gzip --archive="$ARCHIVE")
if [[ "$DROP" == true ]]; then
  ARGS+=(--drop)
fi
mongorestore "${ARGS[@]}"

echo "Restore completed from $ARCHIVE"
