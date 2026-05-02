#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  restore_job.sh --job-config /etc/limadev/jobs/<job>.env --target /restore/path [options]

Options:
  --env <file>           Global env file (default: /etc/limadev/backup.env)
  --job-config <file>    Job config file
  --host <host>          Override host name
  --class <class>        Override backup class
  --snapshot <id|latest> Snapshot to restore (default: latest)
  --target <dir>         Restore destination directory
  --include <path>       Include specific path only (can be repeated)
  -h, --help             Show this help
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
HOST_ARG=""
CLASS_ARG=""
SNAPSHOT="latest"
TARGET=""
declare -a INCLUDES
INCLUDES=()

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
    --host)
      HOST_ARG="$2"
      shift 2
      ;;
    --class)
      CLASS_ARG="$2"
      shift 2
      ;;
    --snapshot)
      SNAPSHOT="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --include)
      INCLUDES+=("$2")
      shift 2
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
# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ -n "${JOB_CONFIG}" ]]; then
  [[ -f "${JOB_CONFIG}" ]] || fatal "job config file not found: ${JOB_CONFIG}"
  # shellcheck disable=SC1090
  source "${JOB_CONFIG}"
fi

HOST="${HOST_ARG:-${BACKUP_HOST:-$(hostname -s)}}"
CLASS="${CLASS_ARG:-${BACKUP_CLASS:-}}"

[[ -n "${CLASS}" ]] || fatal "backup class not set"
[[ -n "${TARGET}" ]] || fatal "target path is required"
[[ -n "${RESTIC_REPOSITORY:-}" ]] || fatal "RESTIC_REPOSITORY is empty"
[[ -n "${RESTIC_PASSWORD_FILE:-}${RESTIC_PASSWORD:-}" ]] || fatal "RESTIC_PASSWORD_FILE or RESTIC_PASSWORD must be set"

command -v restic >/dev/null 2>&1 || fatal "restic binary not found"

mkdir -p "${TARGET}"

RESTORE_CMD=(restic restore "${SNAPSHOT}" --target "${TARGET}" --host "${HOST}" --tag "class:${CLASS}")

if ((${#INCLUDES[@]} > 0)); then
  for include_path in "${INCLUDES[@]}"; do
    RESTORE_CMD+=(--include "${include_path}")
  done
fi

log "Starting restore host=${HOST} class=${CLASS} snapshot=${SNAPSHOT} target=${TARGET}"
"${RESTORE_CMD[@]}" || fatal "restic restore failed"

FILE_COUNT="$(find "${TARGET}" -type f | wc -l | tr -d ' ')"
log "Restore finished host=${HOST} class=${CLASS} files=${FILE_COUNT}"
