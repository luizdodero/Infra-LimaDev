#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  backup_job.sh --job-config /etc/limadev/jobs/<job>.env [options]

Options:
  --env <file>           Global env file (default: /etc/limadev/backup.env)
  --job-config <file>    Job config file with BACKUP_HOST/BACKUP_CLASS/BACKUP_PATHS
  --host <host>          Override host name
  --class <class>        Override backup class (db, app_data, system_config, repos, ops_artifacts)
  --path <path>          Add backup path (can be repeated)
  --dry-run              Run without writing snapshots
  -h, --help             Show this help
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

notify_telegram() {
  local message="$1"

  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    return 0
  fi

  curl -sS --max-time 15 --retry 2 \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${message}" >/dev/null || true
}

fatal() {
  local reason="$1"
  log "ERROR: ${reason}"
  notify_telegram "[BACKUP][FAIL] host=${HOST:-unknown} class=${CLASS:-unknown} reason=${reason}"
  exit 1
}

run_hook() {
  local hook_cmd="$1"
  local hook_name="$2"

  if [[ -z "${hook_cmd}" ]]; then
    return 0
  fi

  log "Running ${hook_name}: ${hook_cmd}"
  bash -lc "${hook_cmd}" || fatal "${hook_name} failed"
}

ENV_FILE="/etc/limadev/backup.env"
JOB_CONFIG=""
HOST_ARG=""
CLASS_ARG=""
DRY_RUN="0"
declare -a PATH_ARGS
PATH_ARGS=()

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
    --path)
      PATH_ARGS+=("$2")
      shift 2
      ;;
    --dry-run)
      DRY_RUN="1"
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

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Global env file not found: ${ENV_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

if [[ -n "${JOB_CONFIG}" ]]; then
  if [[ ! -f "${JOB_CONFIG}" ]]; then
    echo "Job config file not found: ${JOB_CONFIG}"
    exit 1
  fi
  # shellcheck disable=SC1090
  source "${JOB_CONFIG}"
fi

HOST="${HOST_ARG:-${BACKUP_HOST:-$(hostname -s)}}"
CLASS="${CLASS_ARG:-${BACKUP_CLASS:-}}"

if [[ -z "${CLASS}" ]]; then
  fatal "backup class not set"
fi

if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
  fatal "RESTIC_REPOSITORY is empty"
fi

if [[ -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD:-}" ]]; then
  fatal "RESTIC_PASSWORD_FILE or RESTIC_PASSWORD must be set"
fi

if ! command -v restic >/dev/null 2>&1; then
  fatal "restic binary not found"
fi

if ! command -v curl >/dev/null 2>&1; then
  log "WARN: curl not found, Telegram notifications disabled"
  TELEGRAM_BOT_TOKEN=""
  TELEGRAM_CHAT_ID=""
fi

run_hook "${PRE_BACKUP_HOOK:-}" "PRE_BACKUP_HOOK"

declare -a PATHS
if ((${#PATH_ARGS[@]} > 0)); then
  PATHS=("${PATH_ARGS[@]}")
else
  read -r -a PATHS <<< "${BACKUP_PATHS:-}"
fi

if ((${#PATHS[@]} == 0)); then
  fatal "no backup paths provided"
fi

log "Starting backup host=${HOST} class=${CLASS} repo=${RESTIC_REPOSITORY}"

if ! restic snapshots >/dev/null 2>&1; then
  if restic cat config >/dev/null 2>&1; then
    log "WARN: restic snapshots preflight failed, but repository config exists; proceeding"
  else
    log "Repository not initialized, running restic init"
    restic init || fatal "restic init failed"
  fi
fi

declare -a VALID_PATHS
VALID_PATHS=()
for path in "${PATHS[@]}"; do
  if [[ -e "${path}" ]]; then
    VALID_PATHS+=("${path}")
  else
    log "WARN: path does not exist and will be skipped: ${path}"
  fi
done

if ((${#VALID_PATHS[@]} == 0)); then
  fatal "all paths were missing"
fi

BACKUP_CMD=(restic backup --host "${HOST}" --tag "host:${HOST}" --tag "class:${CLASS}" --tag "source:limadev" --one-file-system)

for extra_tag in ${BACKUP_EXTRA_TAGS:-}; do
  BACKUP_CMD+=(--tag "${extra_tag}")
done

JOB_EXCLUDE="${JOB_EXCLUDE_FILE:-}"
if [[ -n "${JOB_EXCLUDE}" ]]; then
  if [[ -f "${JOB_EXCLUDE}" ]]; then
    BACKUP_CMD+=(--exclude-file "${JOB_EXCLUDE}")
  else
    log "WARN: JOB_EXCLUDE_FILE not found: ${JOB_EXCLUDE}"
  fi
elif [[ -n "${EXCLUDE_FILE:-}" ]]; then
  if [[ -f "${EXCLUDE_FILE}" ]]; then
    BACKUP_CMD+=(--exclude-file "${EXCLUDE_FILE}")
  else
    log "WARN: EXCLUDE_FILE not found: ${EXCLUDE_FILE}"
  fi
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  BACKUP_CMD+=(--dry-run)
fi

BACKUP_CMD+=("${VALID_PATHS[@]}")

"${BACKUP_CMD[@]}" || fatal "restic backup command failed"

if [[ "${DRY_RUN}" == "0" ]]; then
  forget_output=""
  forget_ok="0"
  for attempt in 1 2 3; do
    if forget_output="$(restic forget --prune \
      --host "${HOST}" \
      --tag "class:${CLASS}" \
      --keep-daily "${KEEP_DAILY:-7}" \
      --keep-weekly "${KEEP_WEEKLY:-4}" \
      --keep-monthly "${KEEP_MONTHLY:-6}" 2>&1)"; then
      printf '%s\n' "${forget_output}"
      forget_ok="1"
      break
    fi

    printf '%s\n' "${forget_output}"
    if grep -qi 'repository is already locked\|unable to create lock' <<<"${forget_output}" && [[ "${attempt}" != "3" ]]; then
      log "WARN: restic forget/prune locked; retrying attempt $((attempt + 1))/3"
      sleep $((attempt * 20))
      continue
    fi
    break
  done

  if [[ "${forget_ok}" != "1" ]]; then
    if grep -qi 'repository is already locked\|unable to create lock' <<<"${forget_output}"; then
      log "WARN: restic forget/prune skipped after retries because repository is locked; backup snapshot was already created"
      notify_telegram "[BACKUP][WARN] host=${HOST} class=${CLASS} reason=forget_prune_locked_snapshot_created"
    else
      fatal "restic forget/prune failed"
    fi
  fi
fi

run_hook "${POST_BACKUP_HOOK:-}" "POST_BACKUP_HOOK"

LATEST_INFO="$(restic snapshots --host "${HOST}" --tag "class:${CLASS}" --latest 1 2>/dev/null | tail -n 2 | tr '\n' ' ' || true)"
log "Backup finished host=${HOST} class=${CLASS}"
notify_telegram "[BACKUP][OK] host=${HOST} class=${CLASS} latest=${LATEST_INFO}"
