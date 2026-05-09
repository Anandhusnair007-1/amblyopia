#!/usr/bin/env bash
# Assess Docker + nginx + TLS layout for public web deploy (ambyoai.com style).
# Run from repo root: bash scripts/assess_web_deploy.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "scripts/assess_web_deploy.sh (rev: 2026-05-03+screen-quality-step6)"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/.env"
  set +a
fi

HTTP_PORT="${FRONTEND_HTTP_PORT:-8080}"

echo "=== 1. Compose file syntax ==="
docker compose -f docker-compose.yml config >/dev/null
echo "    OK: docker-compose.yml"
docker compose -f docker-compose.yml -f docker-compose.production.yml config >/dev/null
echo "    OK: merged with docker-compose.production.yml"

echo "=== 2. TLS PEMs (required for production nginx mount) ==="
if [[ -f ssl/ambyoai.com/fullchain.pem && -f ssl/ambyoai.com/privkey.pem ]]; then
  echo "    OK: ssl/ambyoai.com/fullchain.pem and privkey.pem"
  if docker info >/dev/null 2>&1; then
    echo "    Running: nginx -t in container (config + certs)..."
    docker run --rm \
      -v "$ROOT/nginx/ambyoai.com.conf:/etc/nginx/conf.d/default.conf:ro" \
      -v "$ROOT/ssl/ambyoai.com/fullchain.pem:/etc/nginx/ssl/fullchain.pem:ro" \
      -v "$ROOT/ssl/ambyoai.com/privkey.pem:/etc/nginx/ssl/privkey.pem:ro" \
      nginx:1.27-alpine nginx -t
    echo "    OK: nginx config test passed"
  else
    echo "    SKIP: Docker daemon not available for nginx -t"
  fi
else
  echo "    MISSING: place Let's Encrypt (or test) PEMs under ssl/ambyoai.com/"
fi

echo "=== 3. ACME webroot (optional) ==="
mkdir -p certbot/www
echo "    OK: certbot/www exists (mount for /.well-known/acme-challenge/)"

echo "=== 4. Backend CORS reminder ==="
if [[ -f backend/.env ]]; then
  if grep -q '^CORS_ORIGINS=.*https://' backend/.env 2>/dev/null; then
    echo "    OK: backend/.env sets CORS_ORIGINS with https://"
  else
    echo "    WARN: set CORS_ORIGINS in backend/.env to your real UI origins (https://ambyoai.com,...)"
  fi
else
  echo "    WARN: backend/.env missing — copy backend/.env.production.example"
fi

echo "=== 5. API health via nginx (stack must be up) ==="
URL="http://127.0.0.1:${HTTP_PORT}/api/health"
BODY="$(curl -fsS -m 3 "$URL" 2>/dev/null || true)"
if [[ "$BODY" == *'"status"'* && "$BODY" == *'"ok"'* ]]; then
  echo "    OK: curl $URL (JSON from API — nginx /api proxy is active)"
elif [[ -n "$BODY" ]]; then
  echo "    FAIL: $URL returned a body but not API JSON (rebuild frontend: docker compose build frontend && docker compose up -d frontend)"
  exit 1
else
  echo "    SKIP: $URL not reachable (run: docker compose up -d)"
fi

echo "=== 6. Screen-quality stack (POST /api/ai/screen-quality via nginx) ==="
if [[ ! -f scripts/verify_screen_quality_stack.sh ]]; then
  echo "    SKIP: scripts/verify_screen_quality_stack.sh not found"
elif ! docker compose exec -T backend true 2>/dev/null; then
  echo "    SKIP: backend container not running"
else
  bash scripts/verify_screen_quality_stack.sh
  echo "    OK: verify_screen_quality_stack.sh (see OK lines above)"
fi

echo "=== Done ==="
