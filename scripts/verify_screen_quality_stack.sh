#!/usr/bin/env bash
# Fail fast: nginx must proxy /api (not return SPA HTML), backend must have Pillow for ai_engine.
# Run from repo root: bash scripts/verify_screen_quality_stack.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/.env"
  set +a
fi

HTTP_PORT="${FRONTEND_HTTP_PORT:-8080}"
URL="http://127.0.0.1:${HTTP_PORT}/api/health"
BODY="$(curl -fsS -m 5 "$URL" 2>/dev/null || true)"

if [[ "$BODY" == *'"status"'* && "$BODY" == *'"ok"'* ]]; then
  echo "OK: $URL returns API JSON (nginx /api proxy active on :${HTTP_PORT})"
else
  echo "FAIL: $URL must return JSON like {\"status\":\"ok\"}."
  echo "Got (first 200 chars): ${BODY:0:200}"
  echo "Typical fix: docker compose build frontend && docker compose up -d frontend"
  exit 1
fi

if ! docker compose exec -T backend true 2>/dev/null; then
  echo "FAIL: backend container not reachable — run: docker compose up -d"
  exit 1
fi
docker compose exec -T backend python3 -c "from PIL import Image; import importlib.util; from pathlib import Path; p=Path('/app/ai_engine.py'); s=importlib.util.spec_from_file_location('m',p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print('OK: ai_engine loads in container:', type(m.ai_engine).__name__)"

# End-to-end POST via nginx (catches missing proxy_methods / wrong location for multipart).
SQ_B64="$(docker compose exec -T backend python3 -c "import io,base64; from PIL import Image; b=io.BytesIO(); Image.new('RGB',(64,64),(9,9,9)).save(b,'JPEG'); print(base64.b64encode(b.getvalue()).decode())")"
printf '%s' "$SQ_B64" | base64 -d >"${TMPDIR:-/tmp}/.ambyo_verify_sq.jpg"
TOKEN="$(docker compose exec -T backend python3 -c "import server; print(server.make_token('verify-sq','patient',{'hospital_id':'h'},120))")"
POST_URL="http://127.0.0.1:${HTTP_PORT}/api/ai/screen-quality"
CODE="$(curl -sS -m 25 -o "${TMPDIR:-/tmp}/.ambyo_verify_sq.json" -w "%{http_code}" -X POST "$POST_URL" -H "Authorization: Bearer ${TOKEN}" -F "file=@${TMPDIR:-/tmp}/.ambyo_verify_sq.jpg;type=image/jpeg")"
if [[ "$CODE" != "200" ]]; then
  echo "FAIL: POST $POST_URL returned HTTP $CODE (expected 200). Body (first 240 chars):"
  head -c 240 "${TMPDIR:-/tmp}/.ambyo_verify_sq.json" || true
  echo ""
  exit 1
fi
if ! grep -q '"quality"' "${TMPDIR:-/tmp}/.ambyo_verify_sq.json"; then
  echo "FAIL: POST response missing JSON quality field (first 240 chars):"
  head -c 240 "${TMPDIR:-/tmp}/.ambyo_verify_sq.json" || true
  echo ""
  exit 1
fi
echo "OK: POST $POST_URL returned 200 with quality JSON (same path as AIScreeningGate)"

# Optional: same checks over TLS (docker-compose maps :8443 → nginx :443; self-signed).
HTTPS_PORT="${FRONTEND_HTTPS_PORT:-8443}"
HS_HEALTH="https://127.0.0.1:${HTTPS_PORT}/api/health"
HS_CODE="$(curl -sk -m 5 -o "${TMPDIR:-/tmp}/.ambyo_verify_hs_health" -w "%{http_code}" "$HS_HEALTH" 2>/dev/null || echo "000")"
if [[ "$HS_CODE" == "200" ]]; then
  HS_BODY="$(cat "${TMPDIR:-/tmp}/.ambyo_verify_hs_health" 2>/dev/null || true)"
  if [[ "$HS_BODY" == *'"status"'* && "$HS_BODY" == *'"ok"'* ]]; then
    echo "OK: $HS_HEALTH returns API JSON (TLS on :${HTTPS_PORT})"
    HS_POST="https://127.0.0.1:${HTTPS_PORT}/api/ai/screen-quality"
    HCODE="$(curl -sk -m 25 -o "${TMPDIR:-/tmp}/.ambyo_verify_hs_post.json" -w "%{http_code}" -X POST "$HS_POST" -H "Authorization: Bearer ${TOKEN}" -F "file=@${TMPDIR:-/tmp}/.ambyo_verify_sq.jpg;type=image/jpeg" 2>/dev/null || echo "000")"
    if [[ "$HCODE" != "200" ]]; then
      echo "FAIL: POST $HS_POST returned HTTP $HCODE (expected 200). Body (first 240 chars):"
      head -c 240 "${TMPDIR:-/tmp}/.ambyo_verify_hs_post.json" 2>/dev/null || true
      echo ""
      exit 1
    fi
    if ! grep -q '"quality"' "${TMPDIR:-/tmp}/.ambyo_verify_hs_post.json" 2>/dev/null; then
      echo "FAIL: POST $HS_POST missing quality JSON (first 240 chars):"
      head -c 240 "${TMPDIR:-/tmp}/.ambyo_verify_hs_post.json" 2>/dev/null || true
      echo ""
      exit 1
    fi
    echo "OK: POST $HS_POST returned 200 with quality JSON"
  else
    echo "FAIL: $HS_HEALTH returned 200 but not API JSON (first 200 chars): ${HS_BODY:0:200}"
    exit 1
  fi
else
  echo "SKIP: $HS_HEALTH not reachable (code ${HS_CODE}) — optional unless you use https:// on :${HTTPS_PORT}"
fi

echo "All checks passed."
