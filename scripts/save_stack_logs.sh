#!/usr/bin/env bash
# Dump docker compose service logs to logs/docker/ (stdout history).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs/docker
TS="$(date -u +%Y%m%d-%H%M%SZ)"
OUT="logs/docker/compose-all-${TS}.log"
docker compose logs --no-color --timestamps >"$OUT"
echo "Wrote $OUT"
for svc in mongo backend frontend; do
  docker compose logs --no-color --timestamps "$svc" >"logs/docker/${svc}-${TS}.log" 2>/dev/null || true
  echo "Wrote logs/docker/${svc}-${TS}.log (if service exists)"
done
