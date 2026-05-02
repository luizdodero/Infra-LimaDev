#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  heartbeat_daily_summary.sh [--date YYYY-MM-DD]
EOF
}

ENV_FILE="${HEARTBEAT_ENV_FILE:-/etc/limadev/heartbeat.env}"
BACKUP_ENV_FILE="${BACKUP_ENV_FILE:-/etc/limadev/backup.env}"
SUMMARY_DATE="$(date '+%Y-%m-%d')"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      SUMMARY_DATE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

if [[ -f "${BACKUP_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${BACKUP_ENV_FILE}"
fi

EXPECTED_HOSTS="${HEARTBEAT_EXPECTED_HOSTS:-}"
STORE_DIR="${HEARTBEAT_STORE_DIR:-/var/lib/limadev-heartbeats}"
LOG_DIR="${HEARTBEAT_LOG_DIR:-/var/log/limadev-heartbeat}"
TELEGRAM_ENABLED="${HEARTBEAT_TELEGRAM_ENABLED:-1}"

mkdir -p "${LOG_DIR}"
summary_file="${LOG_DIR}/daily-summary-${SUMMARY_DATE}.md"

general_status="OK"
ok_hosts=()
warning_hosts=()
fail_hosts=()
missing_hosts=()

set_attention() {
  if [[ "${general_status}" == "OK" ]]; then
    general_status="ATENCAO"
  fi
}

for host in ${EXPECTED_HOSTS}; do
  report_file="${STORE_DIR}/${SUMMARY_DATE}/${host}.json"
  if [[ ! -f "${report_file}" ]]; then
    missing_hosts+=("${host}")
    set_attention
    continue
  fi

  status="$(jq -r '.status // "warning"' "${report_file}")"
  case "${status}" in
    ok)
      ok_hosts+=("${host}")
      ;;
    fail)
      fail_hosts+=("${host}")
      general_status="FALHA"
      ;;
    *)
      warning_hosts+=("${host}")
      set_attention
      ;;
  esac
done

write_list() {
  local title="$1"
  shift
  local items=("$@")
  printf '\n## %s\n\n' "${title}"
  if ((${#items[@]} == 0)); then
    printf -- '- nenhum\n'
  else
    for item in "${items[@]}"; do
      printf -- '- %s\n' "${item}"
    done
  fi
}

{
  printf '# Heartbeat Diario LimaDev\n\n'
  printf -- '- Data: %s\n' "${SUMMARY_DATE}"
  printf -- '- Status geral: %s\n' "${general_status}"
  write_list "OK" "${ok_hosts[@]}"
  write_list "Atencao" "${warning_hosts[@]}" "${missing_hosts[@]}"
  write_list "Falha" "${fail_hosts[@]}"
} > "${summary_file}"

telegram_text="$(sed -n '1,40p' "${summary_file}")"

if [[ "${TELEGRAM_ENABLED}" == "1" && -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  curl -sS --max-time 15 --retry 2 \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${telegram_text}" >/dev/null || true
fi

echo "summary:${summary_file}"
