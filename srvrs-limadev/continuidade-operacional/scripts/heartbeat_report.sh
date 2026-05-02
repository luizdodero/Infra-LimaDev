#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${HEARTBEAT_ENV_FILE:-/etc/limadev/heartbeat.env}"
BACKUP_ENV_FILE="${BACKUP_ENV_FILE:-/etc/limadev/backup.env}"
JOBS_DIR="${HEARTBEAT_JOBS_DIR:-/etc/limadev/jobs}"
NOW="${HEARTBEAT_NOW:-$(date -Iseconds)}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

if [[ -f "${BACKUP_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${BACKUP_ENV_FILE}"
  set +a
fi

HOST="${HEARTBEAT_HOST:-}"
if [[ -z "${HOST}" ]]; then
  HOST="$(hostname -s)"
fi

DISK_WARN="${HEARTBEAT_DISK_WARN_PCT:-80}"
DISK_FAIL="${HEARTBEAT_DISK_FAIL_PCT:-90}"
ROOT_DISK_PCT="$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')"
UPTIME_SECONDS="$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null || printf '0')"

warnings_json='[]'
failed_units_json='[]'
jobs_json='[]'
overall_status="ok"

add_warning() {
  local message="$1"
  warnings_json="$(jq -c --arg message "${message}" '. + [$message]' <<<"${warnings_json}")"
}

set_status() {
  local candidate="$1"
  if [[ "${candidate}" == "fail" ]]; then
    overall_status="fail"
  elif [[ "${candidate}" == "warning" && "${overall_status}" == "ok" ]]; then
    overall_status="warning"
  fi
}

if (( ROOT_DISK_PCT >= DISK_FAIL )); then
  add_warning "root disk usage above fail threshold"
  set_status "fail"
elif (( ROOT_DISK_PCT >= DISK_WARN )); then
  add_warning "root disk usage above warning threshold"
  set_status "warning"
fi

if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r unit; do
    [[ -n "${unit}" ]] || continue
    failed_units_json="$(jq -c --arg unit "${unit}" '. + [$unit]' <<<"${failed_units_json}")"
    set_status "warning"
  done < <(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' || true)
fi

if [[ ! -d "${JOBS_DIR}" ]]; then
  add_warning "jobs directory not found"
  set_status "warning"
else
  shopt -s nullglob
  job_files=("${JOBS_DIR}"/*.env)
  shopt -u nullglob

  if ((${#job_files[@]} == 0)); then
    add_warning "no backup jobs configured"
    set_status "warning"
  fi

  for job_file in "${job_files[@]}"; do
    BACKUP_HOST=""
    BACKUP_CLASS=""
    BACKUP_PATHS=""
    # shellcheck disable=SC1090
    source "${job_file}"

    job_name="$(basename "${job_file}" .env)"
    job_host="${BACKUP_HOST:-${HOST}}"
    job_class="${BACKUP_CLASS:-unknown}"
    job_status="warning"
    latest_snapshot=""
    job_message=""

    if [[ -z "${BACKUP_CLASS:-}" ]]; then
      job_message="BACKUP_CLASS missing"
      set_status "warning"
    elif [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD_FILE:-}${RESTIC_PASSWORD:-}" ]]; then
      job_message="restic repository/password not configured"
      set_status "warning"
    elif ! command -v restic >/dev/null 2>&1; then
      job_message="restic binary not found"
      set_status "warning"
    else
      if snapshot_json="$(restic snapshots --json --host "${job_host}" --tag "class:${job_class}" --latest 1 2>/dev/null)"; then
        latest_snapshot="$(jq -r '.[0].short_id // .[0].id // ""' <<<"${snapshot_json}" 2>/dev/null || true)"
        if [[ -n "${latest_snapshot}" ]]; then
          job_status="ok"
          job_message="latest snapshot found"
        else
          job_message="no snapshots found"
          set_status "warning"
        fi
      else
        job_status="fail"
        job_message="restic snapshots failed"
        set_status "fail"
      fi
    fi

    jobs_json="$(jq -c \
      --arg name "${job_name}" \
      --arg host "${job_host}" \
      --arg class "${job_class}" \
      --arg status "${job_status}" \
      --arg latest_snapshot "${latest_snapshot}" \
      --arg message "${job_message}" \
      '. + [{name:$name, host:$host, class:$class, status:$status, latest_snapshot:$latest_snapshot, message:$message}]' \
      <<<"${jobs_json}")"
  done
fi

jq -n \
  --arg host "${HOST}" \
  --arg timestamp "${NOW}" \
  --arg status "${overall_status}" \
  --argjson uptime_seconds "${UPTIME_SECONDS}" \
  --argjson root_pct "${ROOT_DISK_PCT}" \
  --argjson jobs "${jobs_json}" \
  --argjson failed_units "${failed_units_json}" \
  --argjson warnings "${warnings_json}" \
  '{
    host: $host,
    timestamp: $timestamp,
    status: $status,
    uptime_seconds: $uptime_seconds,
    disk: {root_pct: $root_pct},
    jobs: $jobs,
    failed_units: $failed_units,
    warnings: $warnings
  }'
