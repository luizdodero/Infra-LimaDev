# Continuidade Operacional - vps-assist

## Objetivo

Operar backup, restore, drill e heartbeat do vps-assist seguindo o modulo central de continuidade operacional.

## Status - 2026-05-02

- Backend B2/Restic: validado.
- Backup `db`: PASS, snapshot `2ec26849`.
- Backup `system_config`: PASS, snapshot `13dcbb23`.
- Drill `db`: PASS.
- Heartbeat local: `ok`.
- Summary diario: `ATENCAO` ate os demais hosts reportarem.
- Timers ativos:
  - `limadev-backup@vps-assist-db.timer`
  - `limadev-backup@vps-assist-system.timer`
  - `limadev-backup-drill@vps-assist-db.timer`
  - `limadev-heartbeat-report.timer`
  - `limadev-heartbeat-summary.timer`

## Fonte de verdade

- Modulo: ../continuidade-operacional
- PRD: ../continuidade-operacional/PRD_CONTINUIDADE_OPERACIONAL_V1.md

## Credenciais do backend (onde inserir)

As credenciais devem ser configuradas no host vps-assist em:

- /etc/limadev/backup.env

Campos obrigatorios:

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- RESTIC_REPOSITORY
- RESTIC_PASSWORD_FILE (ou RESTIC_PASSWORD)

Exemplo base:

- ../continuidade-operacional/config/backup.env.example

Sugestao de senha do repositório Restic:

1. `sudo install -m 700 -d /etc/limadev`
2. `openssl rand -base64 48 | sudo tee /etc/limadev/restic-password >/dev/null`
3. `sudo chmod 600 /etc/limadev/restic-password`

## Continuidade de implementação no vps-assist

### 1) Instalar stack de backup no host

1. Copiar o modulo para o host ou acessar o repo no host.
2. Executar:
   - `sudo bash srvrs-limadev/continuidade-operacional/scripts/install_backup_stack.sh`

### 2) Criar jobs do vps-assist

1. Banco:
   - copiar ../continuidade-operacional/config/jobs/examples/vps-assist-db.env.example para /etc/limadev/jobs/vps-assist-db.env
2. Sistema:
   - copiar ../continuidade-operacional/config/jobs/examples/vps-assist-system.env.example para /etc/limadev/jobs/vps-assist-system.env

### 3) Exportar Postgres antes do snapshot de DB

- Script utilitario:
  - ../continuidade-operacional/scripts/vps-assist_export_postgres.sh

Execucao manual:

1. `sudo bash srvrs-limadev/continuidade-operacional/scripts/vps-assist_export_postgres.sh`
2. `sudo systemctl start limadev-backup@vps-assist-db.service`

### 4) Agendar timers

1. `sudo systemctl enable --now limadev-backup@vps-assist-db.timer`
2. `sudo systemctl enable --now limadev-backup@vps-assist-system.timer`
3. `sudo systemctl enable --now limadev-backup-drill@vps-assist-db.timer`

### 5) Validar

1. `sudo restic snapshots --host vps-assist --tag class:db`
2. `sudo journalctl -u limadev-backup@vps-assist-db.service -n 100 --no-pager`
3. `sudo systemctl status limadev-backup@vps-assist-db.timer`

## Restore rápido

- Arquivo/pasta:
  - `sudo limadev-restore-job.sh --job-config /etc/limadev/jobs/vps-assist-system.env --target /tmp/restore-system --snapshot latest`

- Drill:
  - `sudo systemctl start limadev-backup-drill@vps-assist-db.service`

## Referência operacional

- Runbooks: ../continuidade-operacional/runbooks
