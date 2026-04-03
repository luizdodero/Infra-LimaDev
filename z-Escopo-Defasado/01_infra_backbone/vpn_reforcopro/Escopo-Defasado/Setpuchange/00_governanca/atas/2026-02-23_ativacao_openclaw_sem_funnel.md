# Ativacao Openclaw sem Funnel - 2026-02-23

## Decisao

- `funnel` nao sera usado neste setup.
- Publicacao do Openclaw sera apenas na tailnet, usando TCP `18789`.

## Configuracao aplicada

No VPS 1 (`openclaw.json`):
- `gateway.mode = local`
- `gateway.bind = loopback`
- `gateway.tailscale.mode = off`
- `gateway.remote.url = ws://vps-assist.tailed51fe.ts.net:18789`

Na rede Tailscale:
- `tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`

## Resultado

- Backbone validado com `PASS` incluindo assistente edge por check TCP.
- HTTPS dos VPSs mantido estavel (sem impacto na `443` do n8n).

## Observacao

`openclaw gateway health` ainda retorna timeout local no VPS 1 (pendencia de camada aplicacao), apesar de porta e publicacao TCP estarem operacionais.
