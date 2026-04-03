# Relatório de Segurança — Infraestrutura LimaDev
**Data:** 01/04/2026  
**Gerado por:** Varredura manual + Claude Code  
**Escopo:** mini-pc, vps-assist, vps-dev, vps-prod

---

## 1. Contexto

Varredura iniciada em 31/03/2026 às ~21h após comportamento anômalo relatado no **vps-dev**. A investigação revelou ataques de força bruta SSH ativos em **todas as VPS**, além de portas críticas expostas publicamente sem proteção adequada.

---

## 2. Situação por Máquina

### 2.1 mini-pc
| Item | Status |
|---|---|
| IP | 100.87.104.42 (Tailscale) |
| Uptime | 24 dias |
| Carga/Memória/Disco | Normal (load 0.68, 4.1GB/15GB RAM, 11% disco) |
| Falhas SSH | 0 |
| UFW | Não instalado |
| Exposição | Sem portas públicas detectadas |

**Avaliação:** Sem incidentes. Máquina local, sem exposição pública relevante.

---

### 2.2 vps-dev — `129.121.36.133` (IP público anterior)
| Item | Situação encontrada |
|---|---|
| Uptime no momento | 3 min (reboot manual pelo operador) |
| Carga/Memória/Disco | Normal |
| **Falhas SSH** | **5.793 tentativas no dia** |
| Autenticação por senha | Habilitada |
| Fail2ban | Ativo mas com parâmetros fracos (bantime 2h, maxretry 5) |
| IPs banidos | 5 |
| Portas públicas | 22022 (SSH), 80, 443 |
| PostgreSQL exposto | Não |
| Serviços | Flask (8080), Node.js/PM2 (3000), Nginx, Tailscale |

**Origens do ataque:**
| IP | Tentativas | Origem geográfica |
|---|---|---|
| 176.120.22.13 | 779 | Brasil |
| 176.120.22.17 | 668 | Brasil |
| 176.120.22.47 | 543 | Brasil |
| 91.202.233.33 | 519 | Rússia |
| 87.251.64.141 | 189 | Rússia |

---

### 2.3 vps-assist — `129.121.34.171` (IP público anterior)
| Item | Situação encontrada |
|---|---|
| Uptime no momento | 2 dias, 17h |
| Carga/Memória/Disco | Normal |
| **Falhas SSH** | **3.623 tentativas no dia** |
| Autenticação por senha | Habilitada |
| Fail2ban | **Não instalado** |
| Portas públicas | 22022 (SSH) |
| Serviços | OpenClaw (18789 via Tailscale) |

**Origens do ataque:**
| IP | Tentativas | Origem geográfica |
|---|---|---|
| 87.251.64.141 | 314 | Rússia |
| 144.79.187.31 | 41 | Alemanha |
| 20.116.34.103 | 40 | EUA (Azure) |
| 23.91.97.250 | 38 | EUA |
| 165.154.6.150 | 38 | China |

---

### 2.4 vps-prod — `69.6.251.24` (IP público anterior)
| Item | Situação encontrada |
|---|---|
| Uptime no momento | 6 dias, 16h |
| Carga/Memória/Disco | Normal |
| **Falhas SSH** | **8.109 tentativas no dia** |
| Autenticação por senha | Habilitada |
| Fail2ban | **Não instalado** |
| **PostgreSQL 5432 exposto** | **SIM — risco crítico** |
| **API 8000 exposta** | **SIM** |
| Portas públicas | 22022, 80, 443, 3000, 5432, 8000, 51820/51821 (VPN) |
| Containers Docker | voxgate (edge, frontend, backend, vpn, openvpn, db), picfound (api, db) |

**Origens do ataque:**
| IP | Tentativas | Origem geográfica |
|---|---|---|
| 176.120.22.13 | 1.167 | Brasil |
| 176.120.22.17 | 1.158 | Brasil |
| 176.120.22.47 | 791 | Brasil |
| 91.202.233.33 | 752 | Rússia |
| 87.251.64.141 | 309 | Rússia |

> Os IPs `176.120.22.x` e `91.202.233.33` aparecem de forma coordenada em **vps-dev e vps-prod simultaneamente**, sugerindo campanha de varredura automatizada direcionada à faixa de IPs da Hostgator.

---

## 3. Tipo de Ataque

**Brute Force SSH (Credential Stuffing / Dictionary Attack)**

- Tentativas sistemáticas de login via SSH na porta 22022
- Alvos primários: usuário `root` e variações comuns (`admin`, `ems`, `emy`, etc.)
- Padrão automatizado — múltiplas tentativas por segundo por IP
- Múltiplos IPs atuando em paralelo sobre os mesmos servidores (botnet distribuída)
- Sem evidência de acesso bem-sucedido em nenhuma das máquinas

**Exposição adicional (vps-prod):**
- PostgreSQL `0.0.0.0:5432` acessível da internet — risco de ataques diretos ao banco (CVE exploits, força bruta de credenciais Postgres)
- API `0.0.0.0:8000` sem camada de proteção (sem autenticação de rede)

---

## 4. Ações Executadas

### SSH — todas as VPS
| Ação | Detalhe |
|---|---|
| `PasswordAuthentication no` | Login por senha desabilitado em vps-dev, vps-assist, vps-prod |
| `MaxAuthTries 3` | Reduzido de 6 para 3 tentativas por conexão |
| Acesso restrito ao Tailscale | Porta 22022 fechada ao público, liberada apenas via interface `tailscale0` |

### Fail2ban — todas as VPS
| Parâmetro | Antes | Depois |
|---|---|---|
| `bantime` | 2h (vps-dev) / não instalado | **24h** |
| `findtime` | 10 min | **5 min** |
| `maxretry` | 5 | **3** |
| Status vps-assist | Não instalado | **Instalado e ativo** |
| Status vps-prod | Não instalado | **Instalado e ativo** |

### Firewall UFW — todas as VPS
| Máquina | Antes | Depois |
|---|---|---|
| vps-dev | 22022, 80, 443 públicos | Apenas Tailscale (22022, 80, 443) |
| vps-assist | 22022 público | Apenas Tailscale (22022) |
| vps-prod | 22022, 80, 443, 3000, 5432, 8000 públicos | 22022 → Tailscale only; 80/443/VPN mantidos públicos |

### Docker / iptables — vps-prod
- Regras inseridas na chain `DOCKER-USER` (Docker bypassa UFW):
  - `DROP tcp --dport 5432` — PostgreSQL bloqueado da internet
  - `DROP tcp --dport 8000` — API picfound bloqueada da internet
  - `RETURN` para range Tailscale `100.64.0.0/10` (acesso interno mantido)
- Persistência configurada via `iptables-restore.service` no systemd

### SSH config local (`~/.ssh/config`)
- IPs públicos substituídos pelos IPs Tailscale em todas as entradas:
  - `vps-dev` → `100.120.55.28`
  - `vps-assist` → `100.118.212.123`
  - `vps-prod` → `100.118.12.49`
- Flags legadas `HostKeyAlgorithms +ssh-rsa` removidas

---

## 5. Status Final

| Máquina | SSH público | Senha SSH | Fail2ban | Portas críticas expostas |
|---|---|---|---|---|
| mini-pc | N/A | N/A | N/A | Nenhuma |
| vps-dev | Fechado | Desabilitada | Ativo (24h) | Nenhuma |
| vps-assist | Fechado | Desabilitada | Ativo (24h) | Nenhuma |
| vps-prod | Fechado | Desabilitada | Ativo (24h) | Nenhuma |

**Todas as máquinas acessíveis exclusivamente via Tailscale.**  
Sem evidência de comprometimento ou acesso não autorizado bem-sucedido.

---

## 6. Recomendações Pendentes

- [ ] **vps-prod:** Remover mapeamento `0.0.0.0:5432` e `0.0.0.0:8000` dos `docker-compose.yml` (PicFound e Voxgate) — usar `127.0.0.1:5432` para evitar dependência das regras iptables
- [ ] **vps-prod:** Senha padrão `admin` no PostgreSQL do Voxgate (`POSTGRES_PASSWORD: admin`) — alterar imediatamente
- [ ] **vps-assist:** Confirmar qual UFW rule `22022/tcp (v6) on tailscale0` cobre acesso IPv4 também — adicionar regra IPv4 explícita se necessário
- [ ] **Todas as VPS:** Considerar instalar `iptables-persistent` (pacote oficial) em substituição ao serviço customizado de restore
- [ ] **mini-pc:** Avaliar instalar UFW para padronizar gestão de firewall

---

*Relatório gerado em 01/04/2026 — LimaDev / Claude Code*
