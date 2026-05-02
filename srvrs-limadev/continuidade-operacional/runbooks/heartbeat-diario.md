# Runbook - Heartbeat Diario Hermes/Telegram

## Objetivo

Validar diariamente que os hosts do escopo Infra LimaDev continuam reportando saude de backup para o `vps-assist` e que o resumo diario chega no Telegram.

## Componentes

- Coleta local: `limadev-heartbeat-report.sh`
- Ingestao central: `limadev-heartbeat-ingest`
- Resumo diario: `limadev-heartbeat-daily-summary.sh`
- Config local: `/etc/limadev/heartbeat.env`
- Reports recebidos: `/var/lib/limadev-heartbeats/YYYY-MM-DD/<host>.json`
- Evidencia diaria: `/var/log/limadev-heartbeat/daily-summary-YYYY-MM-DD.md`

## Pre-requisitos

- `jq`, `curl`, `restic` e `ssh` instalados.
- `/etc/limadev/backup.env` configurado quando o host tiver jobs Restic.
- `/etc/limadev/jobs/*.env` criado para os jobs de backup do host.
- Telegram configurado em `/etc/limadev/backup.env` ou `/etc/limadev/heartbeat.env`.
- No `vps-assist`, usuario restrito `limadev-report` configurado para ingestao via SSH.

## Configuracao

Copiar o exemplo:

```bash
sudo cp srvrs-limadev/continuidade-operacional/config/heartbeat.env.example /etc/limadev/heartbeat.env
sudo chmod 600 /etc/limadev/heartbeat.env
sudo chown root:root /etc/limadev/heartbeat.env
```

Editar:

```bash
sudo nano /etc/limadev/heartbeat.env
```

Campos principais:

```env
HEARTBEAT_EXPECTED_HOSTS="vps-assist vps-prod vps-dev mini-pc note-limdev"
HEARTBEAT_STORE_DIR="/var/lib/limadev-heartbeats"
HEARTBEAT_LOG_DIR="/var/log/limadev-heartbeat"
HEARTBEAT_INGEST_SSH_TARGET="limadev-report@vps-assist"
HEARTBEAT_INGEST_COMMAND="limadev-heartbeat-ingest"
HEARTBEAT_TELEGRAM_ENABLED="1"
HEARTBEAT_USE_HERMES="1"
```

## Teste Local

No host:

```bash
sudo limadev-heartbeat-report.sh | jq .
```

Resultado esperado:

- JSON valido.
- Campo `host` correto.
- Campo `status` com `ok`, `warning` ou `fail`.
- Array `jobs` contendo os jobs locais quando existirem.

## Teste de Ingestao no vps-assist

No `vps-assist`:

```bash
sudo limadev-heartbeat-report.sh | sudo limadev-heartbeat-ingest
```

Validar:

```bash
sudo find /var/lib/limadev-heartbeats -type f | sort
sudo tail -n 50 /var/log/limadev-heartbeat/ingest.log
```

## Teste Remoto via SSH

Em um host cliente:

```bash
sudo limadev-heartbeat-report.sh | ssh limadev-report@vps-assist limadev-heartbeat-ingest
```

No `vps-assist`, validar que o arquivo do host chegou:

```bash
sudo find /var/lib/limadev-heartbeats/$(date +%F) -type f | sort
```

## Resumo Diario Manual

No `vps-assist`:

```bash
sudo limadev-heartbeat-daily-summary.sh
sudo cat /var/log/limadev-heartbeat/daily-summary-$(date +%F).md
```

Resultado esperado:

- `Status geral: OK`, `ATENCAO` ou `FALHA`.
- Hosts ausentes listados quando nao reportarem.
- Mensagem enviada ao Telegram quando `HEARTBEAT_TELEGRAM_ENABLED=1`.

## Ativar Timers

Em cada host que deve reportar:

```bash
sudo systemctl enable --now limadev-heartbeat-report.timer
sudo systemctl status limadev-heartbeat-report.timer --no-pager
```

No `vps-assist`:

```bash
sudo systemctl enable --now limadev-heartbeat-summary.timer
sudo systemctl status limadev-heartbeat-summary.timer --no-pager
```

## Drill de Falha

### Host ausente

No `vps-assist`, mover temporariamente um report do dia:

```bash
sudo mkdir -p /tmp/limadev-heartbeat-drill
sudo mv /var/lib/limadev-heartbeats/$(date +%F)/vps-prod.json /tmp/limadev-heartbeat-drill/ 2>/dev/null || true
sudo limadev-heartbeat-daily-summary.sh
```

Esperado:

- `Status geral: ATENCAO`.
- `vps-prod` listado na secao de atencao.

Restaurar fixture se necessario:

```bash
sudo mv /tmp/limadev-heartbeat-drill/vps-prod.json /var/lib/limadev-heartbeats/$(date +%F)/ 2>/dev/null || true
```

### Falha declarada

Criar JSON temporario de falha:

```bash
today="$(date +%F)"
sudo mkdir -p "/var/lib/limadev-heartbeats/${today}"
printf '{"host":"vps-prod","timestamp":"%sT08:00:00-03:00","status":"fail"}\n' "${today}" \
  | sudo tee "/var/lib/limadev-heartbeats/${today}/vps-prod.json" >/dev/null
sudo limadev-heartbeat-daily-summary.sh
```

Esperado:

- `Status geral: FALHA`.

## Troubleshooting

- Sem JSON: verificar `journalctl -u limadev-heartbeat-report.service`.
- Report nao chega: validar SSH/Tailscale e `authorized_keys` do `limadev-report`.
- Host rejeitado: conferir `HEARTBEAT_EXPECTED_HOSTS`.
- Telegram nao chega: conferir `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` e conectividade externa.
- Status `warning` sem erro claro: conferir `warnings` no JSON do host.
