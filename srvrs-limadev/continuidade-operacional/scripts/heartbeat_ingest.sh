#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${HEARTBEAT_ENV_FILE:-/etc/limadev/heartbeat.env}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

EXPECTED_HOSTS="${HEARTBEAT_EXPECTED_HOSTS:-}"
STORE_DIR="${HEARTBEAT_STORE_DIR:-/var/lib/limadev-heartbeats}"
LOG_DIR="${HEARTBEAT_LOG_DIR:-/var/log/limadev-heartbeat}"

mkdir -p "${STORE_DIR}" "${LOG_DIR}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_DIR}/ingest.log"
}

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
cat > "${tmp}"

if ! jq -e . "${tmp}" >/dev/null 2>&1; then
  log "reject invalid_json"
  echo "invalid json" >&2
  exit 1
fi

host="$(jq -r '.host // empty' "${tmp}")"
timestamp="$(jq -r '.timestamp // empty' "${tmp}")"

if [[ -z "${host}" ]]; then
  log "reject missing_host"
  echo "missing host" >&2
  exit 1
fi

allowed="0"
for expected in ${EXPECTED_HOSTS}; do
  if [[ "${host}" == "${expected}" ]]; then
    allowed="1"
    break
  fi
done

if [[ "${allowed}" != "1" ]]; then
  log "reject unknown_host host=${host}"
  echo "unknown host: ${host}" >&2
  exit 1
fi

report_date="${timestamp:0:10}"
if [[ ! "${report_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  report_date="$(date '+%Y-%m-%d')"
fi

target_dir="${STORE_DIR}/${report_date}"
mkdir -p "${target_dir}"
install -m 0640 "${tmp}" "${target_dir}/${host}.json"
log "accepted host=${host} date=${report_date}"
