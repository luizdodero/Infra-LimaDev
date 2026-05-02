#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root (sudo)."
    exit 1
  fi
}

require_root

log "Installing dependencies"
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y restic rclone curl ca-certificates jq
else
  echo "Unsupported package manager. Install restic, rclone, curl and jq manually."
  exit 1
fi

log "Creating directories"
mkdir -p /etc/limadev/jobs
mkdir -p /etc/limadev/excludes
mkdir -p /var/log/limadev-backup
mkdir -p /var/log/limadev-heartbeat
mkdir -p /var/lib/limadev-heartbeats

log "Installing scripts"
install -m 0755 "${PROJECT_DIR}/scripts/backup_job.sh" /usr/local/bin/limadev-backup-job.sh
install -m 0755 "${PROJECT_DIR}/scripts/restore_job.sh" /usr/local/bin/limadev-restore-job.sh
install -m 0755 "${PROJECT_DIR}/scripts/drill_restore.sh" /usr/local/bin/limadev-drill-restore.sh
install -m 0755 "${PROJECT_DIR}/scripts/vps-assist_export_postgres.sh" /usr/local/bin/limadev-vps-assist-export-postgres.sh
install -m 0755 "${PROJECT_DIR}/scripts/heartbeat_report.sh" /usr/local/bin/limadev-heartbeat-report.sh
install -m 0755 "${PROJECT_DIR}/scripts/heartbeat_ingest.sh" /usr/local/bin/limadev-heartbeat-ingest
install -m 0755 "${PROJECT_DIR}/scripts/heartbeat_daily_summary.sh" /usr/local/bin/limadev-heartbeat-daily-summary.sh

log "Installing systemd units"
install -m 0644 "${PROJECT_DIR}/systemd/limadev-backup@.service" /etc/systemd/system/limadev-backup@.service
install -m 0644 "${PROJECT_DIR}/systemd/limadev-backup@.timer" /etc/systemd/system/limadev-backup@.timer
install -m 0644 "${PROJECT_DIR}/systemd/limadev-backup-drill@.service" /etc/systemd/system/limadev-backup-drill@.service
install -m 0644 "${PROJECT_DIR}/systemd/limadev-backup-drill@.timer" /etc/systemd/system/limadev-backup-drill@.timer
install -m 0644 "${PROJECT_DIR}/systemd/limadev-heartbeat-report.service" /etc/systemd/system/limadev-heartbeat-report.service
install -m 0644 "${PROJECT_DIR}/systemd/limadev-heartbeat-report.timer" /etc/systemd/system/limadev-heartbeat-report.timer
install -m 0644 "${PROJECT_DIR}/systemd/limadev-heartbeat-summary.service" /etc/systemd/system/limadev-heartbeat-summary.service
install -m 0644 "${PROJECT_DIR}/systemd/limadev-heartbeat-summary.timer" /etc/systemd/system/limadev-heartbeat-summary.timer

systemctl daemon-reload

if [[ ! -f /etc/limadev/backup.env ]]; then
  cp "${PROJECT_DIR}/config/backup.env.example" /etc/limadev/backup.env
  log "Created /etc/limadev/backup.env from example"
fi

if [[ ! -f /etc/limadev/heartbeat.env ]]; then
  cp "${PROJECT_DIR}/config/heartbeat.env.example" /etc/limadev/heartbeat.env
  log "Created /etc/limadev/heartbeat.env from example"
fi

log "Installation done"
log "Next steps:"
log "1) Edit /etc/limadev/backup.env"
log "2) Create /etc/limadev/jobs/<job>.env using config/jobs/job-template.env.example"
log "3) Enable timer: systemctl enable --now limadev-backup@<job>.timer"
log "4) Optional drill: systemctl enable --now limadev-backup-drill@<job>.timer"
log "5) Optional heartbeat: systemctl enable --now limadev-heartbeat-report.timer"
log "6) On vps-assist summary: systemctl enable --now limadev-heartbeat-summary.timer"
