# Heartbeat Hermes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a daily heartbeat flow where Infra LimaDev hosts report backup health to `vps-assist`, Hermes summarizes the state, and Telegram receives one daily confirmation.

**Architecture:** Each host runs a local systemd timer that generates a JSON heartbeat and sends it to `vps-assist` over restricted SSH. The `vps-assist` stores reports by date/host, computes a deterministic status, optionally asks Hermes to polish the message, sends Telegram, and writes markdown evidence.

**Tech Stack:** Bash, systemd timers, SSH over Tailscale, Restic CLI, jq, Telegram Bot API, Hermes CLI.

---

## File Structure

- Create `srvrs-limadev/continuidade-operacional/config/heartbeat.env.example`: global heartbeat defaults, host allowlist, thresholds, Telegram/Hermes switches.
- Create `srvrs-limadev/continuidade-operacional/scripts/heartbeat_report.sh`: local collector that prints JSON to stdout.
- Create `srvrs-limadev/continuidade-operacional/scripts/heartbeat_ingest.sh`: `vps-assist` stdin receiver that validates and stores JSON.
- Create `srvrs-limadev/continuidade-operacional/scripts/heartbeat_daily_summary.sh`: central daily summarizer and Telegram sender.
- Create `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-report.service`: per-host report sender.
- Create `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-report.timer`: daily per-host schedule.
- Create `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-summary.service`: `vps-assist` summary sender.
- Create `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-summary.timer`: daily summary schedule.
- Create `srvrs-limadev/continuidade-operacional/runbooks/heartbeat-diario.md`: install, operate, test, and recover heartbeat flow.
- Modify `srvrs-limadev/continuidade-operacional/scripts/install_backup_stack.sh`: install heartbeat scripts and units.
- Modify `srvrs-limadev/continuidade-operacional/README.md`: link PRD, roadmap, runbook, and quick start.

## Task 1: Heartbeat Configuration Contract

**Files:**
- Create: `srvrs-limadev/continuidade-operacional/config/heartbeat.env.example`

- [ ] **Step 1: Create the config example**

```bash
cat > srvrs-limadev/continuidade-operacional/config/heartbeat.env.example <<'EOF'
# LimaDev heartbeat configuration
# Copy to /etc/limadev/heartbeat.env and adjust values.

HEARTBEAT_EXPECTED_HOSTS="vps-assist vps-prod vps-dev mini-pc note-limdev"
HEARTBEAT_STORE_DIR="/var/lib/limadev-heartbeats"
HEARTBEAT_LOG_DIR="/var/log/limadev-heartbeat"

# Local host identity. Leave empty to use hostname -s.
HEARTBEAT_HOST=""

# vps-assist ingest target for non-central hosts.
HEARTBEAT_INGEST_SSH_TARGET="limadev-report@vps-assist"
HEARTBEAT_INGEST_COMMAND="limadev-heartbeat-ingest"

# Thresholds.
HEARTBEAT_DISK_WARN_PCT="80"
HEARTBEAT_DISK_FAIL_PCT="90"
HEARTBEAT_CRITICAL_BACKUP_GRACE_HOURS="2"
HEARTBEAT_DRILL_WARN_DAYS="8"

# Summary behavior. Telegram values may also come from /etc/limadev/backup.env.
HEARTBEAT_USE_HERMES="1"
HEARTBEAT_TELEGRAM_ENABLED="1"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
```

- [ ] **Step 2: Verify config file exists**

Run: `test -f srvrs-limadev/continuidade-operacional/config/heartbeat.env.example`

Expected: command exits `0`.

- [ ] **Step 3: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/config/heartbeat.env.example
git commit -m "docs: add heartbeat config contract"
```

## Task 2: Local Heartbeat Collector

**Files:**
- Create: `srvrs-limadev/continuidade-operacional/scripts/heartbeat_report.sh`

- [ ] **Step 1: Implement collector**

Create `heartbeat_report.sh` with Bash that:

- sources `/etc/limadev/heartbeat.env` when present;
- sources `/etc/limadev/backup.env` when present;
- detects `host`, `timestamp`, `uptime_seconds`, root disk usage, failed systemd units;
- iterates `/etc/limadev/jobs/*.env`;
- for each job, reads `BACKUP_HOST` and `BACKUP_CLASS`;
- calls `restic snapshots --host "$host" --tag "class:$class" --latest 1 --json` when Restic is configured;
- emits valid JSON to stdout;
- never prints secrets.

- [ ] **Step 2: Validate JSON manually**

Run: `bash srvrs-limadev/continuidade-operacional/scripts/heartbeat_report.sh | jq .`

Expected: valid JSON with top-level keys `host`, `timestamp`, `status`, `disk`, `jobs`, `failed_units`, and `warnings`.

- [ ] **Step 3: Validate missing Restic does not leak secrets**

Run: `PATH=/usr/bin:/bin bash srvrs-limadev/continuidade-operacional/scripts/heartbeat_report.sh | jq '.warnings'`

Expected: warning array exists; output contains no `AWS_SECRET_ACCESS_KEY`, `RESTIC_PASSWORD`, or Telegram token.

- [ ] **Step 4: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/scripts/heartbeat_report.sh
git commit -m "feat: add local heartbeat collector"
```

## Task 3: Central Ingest Script

**Files:**
- Create: `srvrs-limadev/continuidade-operacional/scripts/heartbeat_ingest.sh`

- [ ] **Step 1: Implement ingest**

Create `heartbeat_ingest.sh` with Bash that:

- reads JSON from stdin into a temp file;
- validates JSON using `jq -e`;
- extracts `.host`;
- sources `/etc/limadev/heartbeat.env`;
- rejects hosts not listed in `HEARTBEAT_EXPECTED_HOSTS`;
- writes to `$HEARTBEAT_STORE_DIR/YYYY-MM-DD/<host>.json`;
- logs success/failure to `$HEARTBEAT_LOG_DIR/ingest.log`.

- [ ] **Step 2: Test valid ingest**

Run:

```bash
printf '{"host":"vps-assist","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
  | HEARTBEAT_EXPECTED_HOSTS="vps-assist" HEARTBEAT_STORE_DIR="/tmp/limadev-heartbeats-test" HEARTBEAT_LOG_DIR="/tmp/limadev-heartbeat-log-test" \
    bash srvrs-limadev/continuidade-operacional/scripts/heartbeat_ingest.sh
```

Expected: file `/tmp/limadev-heartbeats-test/2026-05-02/vps-assist.json` exists.

- [ ] **Step 3: Test invalid host rejection**

Run:

```bash
printf '{"host":"unknown","timestamp":"2026-05-02T08:00:00-03:00","status":"ok"}\n' \
  | HEARTBEAT_EXPECTED_HOSTS="vps-assist" HEARTBEAT_STORE_DIR="/tmp/limadev-heartbeats-test" HEARTBEAT_LOG_DIR="/tmp/limadev-heartbeat-log-test" \
    bash srvrs-limadev/continuidade-operacional/scripts/heartbeat_ingest.sh
```

Expected: command exits non-zero and no `unknown.json` is written.

- [ ] **Step 4: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/scripts/heartbeat_ingest.sh
git commit -m "feat: add heartbeat ingest"
```

## Task 4: Daily Summary and Telegram

**Files:**
- Create: `srvrs-limadev/continuidade-operacional/scripts/heartbeat_daily_summary.sh`

- [ ] **Step 1: Implement summary**

Create `heartbeat_daily_summary.sh` with Bash that:

- sources `/etc/limadev/heartbeat.env` and `/etc/limadev/backup.env`;
- accepts optional `--date YYYY-MM-DD`;
- loads each expected host report for the date;
- marks missing reports;
- computes `OK`, `ATENCAO`, or `FALHA`;
- writes markdown evidence to `$HEARTBEAT_LOG_DIR/daily-summary-YYYY-MM-DD.md`;
- sends Telegram when enabled;
- uses deterministic fallback text when Hermes is unavailable.

- [ ] **Step 2: Test all OK fixture**

Create fixture reports under `/tmp/limadev-heartbeats-test/2026-05-02/` for all expected hosts with `status=ok`.

Run:

```bash
HEARTBEAT_EXPECTED_HOSTS="vps-assist vps-prod" HEARTBEAT_STORE_DIR="/tmp/limadev-heartbeats-test" HEARTBEAT_LOG_DIR="/tmp/limadev-heartbeat-log-test" HEARTBEAT_TELEGRAM_ENABLED="0" \
  bash srvrs-limadev/continuidade-operacional/scripts/heartbeat_daily_summary.sh --date 2026-05-02
```

Expected: summary markdown contains `Status geral: OK`.

- [ ] **Step 3: Test missing host fixture**

Remove `/tmp/limadev-heartbeats-test/2026-05-02/vps-prod.json`.

Run the same command.

Expected: summary markdown contains `Status geral: ATENCAO` and `vps-prod` under missing hosts.

- [ ] **Step 4: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/scripts/heartbeat_daily_summary.sh
git commit -m "feat: add heartbeat daily summary"
```

## Task 5: systemd Units

**Files:**
- Create: `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-report.service`
- Create: `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-report.timer`
- Create: `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-summary.service`
- Create: `srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-summary.timer`

- [ ] **Step 1: Create report service**

```ini
[Unit]
Description=LimaDev Heartbeat Report
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
EnvironmentFile=-/etc/limadev/heartbeat.env
ExecStart=/bin/bash -lc '/usr/local/bin/limadev-heartbeat-report.sh | ssh ${HEARTBEAT_INGEST_SSH_TARGET} ${HEARTBEAT_INGEST_COMMAND}'
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=read-only
```

- [ ] **Step 2: Create report timer**

```ini
[Unit]
Description=LimaDev Heartbeat Report Timer

[Timer]
OnCalendar=*-*-* 07:30:00
RandomizedDelaySec=900
Persistent=true
Unit=limadev-heartbeat-report.service

[Install]
WantedBy=timers.target
```

- [ ] **Step 3: Create summary service**

```ini
[Unit]
Description=LimaDev Heartbeat Daily Summary
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
EnvironmentFile=-/etc/limadev/heartbeat.env
EnvironmentFile=-/etc/limadev/backup.env
ExecStart=/usr/local/bin/limadev-heartbeat-daily-summary.sh
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/var/log/limadev-heartbeat /var/lib/limadev-heartbeats /tmp
```

- [ ] **Step 4: Create summary timer**

```ini
[Unit]
Description=LimaDev Heartbeat Daily Summary Timer

[Timer]
OnCalendar=*-*-* 08:30:00
RandomizedDelaySec=120
Persistent=true
Unit=limadev-heartbeat-summary.service

[Install]
WantedBy=timers.target
```

- [ ] **Step 5: Verify units**

Run: `systemd-analyze verify srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-*.service srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-*.timer`

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-*.service srvrs-limadev/continuidade-operacional/systemd/limadev-heartbeat-*.timer
git commit -m "feat: add heartbeat systemd units"
```

## Task 6: Installer and Runbook

**Files:**
- Modify: `srvrs-limadev/continuidade-operacional/scripts/install_backup_stack.sh`
- Create: `srvrs-limadev/continuidade-operacional/runbooks/heartbeat-diario.md`
- Modify: `srvrs-limadev/continuidade-operacional/README.md`

- [ ] **Step 1: Update installer**

Add install lines for:

- `heartbeat_report.sh` to `/usr/local/bin/limadev-heartbeat-report.sh`;
- `heartbeat_ingest.sh` to `/usr/local/bin/limadev-heartbeat-ingest`;
- `heartbeat_daily_summary.sh` to `/usr/local/bin/limadev-heartbeat-daily-summary.sh`;
- heartbeat systemd units to `/etc/systemd/system/`;
- create `/var/lib/limadev-heartbeats` and `/var/log/limadev-heartbeat`;
- copy `config/heartbeat.env.example` to `/etc/limadev/heartbeat.env` only when missing.

- [ ] **Step 2: Write runbook**

The runbook must include:

- install;
- SSH restricted user setup;
- manual local report;
- manual ingest;
- manual summary;
- timer activation;
- Telegram test;
- failure drills;
- troubleshooting.

- [ ] **Step 3: Update README**

Add links to:

- `PRD_HEARTBEAT_HERMES_V1.md`;
- `ROADMAP_HEARTBEAT_HERMES.md`;
- `runbooks/heartbeat-diario.md`.

- [ ] **Step 4: Verify docs paths**

Run: `test -f srvrs-limadev/continuidade-operacional/runbooks/heartbeat-diario.md`

Expected: command exits `0`.

- [ ] **Step 5: Commit**

```bash
git add srvrs-limadev/continuidade-operacional/scripts/install_backup_stack.sh srvrs-limadev/continuidade-operacional/runbooks/heartbeat-diario.md srvrs-limadev/continuidade-operacional/README.md
git commit -m "docs: add heartbeat operations runbook"
```

## Task 7: End-to-End Validation

**Files:**
- No new files required unless validation exposes gaps.

- [ ] **Step 1: Local-only validation on vps-assist**

Run:

```bash
sudo limadev-heartbeat-report.sh | sudo limadev-heartbeat-ingest
sudo limadev-heartbeat-daily-summary.sh
```

Expected: report JSON saved and markdown summary generated.

- [ ] **Step 2: Remote validation from vps-prod**

Run on `vps-prod`:

```bash
sudo limadev-heartbeat-report.sh | ssh limadev-report@vps-assist limadev-heartbeat-ingest
```

Expected: `vps-assist` contains today's `vps-prod.json`.

- [ ] **Step 3: Missing host drill**

Temporarily move one host report out of today's directory on `vps-assist`, then run summary.

Expected: Telegram/test summary marks `ATENCAO` and lists the missing host.

- [ ] **Step 4: Backup fail drill**

Use a fixture JSON with `status=fail` for a critical host, then run summary.

Expected: summary marks `FALHA`.

- [ ] **Step 5: Commit validation evidence**

If evidence files are sanitized and useful for the repo, add an evidence markdown under the runbooks/evidences location chosen by the operator. Do not commit secrets or raw host logs.

## Self-Review

- PRD coverage: the plan covers local collection, SSH ingest, central storage, Hermes/Telegram summary, systemd timers, runbook, and tests.
- Placeholder scan: no implementation step depends on an undefined external task; code bodies that require implementation are scoped by exact behavior and file path.
- Type consistency: config names use `HEARTBEAT_*` consistently across tasks.

Plan execution should start with Task 1 and stop after each task for review if running in production hosts.
