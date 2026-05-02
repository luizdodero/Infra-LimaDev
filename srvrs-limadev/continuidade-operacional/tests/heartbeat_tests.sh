#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$file" || fail "expected '${pattern}' in ${file}"
}

make_env() {
  cat > "${TMP_DIR}/heartbeat.env" <<EOF
HEARTBEAT_EXPECTED_HOSTS="vps-assist vps-prod"
HEARTBEAT_STORE_DIR="${TMP_DIR}/store"
HEARTBEAT_LOG_DIR="${TMP_DIR}/log"
HEARTBEAT_HOST="vps-assist"
HEARTBEAT_TELEGRAM_ENABLED="0"
HEARTBEAT_USE_HERMES="0"
EOF
}

test_report_outputs_valid_json() {
  make_env
  mkdir -p "${TMP_DIR}/jobs"
  cat > "${TMP_DIR}/jobs/vps-assist-system.env" <<'EOF'
BACKUP_HOST="vps-assist"
BACKUP_CLASS="system_config"
BACKUP_PATHS="/etc"
EOF

  HEARTBEAT_ENV_FILE="${TMP_DIR}/heartbeat.env" \
  HEARTBEAT_JOBS_DIR="${TMP_DIR}/jobs" \
  HEARTBEAT_NOW="2026-05-02T08:00:00-03:00" \
    bash "${ROOT_DIR}/scripts/heartbeat_report.sh" > "${TMP_DIR}/report.json"

  jq -e '.host == "vps-assist"' "${TMP_DIR}/report.json" >/dev/null
  jq -e '.jobs[0].class == "system_config"' "${TMP_DIR}/report.json" >/dev/null
  jq -e '.status == "warning" or .status == "ok" or .status == "fail"' "${TMP_DIR}/report.json" >/dev/null
}

test_ingest_accepts_known_host() {
  make_env
  mkdir -p "${TMP_DIR}/store" "${TMP_DIR}/log"
  printf '{"host":"vps-assist","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
    | HEARTBEAT_ENV_FILE="${TMP_DIR}/heartbeat.env" bash "${ROOT_DIR}/scripts/heartbeat_ingest.sh"

  assert_file "${TMP_DIR}/store/2026-05-02/vps-assist.json"
}

test_ingest_rejects_unknown_host() {
  make_env
  mkdir -p "${TMP_DIR}/store" "${TMP_DIR}/log"
  if printf '{"host":"unknown","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
    | HEARTBEAT_ENV_FILE="${TMP_DIR}/heartbeat.env" bash "${ROOT_DIR}/scripts/heartbeat_ingest.sh"; then
    fail "unknown host was accepted"
  fi
}

test_summary_marks_missing_host_attention() {
  make_env
  mkdir -p "${TMP_DIR}/store/2026-05-02" "${TMP_DIR}/log"
  printf '{"host":"vps-assist","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
    > "${TMP_DIR}/store/2026-05-02/vps-assist.json"

  HEARTBEAT_ENV_FILE="${TMP_DIR}/heartbeat.env" \
    bash "${ROOT_DIR}/scripts/heartbeat_daily_summary.sh" --date 2026-05-02

  assert_file "${TMP_DIR}/log/daily-summary-2026-05-02.md"
  assert_contains "${TMP_DIR}/log/daily-summary-2026-05-02.md" "Status geral: ATENCAO"
  assert_contains "${TMP_DIR}/log/daily-summary-2026-05-02.md" "vps-prod"
}

test_summary_marks_all_ok() {
  make_env
  mkdir -p "${TMP_DIR}/store/2026-05-02" "${TMP_DIR}/log"
  printf '{"host":"vps-assist","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
    > "${TMP_DIR}/store/2026-05-02/vps-assist.json"
  printf '{"host":"vps-prod","timestamp":"2026-05-02T08:01:00-03:00","status":"ok"}\n' \
    > "${TMP_DIR}/store/2026-05-02/vps-prod.json"

  HEARTBEAT_ENV_FILE="${TMP_DIR}/heartbeat.env" \
    bash "${ROOT_DIR}/scripts/heartbeat_daily_summary.sh" --date 2026-05-02

  assert_file "${TMP_DIR}/log/daily-summary-2026-05-02.md"
  assert_contains "${TMP_DIR}/log/daily-summary-2026-05-02.md" "Status geral: OK"
}

test_report_outputs_valid_json
test_ingest_accepts_known_host
test_ingest_rejects_unknown_host
test_summary_marks_missing_host_attention
test_summary_marks_all_ok

echo "heartbeat tests passed"
