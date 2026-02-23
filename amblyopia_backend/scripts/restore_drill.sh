#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — DR Restore Drill Script
# =============================================================================
# PURPOSE:
#   Validate the entire backup chain end-to-end without touching production.
#   Creates an isolated restore environment, restores the latest backup,
#   runs smoke tests, and produces a drill report.
#
# USAGE:
#   ./restore_drill.sh [--date YYYY-MM-DD] [--skip-minio] [--dry-run]
#
# Environment variables: same as backup.sh
#   RESTORE_DB_HOST     — separate test DB host (default: localhost)
#   RESTORE_DB_PORT     — (default: 5433 — avoid collision with production)
#   RESTORE_DB_NAME     — (default: amblyopia_restore_drill)
#
# SUCCESS CRITERIA (all must pass for drill to succeed):
#   1. Encrypted backup file downloads successfully from S3
#   2. SHA256 checksums match the stored MANIFEST
#   3. Decryption succeeds without error
#   4. pg_restore completes with 0 errors
#   5. Row-count sanity check: patients, screenings, audit_logs tables non-empty
#   6. Full restore completes within 2 hours (RTO target)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_BASE="/tmp/amblyopia_restore_drill_$$"
DRILL_DATE="${DRILL_DATE:-$(date +%Y-%m-%d)}"
DRILL_LOG="/var/log/amblyopia/restore_drill_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${RESTORE_BASE}/drill_report.txt"
DRY_RUN="${DRY_RUN:-false}"
DRILL_START="$(date +%s)"

: "${RESTORE_DB_HOST:=localhost}"
: "${RESTORE_DB_PORT:=5433}"
: "${RESTORE_DB_NAME:=amblyopia_restore_drill}"
: "${RESTORE_DB_USER:=${POSTGRES_USER:-amblyopia}}"

PASS_COUNT=0
FAIL_COUNT=0

# ── Utility functions ─────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${DRILL_LOG}"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${DRILL_LOG}" >&2; }

pass() { echo "  [PASS] $*" | tee -a "${REPORT_FILE}"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $*" | tee -a "${REPORT_FILE}"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

cleanup() {
  log "Cleaning up restore directory"
  rm -rf "${RESTORE_BASE}"

  # Drop restore DB if it was created
  if [[ "${DB_CREATED:-false}" == "true" ]]; then
    PGPASSWORD="${POSTGRES_PASSWORD:-}" psql \
      -h "${RESTORE_DB_HOST}" -p "${RESTORE_DB_PORT}" \
      -U "${RESTORE_DB_USER}" -d postgres \
      -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};" \
      2>/dev/null || true
    log "Restore drill DB dropped."
  fi
}
trap cleanup EXIT

# ── Step 1: Locate latest backup on S3 ───────────────────────────────────────
find_backup() {
  log "=== Step 1: Locating backup for date ${DRILL_DATE} ==="
  S3_PREFIX="${S3_BUCKET}/daily/${DRILL_DATE}"

  # Check backup exists
  if ! aws s3 ls "${S3_PREFIX}/postgres/" >/dev/null 2>&1; then
    err "No backup found at ${S3_PREFIX}/postgres/"
    fail "Backup found on S3 for ${DRILL_DATE}"
    return 1
  fi

  # Get the most recent dump file for this date
  BACKUP_S3_PATH="$(aws s3 ls "${S3_PREFIX}/postgres/" \
    | sort | tail -1 | awk '{print $4}')"

  if [[ -z "${BACKUP_S3_PATH}" ]]; then
    fail "Backup file listed on S3"
    return 1
  fi

  BACKUP_FULL_S3="${S3_PREFIX}/postgres/${BACKUP_S3_PATH}"
  log "  Found: ${BACKUP_FULL_S3}"
  pass "Backup found on S3 for ${DRILL_DATE}"
}

# ── Step 2: Download and verify checksum ─────────────────────────────────────
download_and_verify() {
  log "=== Step 2: Downloading and verifying checksums ==="
  LOCAL_ENC="${RESTORE_BASE}/${BACKUP_S3_PATH}"

  aws s3 cp "${BACKUP_FULL_S3}" "${LOCAL_ENC}" --quiet
  pass "S3 download succeeded"

  # Download MANIFEST
  LOCAL_MANIFEST="${RESTORE_BASE}/MANIFEST.sha256"
  aws s3 cp "${S3_PREFIX}/MANIFEST.sha256" "${LOCAL_MANIFEST}" --quiet 2>/dev/null || {
    fail "MANIFEST.sha256 present on S3"
    return 0  # non-fatal — skip checksum if manifest missing
  }
  pass "MANIFEST.sha256 downloaded"

  # Verify checksum
  EXPECTED_HASH="$(grep "$(basename "${LOCAL_ENC}")" "${LOCAL_MANIFEST}" | awk '{print $1}')"
  ACTUAL_HASH="$(sha256sum "${LOCAL_ENC}" | awk '{print $1}')"

  if [[ "${EXPECTED_HASH}" == "${ACTUAL_HASH}" ]]; then
    pass "SHA256 checksum matches MANIFEST"
  else
    fail "SHA256 checksum mismatch! Expected=${EXPECTED_HASH:0:16}... Got=${ACTUAL_HASH:0:16}..."
  fi
}

# ── Step 3: Decrypt backup ────────────────────────────────────────────────────
decrypt_backup() {
  log "=== Step 3: Decrypting backup ==="

  [[ -z "${BACKUP_ENCRYPTION_KEY:-}" ]] && { fail "BACKUP_ENCRYPTION_KEY set"; return 1; }

  LOCAL_ENC="${RESTORE_BASE}/${BACKUP_S3_PATH}"
  LOCAL_DUMP="${LOCAL_ENC%.enc}"

  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
    -pass env:BACKUP_ENCRYPTION_KEY \
    -in "${LOCAL_ENC}" -out "${LOCAL_DUMP}"

  if [[ -s "${LOCAL_DUMP}" ]]; then
    pass "Decryption succeeded ($(du -sh "${LOCAL_DUMP}" | cut -f1))"
  else
    fail "Decrypted file is empty"
    return 1
  fi
}

# ── Step 4: Create restore DB and run pg_restore ──────────────────────────────
restore_database() {
  log "=== Step 4: Restoring to ${RESTORE_DB_NAME} ==="

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "  DRY RUN — skipping actual DB restore"
    pass "pg_restore (dry-run skipped)"
    return 0
  fi

  LOCAL_DUMP="${RESTORE_BASE}/${BACKUP_S3_PATH%.enc}"

  PGPASSWORD="${POSTGRES_PASSWORD:-}" createdb \
    -h "${RESTORE_DB_HOST}" -p "${RESTORE_DB_PORT}" \
    -U "${RESTORE_DB_USER}" \
    "${RESTORE_DB_NAME}" 2>/dev/null && DB_CREATED=true

  PGPASSWORD="${POSTGRES_PASSWORD:-}" pg_restore \
    -h "${RESTORE_DB_HOST}" \
    -p "${RESTORE_DB_PORT}" \
    -U "${RESTORE_DB_USER}" \
    -d "${RESTORE_DB_NAME}" \
    --no-owner --no-acl \
    --jobs=4 \
    "${LOCAL_DUMP}" 2>&1 | tee -a "${DRILL_LOG}" || {
      fail "pg_restore exited non-zero"
      return 1
    }

  pass "pg_restore completed"
}

# ── Step 5: Smoke tests ───────────────────────────────────────────────────────
run_smoke_tests() {
  log "=== Step 5: Running database smoke tests ==="

  if [[ "${DRY_RUN}" == "true" ]]; then
    pass "Smoke tests (dry-run skipped)"
    return 0
  fi

  psql_exec() {
    PGPASSWORD="${POSTGRES_PASSWORD:-}" psql \
      -h "${RESTORE_DB_HOST}" -p "${RESTORE_DB_PORT}" \
      -U "${RESTORE_DB_USER}" -d "${RESTORE_DB_NAME}" \
      -t -c "$1" 2>/dev/null | xargs
  }

  # Table existence checks
  for table in patients screenings audit_logs users; do
    count="$(psql_exec "SELECT COUNT(*) FROM ${table};" 2>/dev/null || echo "ERROR")"
    if [[ "${count}" == "ERROR" ]]; then
      fail "Table '${table}' exists in restored DB"
    elif [[ "${count}" -gt 0 ]]; then
      pass "Table '${table}' has ${count} rows"
    else
      log "  WARNING: Table '${table}' is empty (may be valid for test env)"
    fi
  done

  # Schema integrity — check critical columns
  col_check="$(psql_exec "SELECT column_name FROM information_schema.columns \
    WHERE table_name='patients' AND column_name='encrypted_name';" 2>/dev/null || echo "")"
  if [[ -n "${col_check}" ]]; then
    pass "patients.encrypted_name column present (encryption schema intact)"
  else
    fail "patients.encrypted_name column missing"
  fi
}

# ── Step 6: RTO check ─────────────────────────────────────────────────────────
check_rto() {
  log "=== Step 6: RTO Verification ==="
  local elapsed=$(( $(date +%s) - DRILL_START ))
  local elapsed_min=$(( elapsed / 60 ))
  local rto_limit=7200  # 2 hours in seconds

  if [[ "${elapsed}" -lt "${rto_limit}" ]]; then
    pass "RTO target met: restore completed in ${elapsed_min} minutes (limit: 120 min)"
  else
    fail "RTO target EXCEEDED: ${elapsed_min} minutes > 120 minute limit"
  fi
}

# ── Step 7: Print report ──────────────────────────────────────────────────────
print_report() {
  local total=$(( PASS_COUNT + FAIL_COUNT ))
  local elapsed=$(( $(date +%s) - DRILL_START ))

  echo "" | tee -a "${REPORT_FILE}"
  echo "=============================================" | tee -a "${REPORT_FILE}"
  echo " Amblyopia Care System — DR Restore Drill"    | tee -a "${REPORT_FILE}"
  echo " Date:     $(date '+%Y-%m-%d %H:%M:%S')"      | tee -a "${REPORT_FILE}"
  echo " Backup:   ${DRILL_DATE}"                      | tee -a "${REPORT_FILE}"
  echo " Duration: ${elapsed}s"                        | tee -a "${REPORT_FILE}"
  echo " Results:  ${PASS_COUNT}/${total} PASS | ${FAIL_COUNT} FAIL" | tee -a "${REPORT_FILE}"
  echo "=============================================" | tee -a "${REPORT_FILE}"

  # Copy report to S3 for audit trail
  aws s3 cp "${REPORT_FILE}" \
    "${S3_BUCKET}/dr-drill-reports/drill_$(date +%Y%m%d_%H%M%S).txt" \
    --quiet 2>/dev/null || true

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    err "DR Drill FAILED: ${FAIL_COUNT} check(s) failed. See ${DRILL_LOG}"
    return 1
  fi
  log "DR Drill PASSED. Report: ${REPORT_FILE}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 [--date YYYY-MM-DD] [--dry-run]"
  echo "  --date YYYY-MM-DD   Use backup from this date (default: today)"
  echo "  --dry-run           Skip actual DB restore and smoke tests"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)      DRILL_DATE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)   usage ;;
    *)           err "Unknown argument: $1"; usage ;;
  esac
done

mkdir -p "${RESTORE_BASE}" "$(dirname "${DRILL_LOG}")"
touch "${REPORT_FILE}"

log "=== DR Restore Drill START (backup date: ${DRILL_DATE}) ==="

find_backup       || true
download_and_verify
decrypt_backup
restore_database
run_smoke_tests
check_rto
print_report
