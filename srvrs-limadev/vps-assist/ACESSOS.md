# Acessos - vps-assist

## Status: Paperclip + Hermes Ativo

Servidor com Paperclip rodando via systemd + Postgres em Docker.

---

## SSH

| Acesso | Valor |
|--------|-------|
| Host | `vps-assist.tailed51fe.ts.net` |
| User | `root` |
| Port | `22022` |
| Key | `srvrs-limadev/.ssh/id_openclaw_deploy` |

### SSH Config (`~/.ssh/config`)
```
Host vps-assist
    HostName vps-assist.tailed51fe.ts.net
    User root
    Port 22022
    IdentityFile /caminho/para/id_openclaw_deploy
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Comandos SSH
```bash
# Conectar
ssh -i srvrs-limadev/.ssh/id_openclaw_deploy -p 22022 root@vps-assist.tailed51fe.ts.net
```

---

## Paperclip

| Acesso | URL |
|--------|-----|
| Via Caddy (Tailscale) | `http://100.118.212.123` |
| Direto (localhost only) | `http://127.0.0.1:3100` |
| Health Check | `http://127.0.0.1:3100/api/health` |

> **Nota**: Porta 3100 bloqueada externamente pelo UFW. Acesso apenas via Caddy (porta 80) ou localhost.

### Gerenciamento
```bash
systemctl status paperclip
systemctl restart paperclip
systemctl stop paperclip
journalctl -u paperclip -f
```

---

## PostgreSQL

| Acesso | Valor |
|--------|-------|
| Container | `paperclip-pg` |
| Imagem | postgres:16 |
| Porta (host) | 54329 |
| Porta (container) | 5432 |

```bash
docker ps
docker logs paperclip-pg
docker restart paperclip-pg
docker exec -it paperclip-pg psql -U paperclip
```

---

## Hermes Agent

| Acesso | Caminho |
|--------|---------|
| Binário | `/root/.local/bin/hermes` |
| Config | `/root/.hermes/config.yaml` |
| Sessions | `/root/.hermes/sessions/` |
| Skills | `/root/.hermes/skills/` |
| Logs | `/root/.hermes/logs/` |
| .env | `/root/.hermes/.env` |

```bash
hermes chat
hermes chat -q "pergunta"
hermes status
hermes doctor
hermes model
hermes sessions list
hermes skills list
```

---

## Caddy (Reverse Proxy)

| Arquivo | Caminho |
|---------|---------|
| Caddyfile | `/etc/caddy/Caddyfile` |
| Logs | `journalctl -u caddy -f` |
| Porta | 80 |

```bash
systemctl status caddy
systemctl restart caddy
```

---

## Tailscale

| Info | Valor |
|------|-------|
| MagicDNS | `vps-assist.tailed51fe.ts.net` |
| IP Tailscale | `100.118.212.123` |
| Status | `tailscale status` |

---

## UFW (Firewall)

| # | Porta | Ação | Descrição |
|---|-------|------|-----------|
| 1 | 41641/udp | ALLOW | Tailscale direct/DERP |
| 2 | tailscale0 | ALLOW | Todo tráfego Tailscale |
| 3 | 3100/tcp | **DENY** | Paperclip (bloqueado externamente) |
| 4 | 22022/tcp (v6) | ALLOW | SSH via Tailscale |
| 5 | 41641/udp (v6) | ALLOW | Tailscale direct/DERP |
| 6 | tailscale0 (v6) | ALLOW | Todo tráfego Tailscale |
| 7 | 3100/tcp (v6) | **DENY** | Paperclip (bloqueado externamente) |

```bash
ufw status numbered
```

---

## Serviços Ativos

```bash
systemctl status ssh
systemctl status tailscaled
systemctl status fail2ban
systemctl status caddy
systemctl status ufw
systemctl status paperclip
systemctl status docker
```

---

## Continuidade Operacional (vps-assist)

| Item | Valor |
|------|-------|
| Guia operacional | `srvrs-limadev/vps-assist/CONTINUIDADE_OPERACIONAL.md` |
| Módulo central | `srvrs-limadev/continuidade-operacional/README.md` |
| Credenciais do backend no host | `/etc/limadev/backup.env` |

Campos principais para backend S3 compativel:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD_FILE`

---

## Disk Usage

| Diretório | Tamanho |
|-----------|---------|
| /swapfile1 | 4.0GB |
| /usr | 3.6GB |
| /var | 2.0GB |
| /root/.vscode-server | 1.5GB |
| /boot | 259MB |
| /etc | 7MB |
| /snap | 20KB |
| /opt | 12KB |
| **Total** | **16GB/99GB (16%)** |
