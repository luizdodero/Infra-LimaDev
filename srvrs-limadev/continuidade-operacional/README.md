# Continuidade Operacional - Infra LimaDev

Implementacao inicial do plano de backup e recuperacao para a infraestrutura LimaDev.

## Status atual - 2026-05-02

- Backend remoto: Backblaze B2, bucket privado `limadev-backup`.
- Repositorio Restic: inicializado e validado com `restic check`.
- Host implantado: `vps-assist`.
- Snapshots validados no `vps-assist`:
  - `db`: `2ec26849`
  - `system_config`: `13dcbb23`
- Drill validado:
  - `vps-assist-db`: PASS em `2026-05-02 18:13`.
- Telegram: validado com envio real.
- Heartbeat:
  - `vps-assist`: `ok`
  - demais hosts: pendentes, por isso o resumo diario fica `ATENCAO` ate completar rollout.
- Timers ativos no `vps-assist`:
  - `limadev-backup@vps-assist-db.timer`
  - `limadev-backup@vps-assist-system.timer`
  - `limadev-backup-drill@vps-assist-db.timer`
  - `limadev-heartbeat-report.timer`
  - `limadev-heartbeat-summary.timer`

## Escopo

- 5 maquinas: note-limdev, mini-pc, vps-assist, vps-dev, vps-prod.
- Backup criptografado com Restic em backend S3 compativel.
- Operacao automatizada com timer systemd.
- Alerta de sucesso/falha/atraso via Telegram.
- Recuperacao em 3 niveis: arquivo, servico e host completo.

## SLO inicial

- RPO: 6 horas para servicos criticos.
- RTO: 4 horas para servicos criticos.
- Retencao: 7 diarios, 4 semanais, 6 mensais.

## Estrutura

- `PRD_CONTINUIDADE_OPERACIONAL_V1.md`: documento de produto (escopo e requisitos).
- `PRD_HEARTBEAT_HERMES_V1.md`: documento de produto do heartbeat diario com Hermes/Telegram.
- `ROADMAP_HEARTBEAT_HERMES.md`: roadmap de desenvolvimento e testes do heartbeat.
- `SPRINT_2026-05-02_IMPLANTACAO_AUTONOMA.md`: sprint autonoma para expandir implantacao aos hosts restantes.
- `inventory/hosts_backup_matrix.csv`: matriz de hosts e classes de dado.
- `config/backup.env.example`: variaveis globais do stack de backup.
- `config/backup-credentials.env.example`: template seguro para cofre privado de credenciais.
- `config/excludes/`: exemplos de excludes por host/job.
- `config/jobs/job-template.env.example`: modelo de job por host/classe.
- `config/jobs/examples/`: exemplos de jobs prontos por host.
- `scripts/`: scripts de backup, restore, drill e instalacao.
- `scripts/vps-assist_export_postgres.sh`: helper de dump para o Postgres do vps-assist.
- `systemd/`: templates de service/timer para execucao automatica.
- `runbooks/`: procedimento operacional de restore e rebuild.
- `tests/heartbeat_tests.sh`: testes locais do fluxo de heartbeat.

## Quick start

1. Defina credenciais e parametros em `/etc/limadev/backup.env` usando o exemplo de `config/backup.env.example`.
   - Campos do backend S3 compativel: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
   - Backend/segredo Restic: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`.
2. Crie jobs em `/etc/limadev/jobs/*.env` usando `config/jobs/job-template.env.example`.
3. Instale scripts em `/usr/local/bin` com `scripts/install_backup_stack.sh`.
4. Ative timer por job, exemplo:
   - `systemctl enable --now limadev-backup@vps-assist-db.timer`
5. Valide snapshots:
   - `restic snapshots --host vps-assist --tag class:db`
6. Execute drill de restore:
   - `systemctl start limadev-backup-drill@vps-assist-db.service`
7. Opcional: valide heartbeat local:
   - `bash tests/heartbeat_tests.sh`

## Continuidade por host (vps-assist)

- Guia operacional do host: `../vps-assist/CONTINUIDADE_OPERACIONAL.md`.
- Exemplo de jobs: `config/jobs/examples/vps-assist-db.env.example` e `config/jobs/examples/vps-assist-system.env.example`.

## Credenciais do Backend

O local correto para inserir credenciais e configuracao S3 no host e:

- `/etc/limadev/backup.env`

Para guardar o conjunto de credenciais fora do host, use:

- template versionavel: `config/backup-credentials.env.example`
- arquivo privado local ignorado pelo git: `secure/limadev-backup-credentials.env`
- manual de uso e armazenamento seguro: `runbooks/manual-uso-backup-b2-heartbeat.md`
- runbook do heartbeat diario: `runbooks/heartbeat-diario.md`

Para Google Drive, guardar apenas copia criptografada (`.gpg`) do arquivo privado.
