#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-/var/backups/limadev/postgres}"
CONTAINER="${POSTGRES_CONTAINER:-paperclip-pg}"
DB_NAME="${POSTGRES_DB_NAME:-paperclip}"
DB_USER="${POSTGRES_DB_USER:-paperclip}"
RETENTION_DAYS="${LOCAL_DUMP_RETENTION_DAYS:-3}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "Missing command: ${cmd}" >&2
    exit 1
  }
}

require_cmd docker
require_cmd gzip
require_cmd find

mkdir -p "${OUT_DIR}"

STAMP="$(date '+%Y%m%d-%H%M%S')"
DUMP_FILE="${OUT_DIR}/paperclip-${DB_NAME}-${STAMP}.sql.gz"

log "Exporting Postgres from container=${CONTAINER} db=${DB_NAME}"

docker exec "${CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" \
  | gzip -c > "${DUMP_FILE}"

log "Dump created at ${DUMP_FILE}"

# Keep short local retention, object storage retention is managed by restic.
find "${OUT_DIR}" -type f -name '*.sql.gz' -mtime "+${RETENTION_DAYS}" -delete

LATEST_LINK="${OUT_DIR}/latest.sql.gz"
ln -sfn "${DUMP_FILE}" "${LATEST_LINK}"

log "Local cleanup done and latest symlink updated"
