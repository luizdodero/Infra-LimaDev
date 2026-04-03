# acesso_assistente_edge

## Objetivo
Padronizar como os clientes internos acessam o assistente IA edge no VPS 1 via backbone privado.

## Status atual

- Openclaw ativado em modo de rede privado (tailnet only).
- Sem `funnel` (nao ha exposicao publica).
- Gateway em loopback no VPS 1 (`127.0.0.1:18789`) com publicacao TCP pela tailnet.
- Control UI requer contexto seguro: usar HTTPS via `tailscale serve` ou acessar localmente no VPS 1.

## Contrato minimo de acesso

- Origem permitida: nos da malha Tailscale.
- Destino: VPS 1 (assistente edge).
- Transporte:
  - Gateway Openclaw: `WS/WSS` (porta `18789`).
  - APIs HTTP auxiliares (quando expostas): `HTTP/HTTPS`.
- Porta padrao do assistente (Openclaw): `18789`.
- Endpoint de healthcheck: `/health` (sugestao).
- Endpoint de inferencia: definir no projeto do assistente edge.
- Autenticacao: token por header (sugestao).

## Variaveis padrao sugeridas

- `ASSISTANT_EDGE_BASE_URL`
- `ASSISTANT_EDGE_HEALTH_PATH`
- `ASSISTANT_EDGE_PORT` (`18789`)
- `ASSISTANT_EDGE_CHECK_MODE` (`http` ou `tcp`)
- `ASSISTANT_EDGE_AUTH_HEADER`
- `ASSISTANT_EDGE_TIMEOUT_SECONDS`

## Testes basicos

Healthcheck:
`curl -k -sS -o /dev/null -w "%{http_code}\n" "${ASSISTANT_EDGE_BASE_URL}:${ASSISTANT_EDGE_PORT}${ASSISTANT_EDGE_HEALTH_PATH}"`

Teste autenticado (exemplo):
`curl -k -sS -X POST "${ASSISTANT_EDGE_BASE_URL}:${ASSISTANT_EDGE_PORT}/infer" -H "${ASSISTANT_EDGE_AUTH_HEADER}" -H "Content-Type: application/json" -d '{"input":"ping"}'`

Teste TCP (gateway WS):
`nc -z -w 5 <host> 18789`

## Control UI (contexto seguro)

Preferencial (tailnet HTTPS):
`https://vps-assist.tailed51fe.ts.net:18790/`

Alternativa (local no VPS 1):
`http://127.0.0.1:18789/`

Se for manter HTTP remoto (nao recomendado):
`gateway.controlUi.allowInsecureAuth: true` (token-only).

## Ativacao na Tailnet (quando sair da implantacao)

Modo recomendado do Openclaw:
- `gateway.tailscale.mode = off`
- `gateway.bind = loopback`

Publicacao (tailnet only):
`tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`

HTTPS para Control UI (recomendado):
`tailscale serve --bg --https 18790 http://127.0.0.1:18789`

Ver status:
`tailscale serve status`

Desativar novamente:
`tailscale serve --tcp=18789 off`

Nao usar:
- `tailscale funnel` (exposicao publica, desnecessaria neste setup).

## Regras de rede

- Liberar apenas o necessario no `tailscale0`.
- Bloquear exposicao publica desnecessaria do endpoint edge.
- Se usar `tailscale serve --tcp` para `127.0.0.1:18789`, liberar loopback na porta (iptables/ufw) para evitar timeout local do proxy.
- Registrar alteracoes de rota/firewall em `01_infra_backbone/evidencias/`.
