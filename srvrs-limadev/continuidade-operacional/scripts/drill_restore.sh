#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  drill_restore.sh --job-config /etc/limadev/jobs/<job>.env [options]

Options:
  --env <file>            Global env file (default: /etc/limadev/backup.env)
  --job-config <file>     Job config file
  --snapshot <id|latest>  Snapshot to validate (default: latest)
  --target-base <dir>     Base directory for temporary restore
  --report-file <file>    Markdown report output
  --keep-target           Keep restored files after drill
  -h, --help              Show this help
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fatal() {
  echo "ERROR: $1" >&2
  exit 1
}

ENV_FILE="/etc/limadev/backup.env"
JOB_CONFIG=""
SNAPSHOT="latest"
TARGET_BASE="/tmp/limadev-drill"
REPORT_FILE=""
KEEP_TARGET="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    --job-config)
      JOB_CONFIG="$2"
      shift 2
      ;;
    --snapshot)
      SNAPSHOT="$2"
      shift 2
      ;;
    --target-base)
      TARGET_BASE="$2"
      shift 2
      ;;
    --report-file)
      REPORT_FILE="$2"
      shift 2
      ;;
    --keep-target)
      KEEP_TARGET="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

[[ -f "${ENV_FILE}" ]] || fatal "global env file not found: ${ENV_FILE}"
[[ -n "${JOB_CONFIG}" ]] || fatal "job config is required"
[[ -f "${JOB_CONFIG}" ]] || fatal "job config file not found: ${JOB_CONFIG}"

# shellcheck disable=SC1090
source "${ENV_FILE}"
# shellcheck disable=SC1090
source "${JOB_CONFIG}"

HOST="${BACKUP_HOST:-$(hostname -s)}"
CLASS="${BACKUP_CLASS:-}"

[[ -n "${CLASS}" ]] || fatal "BACKUP_CLASS is empty in job config"
[[ -n "${RESTIC_REPOSITORY:-}" ]] || fatal "RESTIC_REPOSITORY is empty"
[[ -n "${RESTIC_PASSWORD_FILE:-}${RESTIC_PASSWORD:-}" ]] || fatal "RESTIC_PASSWORD_FILE or RESTIC_PASSWORD must be set"

command -v restic >/dev/null 2>&1 || fatal "restic binary not found"

mkdir -p "${TARGET_BASE}"
DRILL_TARGET="$(mktemp -d "${TARGET_BASE}/${HOST}-${CLASS}-XXXX")"

if [[ -z "${REPORT_FILE}" ]]; then
  mkdir -p /var/log/limadev-backup
  REPORT_FILE="/var/log/limadev-backup/drill-${HOST}-${CLASS}-$(date '+%Y%m%d-%H%M%S').md"
fi

CHECK_SUBSET="${DRILL_CHECK_SUBSET:-10%}"

START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
log "Running restic check subset=${CHECK_SUBSET}"
restic check --read-data-subset "${CHECK_SUBSET}" >/dev/null

log "Restoring snapshot=${SNAPSHOT} host=${HOST} class=${CLASS} into ${DRILL_TARGET}"
restic restore "${SNAPSHOT}" --target "${DRILL_TARGET}" --host "${HOST}" --tag "class:${CLASS}" >/dev/null

FILE_COUNT="$(find "${DRILL_TARGET}" -type f | wc -l | tr -d ' ')"
END_TS="$(date '+%Y-%m-%d %H:%M:%S')"

cat > "${REPORT_FILE}" <<EOF
# Drill Restore Report

- Start: ${START_TS}
- End: ${END_TS}
- Host: ${HOST}
- Class: ${CLASS}
- Snapshot: ${SNAPSHOT}
- Restored files: ${FILE_COUNT}
- Target: ${DRILL_TARGET}
- Result: PASS
EOF

if [[ "${KEEP_TARGET}" != "1" && "${DRILL_KEEP_TARGET:-0}" != "1" ]]; then
  rm -rf "${DRILL_TARGET}"
fi

log "Drill completed successfully. Report: ${REPORT_FILE}"
