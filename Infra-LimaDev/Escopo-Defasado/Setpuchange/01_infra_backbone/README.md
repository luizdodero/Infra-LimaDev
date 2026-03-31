# 01_infra_backbone

## Objetivo
Garantir backbone estavel entre os 5 nos (Tailscale + SSH + HTTPS), incluindo acesso confiavel ao assistente IA edge hospedado no VPS 1 e acesso operacional ao `mini-pc`.

## Pastas

- `tailscale`: configuracao, ACLs e troubleshooting da malha privada.
- `ssh`: tunelamento, portas, hardening e acesso remoto.
- `ufw`: regras de firewall por no.
- `scripts`: diagnosticos e automacoes especificas do backbone.
- `acesso_assistente_edge`: endpoints, DNS, rotas e validacoes de disponibilidade do assistente.
- `checklists`: validacoes operacionais e runbooks.
- `evidencias`: outputs de teste, logs e capturas.
- `vpn_reforcopro`: conexao VPN do `note-limdev` para a rede do Grupo ReforcePro (177.105.240.90, usuario luiz.dodero).

## Checklist inicial

- [ ] Validar ping e resolucao MagicDNS entre todos os nos.
- [ ] Confirmar SSH na porta `22022` em todos os hosts previstos.
- [ ] Confirmar HTTPS (`443`) para servicos publicados.
- [ ] Ajustar UFW para trafego `tailscale0` sem bloquear comunicacao necessaria.
- [ ] Definir rota de acesso ao assistente edge no VPS 1 (host, porta `18789`, autenticacao).
- [x] Concluir bootstrap do `mini-pc` (primeiro acesso por senha, instalacao de chave e padronizacao para `22022`).
- [ ] Registrar comandos e resultados em `evidencias/`.
- [ ] Configurar VPN ReforcePro: inserir senha em `vpn_reforcopro/credenciais.conf` e instalar dependencias PPTP/L2TP.

## Inicio rapido

1. Preencher `checklists/hosts.csv` com os hosts reais (use `checklists/hosts.example.csv` como base).
   O script aceita linhas com `,` ou `;` (inclusive layout `nome;host;ipv4;ipv6;`).
   Para hosts ainda em bootstrap SSH, manter `check_ssh=0` e registrar IPs no `checklists/hosts_inventory.csv`.
2. Definir a verificacao do assistente edge (porta padrao Openclaw `18789`):
   - HTTP healthcheck: `export ASSISTANT_EDGE_URL="https://<host>:18789/health"`
   - Gateway WS (Openclaw): `export ASSISTANT_EDGE_CHECK_MODE=tcp && export ASSISTANT_EDGE_HOST="<host>"`
   Se o Openclaw ainda estiver em implantacao, deixe variaveis `ASSISTANT_EDGE_*` sem definir (checagem fica `SKIP`).
   Em operacao, usar publicacao tailnet via `tailscale serve --tcp` e manter `funnel` desativado.
   Para diagnostico dedicado do `vps-assist` apos update ou queda do Openclaw:
   `bash 01_infra_backbone/scripts/diagnose_vps_assist_openclaw.sh`
3. Rodar a validacao:
   `bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv`.
4. Salvar evidencia:
   `bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv | tee 01_infra_backbone/evidencias/backbone_$(date +%F_%H%M).log`.

## Alocacao atual dos nos locais

- `note-limdev`: interface de trabalho, VS Code Remote, acesso aos demais equipamentos e operacao manual.
- `mini-pc`: alvo primario para testes de desenvolvimento mais pesados da solucao de portaria inteligente, com SSH padronizado na porta `22022`.
