# Continuidade Operacional - Infra LimaDev

Implementacao inicial do plano de backup e recuperacao para a infraestrutura LimaDev.

## Status atual - 2026-06-02

- Backend remoto: Backblaze B2, bucket privado `limadev-backup`.
- Repositorio Restic: inicializado; `restic snapshots --json` no `vps-assist` retornou 53 snapshots em 2026-06-02 apos revalidacao.
- Hosts operacionais:
  - `vps-assist`: PASS, host central de ingestao/summary.
  - `vps-prod`: PASS, com backups de DB/app/system, drill de DB e heartbeat ativos.
  - `vps-dev`: PASS, com backups de `repos`/`system_config` e heartbeat reportando OK; `db` local ficou fora do escopo operacional por ser apenas ambiente de teste local.
  - `mini-pc`: PASS, tratado como servidor; backups `system_config`, `repos` e `ops_artifacts`, heartbeat, timers de backup e timer recorrente de drill `mini-pc-system` ativos.
  - `note-limdev`: PASS parcial controlado, com backups `system_config`, `repos` e `ops_artifacts`, heartbeat e timers de backup ativos; drill manual de restore do `system_config` validado.
- Hosts pendentes/bloqueados:
  - nenhum no escopo atual.
- Snapshots recentes validados:
  - `vps-prod/db`: `509cc082`
  - `vps-prod/app_data`: `1fef25ef`
  - `vps-prod/system_config`: `cbbf1a75`
  - `vps-dev/repos`: `a0a880a2`
  - `vps-dev/system_config`: `ee2d75b1`
  - `mini-pc/system_config`: `ca549b06`
  - `mini-pc/repos`: `256c7e98`
  - `mini-pc/ops_artifacts`: `089725be`
  - `note-limdev/system_config`: `fa7f47fa`
  - `note-limdev/repos`: `e95b4ee5`
  - `note-limdev/ops_artifacts`: `94dd289a`
- Drill validado:
  - `vps-assist-db`: PASS recorrente.
  - `vps-prod-db`: PASS em `2026-06-01 19:21:51 -0300`.
  - `mini-pc-system`: PASS manual em `/var/log/limadev-backup/drill-mini-pc-system-manual-20260602-054914.md`.
  - `note-limdev-system`: PASS manual em `/var/log/limadev-backup/drill-note-limdev-system-manual-20260602-010904.md`.
- Telegram: validado com envio real previamente; summary diario segue ativo no `vps-assist`.
- Heartbeat no summary de 2026-06-02:
  - OK: `vps-assist`, `vps-prod`, `vps-dev`, `mini-pc`, `note-limdev`.
  - ATENCAO: nenhum.
  - Status geral: OK.
- Timers ativos:
  - `vps-assist`: backups, drill DB, heartbeat report e summary.
  - `vps-prod`: `limadev-backup@vps-prod-db.timer`, `limadev-backup@vps-prod-app.timer`, `limadev-backup@vps-prod-system.timer`, `limadev-backup-drill@vps-prod-db.timer`, `limadev-heartbeat-report.timer`.
  - `vps-dev`: `limadev-backup@vps-dev-repos.timer`, `limadev-backup@vps-dev-system.timer`, `limadev-heartbeat-report.timer`.
  - `mini-pc`: `limadev-backup@mini-pc-system.timer`, `limadev-backup@mini-pc-repos.timer`, `limadev-backup@mini-pc-ops.timer`, `limadev-heartbeat-report.timer`.
  - `mini-pc` drill recorrente: `limadev-backup-drill@mini-pc-system.timer` ativo; proxima janela observada em `2026-06-07 03:34:54 UTC`.
  - `note-limdev`: `limadev-backup@note-limdev-system.timer`, `limadev-backup@note-limdev-repos.timer`, `limadev-backup@note-limdev-ops.timer`, `limadev-heartbeat-report.timer`.
- Observacao operacional:
  - o snapshot historico `vps-dev/db` (`69b3ac14`) permanece no repositorio Restic como evidencia antiga, mas nao faz parte dos jobs/timers ativos.
  - `note-limdev` e a unica estacao de trabalho no escopo atual; drill pesado/restore amplo ficou sob autorizacao explicita em Multica `LIM-40`, status `in_review`, prioridade `medium`.
  - recorrencia de aprovacao do `note-limdev`: autopilot Multica `Solicitar janela de drill note-limdev` (`f4171362-8ade-4e94-a5c3-e08fb689a81e`), modo `create_issue`, cron `0 9 5 * *`, timezone `America/Sao_Paulo`, proxima criacao prevista `2026-06-05T12:00:00Z`; cria issue de revisao, nao executa drill automaticamente.
  - `backup_job.sh` foi ajustado para tratar lock de `forget/prune` como aviso quando o snapshot ja foi criado, evitando marcar backup bem-sucedido como falha por manutencao concorrente do repositorio.
  - pausa operacional registrada em `SPRINT_2026-05-02_IMPLANTACAO_AUTONOMA_STATUS.md` em 2026-06-02 13:32 -0300; proximos passos: acompanhar autopilot Multica de 05/06, executar drill do `note-limdev` somente com janela aprovada e revisar custo/tamanho do repositorio apos 7 dias de operacao.

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
