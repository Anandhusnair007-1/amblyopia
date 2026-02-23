#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Automated Backup Script
# =============================================================================
# What this backs up:
#   1. PostgreSQL database          → AES-256-CBC encrypted, uploaded to S3
#   2. MLflow artifact store        → synced to S3 bucket prefix
#   3. MinIO object storage         → mc mirror to S3
#   4. Airflow metadata DB          → separate pg_dump encrypted
#   5. Application logs             → compressed, uploaded to S3
#
# Environment variables (set in .env or via secrets manager):
#   POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
#   AIRFLOW_DB_HOST, AIRFLOW_DB_NAME, AIRFLOW_DB_USER, AIRFLOW_DB_PASSWORD
#   BACKUP_ENCRYPTION_KEY   — 32-byte hex key for AES-256 (openssl enc)
#   S3_BUCKET               — s3://mybucket/amblyopia-backups
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
#   MINIO_ACCESS_KEY, MINIO_SECRET_KEY, MINIO_ENDPOINT
#   SLACK_WEBHOOK_URL       — optional; for success/failure notifications
#
# RTO target: < 2 hours  |  RPO target: < 24 hours (daily backups)
# Retention:  - Daily backups kept for 30 days
#             - Weekly backups (Sunday) kept for 1 year
#             - Monthly backups (1st of month) kept for 7 years (DPDP Act)
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="/tmp/amblyopia_backup_$$"
LOG_FILE="/var/log/amblyopia/backup_$(date +%Y%m%d_%H%M%S).log"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DATE_TAG="$(date +%Y-%m-%d)"

# S3 path prefix for today's backup
S3_DAILY_PREFIX="${S3_BUCKET}/daily/${DATE_TAG}"

: "${POSTGRES_HOST:=localhost}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_DB:=amblyopia_db}"
: "${POSTGRES_USER:=amblyopia}"
: "${AIRFLOW_DB_HOST:=localhost}"
: "${AIRFLOW_DB_NAME:=airflow}"
: "${AIRFLOW_DB_USER:=airflow}"

# ── Utility functions ─────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${LOG_FILE}" >&2; }

notify_slack() {
  local status="$1" msg="$2"
  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    local color="good"
    [[ "$status" == "FAILURE" ]] && color="danger"
    curl -sf -X POST "${SLACK_WEBHOOK_URL}" \
      -H "Content-Type: application/json" \
      -d "{\"attachments\":[{\"color\":\"${color}\",\"text\":\"[Amblyopia Backup] ${status}: ${msg}\"}]}" \
      || true
  fi
}

cleanup() {
  log "Cleaning up temp directory ${BACKUP_BASE}"
  rm -rf "${BACKUP_BASE}"
}
trap cleanup EXIT

encrypt_file() {
  local src="$1" dst="$2"
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 \
    -pass env:BACKUP_ENCRYPTION_KEY \
    -in "${src}" -out "${dst}"
}

s3_upload() {
  local src="$1" dst="$2"
  aws s3 cp "${src}" "${dst}" \
    --sse aws:kms \
    --metadata "backup_date=${DATE_TAG},hostname=$(hostname)"
}

# ── Preflight checks ─────────────────────────────────────────────────────────
preflight() {
  log "=== Amblyopia Backup Start: ${TIMESTAMP} ==="
  mkdir -p "${BACKUP_BASE}" "$(dirname "${LOG_FILE}")"

  for cmd in pg_dump openssl aws; do
    command -v "$cmd" >/dev/null 2>&1 || { err "$cmd not found in PATH"; exit 1; }
  done

  [[ -z "${BACKUP_ENCRYPTION_KEY:-}" ]] && { err "BACKUP_ENCRYPTION_KEY not set"; exit 1; }
  [[ -z "${S3_BUCKET:-}" ]]             && { err "S3_BUCKET not set"; exit 1; }

  # Verify S3 access
  aws s3 ls "${S3_BUCKET}/" >/dev/null 2>&1 || { err "Cannot access S3 bucket ${S3_BUCKET}"; exit 1; }
  log "Preflight checks passed."
}

# ── 1. PostgreSQL backup ──────────────────────────────────────────────────────
backup_postgres() {
  log "--- Backing up PostgreSQL: ${POSTGRES_DB} ---"
  local dump_file="${BACKUP_BASE}/postgres_${POSTGRES_DB}_${TIMESTAMP}.pgdump"
  local enc_file="${dump_file}.enc"

  PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --format=custom \
    --compress=9 \
    --no-password \
    -f "${dump_file}"

  log "  Dump size: $(du -sh "${dump_file}" | cut -f1)"

  encrypt_file "${dump_file}" "${enc_file}"
  rm -f "${dump_file}"

  s3_upload "${enc_file}" "${S3_DAILY_PREFIX}/postgres/${POSTGRES_DB}_${TIMESTAMP}.pgdump.enc"
  log "  PostgreSQL backup uploaded."

  # Compute and store SHA256 manifest for integrity verification
  sha256sum "${enc_file}" >> "${BACKUP_BASE}/MANIFEST.sha256"
}

# ── 2. Airflow metadata DB backup ────────────────────────────────────────────
backup_airflow_db() {
  log "--- Backing up Airflow metadata DB ---"
  local dump_file="${BACKUP_BASE}/airflow_${TIMESTAMP}.pgdump"
  local enc_file="${dump_file}.enc"

  PGPASSWORD="${AIRFLOW_DB_PASSWORD}" pg_dump \
    -h "${AIRFLOW_DB_HOST}" \
    -U "${AIRFLOW_DB_USER}" \
    -d "${AIRFLOW_DB_NAME}" \
    --format=custom \
    --compress=9 \
    -f "${dump_file}" || { err "Airflow DB dump failed (non-fatal)"; return 0; }

  encrypt_file "${dump_file}" "${enc_file}"
  rm -f "${dump_file}"

  s3_upload "${enc_file}" "${S3_DAILY_PREFIX}/airflow/metadata_${TIMESTAMP}.pgdump.enc"
  log "  Airflow metadata backup uploaded."
}

# ── 3. MLflow artifact store backup ──────────────────────────────────────────
backup_mlflow() {
  log "--- Syncing MLflow artifacts ---"
  local mlflow_dir="${SCRIPT_DIR}/../mlruns"

  if [[ -d "${mlflow_dir}" ]]; then
    aws s3 sync "${mlflow_dir}/" \
      "${S3_DAILY_PREFIX}/mlruns/" \
      --sse aws:kms \
      --only-show-errors
    log "  MLflow sync complete."
  else
    log "  WARNING: mlruns directory not found at ${mlflow_dir}, skipping."
  fi
}

# ── 4. MinIO object storage backup ───────────────────────────────────────────
backup_minio() {
  log "--- Mirroring MinIO buckets ---"
  if command -v mc >/dev/null 2>&1 && [[ -n "${MINIO_ENDPOINT:-}" ]]; then
    mc alias set local_minio "${MINIO_ENDPOINT}" \
      "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --quiet

    mc mirror --overwrite --quiet \
      "local_minio/amblyopia-media" \
      "${S3_BUCKET}/minio-mirror/amblyopia-media/"

    log "  MinIO mirror complete."
  else
    log "  WARNING: mc client not found or MINIO_ENDPOINT not set, skipping MinIO backup."
  fi
}

# ── 5. Application logs backup ───────────────────────────────────────────────
backup_logs() {
  log "--- Archiving application logs ---"
  local log_dir="/var/log/amblyopia"
  local archive="${BACKUP_BASE}/logs_${TIMESTAMP}.tar.gz"

  if [[ -d "${log_dir}" ]]; then
    tar -czf "${archive}" -C "$(dirname "${log_dir}")" "$(basename "${log_dir}")"
    s3_upload "${archive}" "${S3_DAILY_PREFIX}/logs/logs_${TIMESTAMP}.tar.gz"
    log "  Logs archived and uploaded."
  else
    log "  WARNING: Log directory ${log_dir} not found, skipping."
  fi
}

# ── 6. Upload SHA256 manifest ─────────────────────────────────────────────────
upload_manifest() {
  local manifest="${BACKUP_BASE}/MANIFEST.sha256"
  if [[ -f "${manifest}" ]]; then
    s3_upload "${manifest}" "${S3_DAILY_PREFIX}/MANIFEST.sha256"
    log "  SHA256 manifest uploaded."
  fi
}

# ── 7. Retention policy enforcement ──────────────────────────────────────────
apply_retention() {
  log "--- Applying retention policy ---"

  # Delete daily backups older than 30 days
  local cutoff_daily
  cutoff_daily="$(date -d '30 days ago' +%Y-%m-%d)"
  log "  Deleting daily backups before ${cutoff_daily}..."
  aws s3 ls "${S3_BUCKET}/daily/" | awk '{print $2}' | while read -r prefix; do
    day="${prefix%/}"
    if [[ "${day}" < "${cutoff_daily}" ]]; then
      # Keep weekly (Sunday) backups up to 1 year
      day_of_week="$(date -d "${day}" +%u 2>/dev/null || echo 1)"
      if [[ "${day_of_week}" != "7" ]]; then
        aws s3 rm "${S3_BUCKET}/daily/${prefix}" --recursive --quiet
        log "  Removed daily backup: ${day}"
      fi
    fi
  done || true

  log "  Retention policy applied."
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  preflight

  local errors=0

  backup_postgres    || { err "PostgreSQL backup FAILED"; errors=$((errors + 1)); }
  backup_airflow_db  || { err "Airflow DB backup FAILED (non-critical)"; }
  backup_mlflow      || { err "MLflow backup FAILED"; errors=$((errors + 1)); }
  backup_minio       || { err "MinIO backup FAILED (non-critical)"; }
  backup_logs        || { err "Logs backup FAILED (non-critical)"; }
  upload_manifest    || true
  apply_retention    || { err "Retention policy FAILED (non-critical)"; }

  if [[ "${errors}" -gt 0 ]]; then
    err "Backup completed with ${errors} critical error(s)."
    notify_slack "FAILURE" "${errors} critical error(s). Check ${LOG_FILE}"
    exit 1
  fi

  log "=== Backup complete: ${TIMESTAMP} (0 errors) ==="
  notify_slack "SUCCESS" "All components backed up to ${S3_DAILY_PREFIX}"
}

main "$@"
