# Plano de Adequação — vps-dev
**Data:** 2026-03-30  
**Status:** Em execução  
**Máquina:** vps-dev (129.121.36.133:22022)

---

## Contexto

A vps-dev é máquina dedicada a hospedar código de sistemas em andamento, integrada ao GitHub.  
Este plano consolida a sessão de diagnóstico de 30/03/2026 e define todas as ações de limpeza, segurança e exposição controlada de serviços.

---

## O que já foi feito (concluído)

| # | Ação | Resultado |
|---|------|-----------|
| 1 | Parar e remover stack portaria-ia-mvp (Asterisk, LiveKit, SIP, Redis, Speaches) | ✅ Concluído |
| 2 | Parar e remover stack voxgate-core (API + Postgres) | ✅ Concluído |
| 3 | Remover volumes Docker dos stacks (speaches-models 640MB, postgres 47MB) | ✅ Concluído |
| 4 | Remover todas as imagens Docker dos projetos extintos (~6.5 GB liberados) | ✅ Concluído |
| 5 | Remover build cache Docker (1.7 GB liberados) | ✅ Concluído |
| 6 | Remover Ansible 2.9.27 global quebrado | ✅ Concluído |
| 7 | Instalar e ativar Fail2ban | ✅ Concluído |
| 8 | UFW ativo com deny incoming, allow 22022/80/443 | ✅ Concluído |
| 9 | Persistir onboarding-form via PM2 no boot (`pm2-root`) | ✅ Concluído |
| 10 | Migrar `server.py` para systemd (`infra-entrada`) como `opsbot` | ✅ Concluído |
| 11 | Instalar `certbot`, plugin nginx e `apache2-utils` | ✅ Concluído |
| 12 | Criar `Basic Auth` em `/etc/nginx/.htpasswd-reforce` | ✅ Concluído |
| 13 | Criar e ativar vhosts nginx para `infra.reforce.pro.br` e `onb-mkt.reforce.pro.br` | ✅ Concluído |

**Ganho de swap:** 3.6 GB → 177 MB em uso  
**Ganho de disco:** ~8.5 GB liberados  
**Causa raiz do OOM confirmada:** serviços fora de contexto (portaria + voxgate) consumindo RAM/swap. Removidos. Upgrade de hardware não necessário.

---

## O que permanece e está correto

| Serviço | Porta | Motivo |
|---------|-------|--------|
| SSH (sshd) | 22022 | Acesso operacional |
| Nginx | 443 | Proxy reverso HTTPS |
| Tailscale | — | VPN privada |
| Fail2ban | — | Proteção SSH |
| Docker engine | — | Runtime para projetos (sob demanda) |
| UFW | — | Firewall perimetral |
| PM2 + onboarding-form | 3000 localhost | Projeto AutoMarkVendas (entrada de dados) |
| python server.py | 8080 localhost | Projeto infra-refpro (entrada de dados infra) |

---

## Fase 1 — concluída

### P1.1 — PM2: persistência do onboarding-form
Status: ✅ Concluído  
Implementado com `pm2 save` e serviço `pm2-root` habilitado no boot.

### P1.2 — python server.py: migração para systemd
Status: ✅ Concluído  
Implementado com unit `/etc/systemd/system/infra-entrada.service`, executando como `opsbot` e com restart automático (`Restart=on-failure`).

---

## Fase 2 — parcialmente concluída (aguardando DNS para SSL publico)

**Pré-requisito:** subdomínios criados no DNS público:
- `infra.reforce.pro.br` → A record → 129.121.36.133
- `onb-mkt.reforce.pro.br` → A record → 129.121.36.133

### Nota sobre SSL ⚠️
O certificado self-signed atual é válido para `vps-dev.tailed51fe.ts.net`.  
Para domínios públicos (`*.reforce.pro.br`), o self-signed causa aviso de segurança no browser.  
**Recomendação:** usar Let's Encrypt via certbot (gratuito, renovação automática).

```bash
apt install certbot python3-certbot-nginx -y
certbot --nginx -d infra.reforce.pro.br -d onb-mkt.reforce.pro.br
```

O plano abaixo já está estruturado para Let's Encrypt, mas pode ser executado com self-signed também.

### P2.1 — Criar arquivo de senhas (basic auth)
Status: ✅ Concluído  
Arquivo criado em `/etc/nginx/.htpasswd-reforce`.

```bash
apt install apache2-utils -y
htpasswd -c /etc/nginx/.htpasswd <usuario>
# adicionar mais usuários se necessário:
# htpasswd /etc/nginx/.htpasswd <outro_usuario>
chmod 640 /etc/nginx/.htpasswd
chown root:www-data /etc/nginx/.htpasswd
```

### P2.2 — Criar vhost: infra.reforce.pro.br → :8080
Status: ✅ Concluído com certificado temporário (`/etc/nginx/ssl/vps-dev-selfsigned.crt`).  
Pendente apenas substituição automática pelo Let's Encrypt após propagação DNS.

Arquivo: `/etc/nginx/sites-available/infra-reforce.conf`

```nginx
server {
    listen 80;
    server_name infra.reforce.pro.br;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name infra.reforce.pro.br;

    ssl_certificate     /etc/letsencrypt/live/infra.reforce.pro.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/infra.reforce.pro.br/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    auth_basic           "Acesso Restrito";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

### P2.3 — Criar vhost: onb-mkt.reforce.pro.br → :3000
Status: ✅ Concluído com certificado temporário (`/etc/nginx/ssl/vps-dev-selfsigned.crt`).  
Pendente apenas substituição automática pelo Let's Encrypt após propagação DNS.

Arquivo: `/etc/nginx/sites-available/onb-mkt-reforce.conf`

```nginx
server {
    listen 80;
    server_name onb-mkt.reforce.pro.br;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name onb-mkt.reforce.pro.br;

    ssl_certificate     /etc/letsencrypt/live/onb-mkt.reforce.pro.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/onb-mkt.reforce.pro.br/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    auth_basic           "Acesso Restrito";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

### P2.4 — Ativar vhosts e recarregar nginx
Status: ✅ Concluído  

```bash
ln -s /etc/nginx/sites-available/infra-reforce.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/onb-mkt-reforce.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### P2.5 — Adicionar porta 80 ao UFW (para redirect e certbot challenge)
A porta 80 já está aberta no UFW (usada pelo certbot no challenge HTTP-01).

---

## Pendências — fase 3: verificação final pós-implantação

- [x] `curl -u user:pass https://infra.reforce.pro.br` retorna 200 (validado localmente com `--resolve`)
- [x] `curl -u user:pass https://onb-mkt.reforce.pro.br` retorna 200 (validado localmente com `--resolve`)
- [x] Acesso sem credenciais retorna 401
- [x] `free -h` mostra swap < 500 MB após estabilizar
- [x] `systemctl status infra-entrada` mostra `active (running)`
- [x] `ps aux | grep -E 'livekit|asterisk|redis-server'` retorna vazio
- [ ] Let's Encrypt configurado: `certbot renew --dry-run` sem erros

---

## Nada mais a remover

Após varredura completa:
- Diretórios de código (VoxGate, Portaria, etc.) são repositórios git — corretos na vps-dev
- `/home/opsbot/projetos/asterisk` é repositório de configuração (7.5 MB) — não executa nada
- Cron do opensquad (09:00 diário) — operação normal de sync
- Todos os timers systemd são do sistema operacional — corretos

---

## Topologia final esperada

```
Internet
   │
   ├─ :22022  SSH ──────────────────────────────── sshd (Fail2ban + UFW)
   │
   ├─ :80     HTTP ─── nginx ──── redirect 301 ──► :443
   │
   └─ :443    HTTPS ── nginx ─┬─ infra.reforce.pro.br    ──► 127.0.0.1:8080 (python/infra-refpro)
                               └─ onb-mkt.reforce.pro.br  ──► 127.0.0.1:3000 (node/onboarding-form)

Tailscale (100.x)
   └─ vps-dev.tailed51fe.ts.net:443 ── nginx ── health check
```
