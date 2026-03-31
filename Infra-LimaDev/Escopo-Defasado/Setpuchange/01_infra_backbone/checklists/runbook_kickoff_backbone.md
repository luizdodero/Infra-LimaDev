# Runbook de Kickoff - Backbone

Objetivo: validar conectividade minima entre os 5 nos e acesso ao assistente edge no VPS 1.

## 1) Preparar inventario de hosts

1. Copiar o arquivo de exemplo:
   `cp 01_infra_backbone/checklists/hosts.example.csv 01_infra_backbone/checklists/hosts.csv`
2. Substituir os hosts ficticios pelos hosts reais (MagicDNS/FQDN/IP Tailscale).
   Se quiser manter inventario estendido (DNS/IP), use `checklists/hosts_inventory.csv`.

Formato:
`nome,host,check_ssh,check_https`

Formatos tambem aceitos:
`nome;host;check_ssh;check_https`
`nome;host;ipv4;ipv6;`

- `check_ssh`: `1` para validar porta `22022`, `0` para ignorar.
- `check_https`: `1` para validar HTTPS `443`, `0` para ignorar.
- Se as colunas 3/4 nao forem `0` ou `1` (ex.: `ipv4;ipv6`), o script assume ambos como `1`.
- Para host ainda em bootstrap (ex.: `mini-pc` no primeiro acesso por senha), manter `check_ssh=0` ate concluir a instalacao da chave e a mudanca para `22022`.

## 2) Preparar endpoint do assistente edge

Quando o endpoint estiver definido:
`export ASSISTANT_EDGE_URL="https://<host-ou-dns>:18789/health"`

Porta padrao do assistente (Openclaw): `18789`.

Para gateway Openclaw em WebSocket (sem endpoint HTTP de health):
`export ASSISTANT_EDGE_CHECK_MODE=tcp`
`export ASSISTANT_EDGE_HOST="<host-ou-dns>"`

Se o gateway estiver em loopback no VPS 1:
`tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`

Se o Openclaw estiver em implantacao:
- nao configurar `ASSISTANT_EDGE_*` nesta rodada
- manter `tailscale serve` desativado para `18789`

Em producao interna:
- manter `gateway.tailscale.mode = off` no Openclaw
- usar apenas `tailscale serve --tcp` (sem funnel)

Se o endpoint exigir token:
`export ASSISTANT_EDGE_AUTH_HEADER="Authorization: Bearer <token>"`

## 3) Rodar validacao

Comando base:
`bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv`

Salvar log da rodada:
`bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv | tee 01_infra_backbone/evidencias/backbone_$(date +%F_%H%M).log`

## 4) Critério de aceite da rodada

- Todos os nos com SSH `22022` em `OK` (quando habilitado no CSV).
- Todos os nos com HTTPS `443` em `OK` (quando habilitado no CSV).
- Endpoint do assistente edge em `OK` (HTTP status diferente de `000`).
- Nenhum bloqueio indevido em `tailscale0` no UFW.

## 5) Registrar evidencia

Preencher:
`01_infra_backbone/evidencias/template_validacao_backbone.md`
