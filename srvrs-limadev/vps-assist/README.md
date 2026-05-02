# vps-assist - LimaDev Infrastructure

## Status: Paperclip + Hermes (Systemd + Docker)

Servidor com deploy ativo do Paperclip via systemd + Postgres em Docker.

## Serviços Ativos

| Serviço | Status | Porta | Detalhes |
|---------|--------|-------|----------|
| SSH | active | 22022 | Tailscale |
| Tailscale | active | VPN | MagicDNS |
| Fail2ban | active | - | jail SSH |
| Caddy | active | 80 | Reverse proxy → Paperclip |
| UFW | active | - | Firewall |
| Docker | active | - | Postgres container |
| Paperclip | active | 3100 | systemd (paperclip.service) |

## Paperclip

- **Versão**: 0.3.1
- **Modo**: `local_trusted` (sem autenticação)
- **Porta**: 3100 (localhost) + Caddy proxy porta 80
- **Serviço**: `systemctl status paperclip.service`
- **Node.js**: `/root/.hermes/node/bin/node` (não instalado no sistema)
- **pnpm**: 9.15.4
- **Health**: `curl http://127.0.0.1:3100/api/health`

## PostgreSQL

- **Container**: `paperclip-pg` (postgres:16)
- **Porta**: 54329 (mapeada para host)
- **Volume**: Docker volume

## Hermes Agent

- **Localização**: `/root/.hermes/`
- **Binário**: `/root/.local/bin/hermes` (symlink)
- **Config**: `/root/.hermes/config.yaml`
- **Sessions**: `/root/.hermes/sessions/`
- **Skills**: `/root/.hermes/skills/`
- **Logs**: `/root/.hermes/logs/`

## Estrutura /root/

| Diretório | Descrição |
|-----------|-----------|
| `.hermes/` | Hermes Agent (node, venv, skills, sessions) |
| `.paperclip/` | Paperclip instances |
| `.claude/` | Claude Code config |
| `.codex/` | Codex state |
| `.npm/` | Cache npm (limpo) |
| `.cache/` | Cache geral (limpo) |
| `.local/bin/` | uv, uvx, hermes, node, npm, npx symlinks |
| `.vscode-server/` | VS Code Remote |

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
| /opt | 12KB (google) |
| **Total** | **16GB/99GB (16%)** |

## Acesso

- **Paperclip UI**: `http://100.118.212.123` (via Caddy)
- **Paperclip direto**: `http://100.118.212.123:3100` (localhost only, DENY no UFW)
- **SSH**: `ssh -p 22022 root@vps-assist.tailed51fe.ts.net` (Tailscale)
- **Tailscale IP**: `100.118.212.123`

## UFW Rules

```
[1] 41641/udp          - Tailscale direct/DERP
[2] tailscale0         - Allow trusted tailnet traffic
[3] 3100/tcp           - DENY (Paperclip bloqueado externamente)
[4] 22022/tcp (v6)     - SSH via Tailscale
[5] 41641/udp (v6)     - Tailscale direct/DERP
[6] tailscale0 (v6)    - Allow trusted tailnet traffic
[7] 3100/tcp (v6)      - DENY
```

## Gerenciamento

```bash
# Paperclip
systemctl status paperclip
systemctl restart paperclip
systemctl stop paperclip

# Postgres
docker ps
docker logs paperclip-pg
docker restart paperclip-pg

# Caddy
systemctl status caddy
systemctl restart caddy

# Ver logs
journalctl -u paperclip -f
docker logs -f paperclip-pg
```

## Histórico

- **2026-04-09**: Deploy Paperclip + Hermes (Docker) → removido
- **2026-04-09**: Limpeza completa (Docker, OpenClaw, Chrome, cache)
- **2026-04-10**: Novo deploy Paperclip via systemd + Postgres Docker

## Continuidade Operacional

- Guia operacional do host: [CONTINUIDADE_OPERACIONAL.md](./CONTINUIDADE_OPERACIONAL.md)
- Modulo central de backup: [../continuidade-operacional/README.md](../continuidade-operacional/README.md)
- Arquivo local de credenciais no host: `/etc/limadev/backup.env`

---

Veja [ACESSOS.md](./ACESSOS.md) para detalhes de acesso.
