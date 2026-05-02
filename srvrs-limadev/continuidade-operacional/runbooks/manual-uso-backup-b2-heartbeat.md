# Manual de Uso - Backup B2, Restic e Heartbeat Hermes

## Objetivo

Este manual descreve como usar e guardar as credenciais do backup da Infra LimaDev, como configurar os hosts e como validar o fluxo diario de heartbeat com Hermes e Telegram.

## Arquivos Importantes

- Template versionavel de credenciais: `config/backup-credentials.env.example`
- Arquivo privado para preencher: `secure/limadev-backup-credentials.env`
- Config do host: `/etc/limadev/backup.env`
- Senha Restic no host: `/etc/limadev/restic-password`
- Config heartbeat no host: `/etc/limadev/heartbeat.env`
- Evidencias de backup: `/var/log/limadev-backup`
- Evidencias de heartbeat: `/var/log/limadev-heartbeat`
- Heartbeats recebidos no `vps-assist`: `/var/lib/limadev-heartbeats`

## Regra de Seguranca

Nunca commitar credenciais reais.

O arquivo preenchido `secure/limadev-backup-credentials.env` e ignorado pelo git porque o `.gitignore` do repo ja ignora `*.env`.

Para Google Drive, guardar somente uma copia criptografada, por exemplo:

```bash
gpg -c --cipher-algo AES256 secure/limadev-backup-credentials.env
```

Isso gera:

```text
secure/limadev-backup-credentials.env.gpg
```

Guarde no Google Drive o arquivo `.gpg`, nao o `.env` aberto.

## Criar o Arquivo Privado de Credenciais

No repo:

```bash
mkdir -p srvrs-limadev/continuidade-operacional/secure
cp srvrs-limadev/continuidade-operacional/config/backup-credentials.env.example \
  srvrs-limadev/continuidade-operacional/secure/limadev-backup-credentials.env
chmod 600 srvrs-limadev/continuidade-operacional/secure/limadev-backup-credentials.env
```

Editar:

```bash
nano srvrs-limadev/continuidade-operacional/secure/limadev-backup-credentials.env
```

Preencher pelo menos:

- `B2_APPLICATION_KEY_ID`
- `B2_APPLICATION_KEY`
- `B2_BUCKET_NAME`
- `B2_REGION`
- `B2_S3_ENDPOINT`
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

## Gerar Senha Forte do Restic

```bash
openssl rand -base64 48
```

Guarde essa senha no arquivo privado. Sem ela, o backup criptografado nao pode ser restaurado.

## Configurar um Host

No host alvo:

```bash
sudo install -m 700 -d /etc/limadev
sudo install -m 700 -d /etc/limadev/jobs
sudo install -m 700 -d /etc/limadev/excludes
```

Criar `/etc/limadev/restic-password`:

```bash
sudo nano /etc/limadev/restic-password
sudo chmod 600 /etc/limadev/restic-password
sudo chown root:root /etc/limadev/restic-password
```

Criar `/etc/limadev/backup.env`:

```bash
sudo nano /etc/limadev/backup.env
sudo chmod 600 /etc/limadev/backup.env
sudo chown root:root /etc/limadev/backup.env
```

Formato minimo:

```env
RESTIC_REPOSITORY="s3:s3.us-west-002.backblazeb2.com/limadev-backup"
RESTIC_PASSWORD_FILE="/etc/limadev/restic-password"
AWS_ACCESS_KEY_ID="B2_APPLICATION_KEY_ID"
AWS_SECRET_ACCESS_KEY="B2_APPLICATION_KEY"
AWS_DEFAULT_REGION="us-west-002"
KEEP_DAILY="7"
KEEP_WEEKLY="4"
KEEP_MONTHLY="6"
TELEGRAM_BOT_TOKEN="token"
TELEGRAM_CHAT_ID="chat_id"
```

## Instalar Stack de Backup

No host, a partir do repo:

```bash
sudo bash srvrs-limadev/continuidade-operacional/scripts/install_backup_stack.sh
```

Criar jobs em `/etc/limadev/jobs/*.env`.

Exemplo:

```bash
sudo cp srvrs-limadev/continuidade-operacional/config/jobs/examples/vps-assist-db.env.example \
  /etc/limadev/jobs/vps-assist-db.env
sudo nano /etc/limadev/jobs/vps-assist-db.env
```

Para o job `vps-assist-system`, copiar tambem o exclude recomendado:

```bash
sudo cp srvrs-limadev/continuidade-operacional/config/excludes/vps-assist-system.txt.example \
  /etc/limadev/excludes/vps-assist-system.txt
sudo chmod 600 /etc/limadev/excludes/vps-assist-system.txt
```

## Executar Primeiro Backup

```bash
sudo systemctl start limadev-backup@vps-assist-db.service
sudo journalctl -u limadev-backup@vps-assist-db.service -n 100 --no-pager
```

Validar snapshots:

```bash
sudo set -a
sudo . /etc/limadev/backup.env
sudo set +a
sudo restic snapshots --host vps-assist --tag class:db
```

## Ativar Agendamento

```bash
sudo systemctl enable --now limadev-backup@vps-assist-db.timer
sudo systemctl enable --now limadev-backup-drill@vps-assist-db.timer
```

## Executar Drill de Restore

```bash
sudo systemctl start limadev-backup-drill@vps-assist-db.service
sudo journalctl -u limadev-backup-drill@vps-assist-db.service -n 100 --no-pager
```

Ver evidencia:

```bash
sudo ls -lh /var/log/limadev-backup
```

## Configurar Heartbeat Diario

Criar `/etc/limadev/heartbeat.env`:

```env
HEARTBEAT_EXPECTED_HOSTS="vps-assist vps-prod vps-dev mini-pc note-limdev"
HEARTBEAT_STORE_DIR="/var/lib/limadev-heartbeats"
HEARTBEAT_LOG_DIR="/var/log/limadev-heartbeat"
HEARTBEAT_INGEST_SSH_TARGET="limadev-report@vps-assist"
HEARTBEAT_INGEST_COMMAND="limadev-heartbeat-ingest"
HEARTBEAT_DISK_WARN_PCT="80"
HEARTBEAT_DISK_FAIL_PCT="90"
HEARTBEAT_USE_HERMES="1"
HEARTBEAT_TELEGRAM_ENABLED="1"
```

No `vps-assist`, criar usuario restrito para receber reports:

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin limadev-report
sudo install -m 700 -o limadev-report -g limadev-report -d /home/limadev-report/.ssh
```

No `authorized_keys`, usar chave publica dos hosts com comando restrito:

```text
command="/usr/local/bin/limadev-heartbeat-ingest",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA... host
```

## Testar Heartbeat Manualmente

No host:

```bash
sudo limadev-heartbeat-report.sh | jq .
```

Enviar para o `vps-assist`:

```bash
sudo limadev-heartbeat-report.sh | ssh limadev-report@vps-assist limadev-heartbeat-ingest
```

No `vps-assist`:

```bash
sudo find /var/lib/limadev-heartbeats -type f | sort
sudo limadev-heartbeat-daily-summary.sh
sudo ls -lh /var/log/limadev-heartbeat
```

## Backup do Arquivo de Credenciais no Note

Manter copia local privada:

```bash
chmod 600 srvrs-limadev/continuidade-operacional/secure/limadev-backup-credentials.env
```

Opcionalmente criar copia criptografada:

```bash
gpg -c --cipher-algo AES256 srvrs-limadev/continuidade-operacional/secure/limadev-backup-credentials.env
```

## Backup do Arquivo no Google Drive

Enviar somente:

```text
limadev-backup-credentials.env.gpg
```

Nao enviar:

```text
limadev-backup-credentials.env
```

## Recuperacao em Perda Total

1. Provisionar host limpo.
2. Instalar Restic.
3. Restaurar ou recriar `/etc/limadev/backup.env`.
4. Restaurar `/etc/limadev/restic-password`.
5. Rodar:

```bash
sudo set -a
sudo . /etc/limadev/backup.env
sudo set +a
sudo restic snapshots --host <host>
```

6. Restaurar primeiro `system_config`, depois `db`, depois `app_data`.
7. Subir servicos.
8. Validar healthchecks.
9. Reativar timers.

## Checklist Diario

- Telegram recebeu resumo diario.
- Todos os hosts esperados reportaram.
- Nenhum backup critico aparece como falho.
- Nenhum host critico esta com disco acima do limite.
- Drill semanal dos criticos esta recente.

## Checklist Mensal

- Executar drill manual de restore em host critico.
- Validar arquivo de credenciais criptografado.
- Confirmar que a senha Restic abre o repositorio.
- Revisar chaves B2 e permissao de menor privilegio.
- Revisar chaves SSH restritas do heartbeat.
