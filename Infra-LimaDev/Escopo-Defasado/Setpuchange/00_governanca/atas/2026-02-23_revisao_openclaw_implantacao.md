# Revisao Openclaw - 2026-02-23

## Contexto

Openclaw ainda em fase de implantacao. Acessos externos nao devem ficar ativos por padrao.

## Decisoes

- Manter gateway Openclaw em loopback (`127.0.0.1:18789`) no VPS 1.
- Desativar publicacao tailnet da porta `18789` nesta fase.
- Tratar validacao do assistente edge como opcional (`SKIP`) ate go-live.

## Acao executada

No VPS 1 foi aplicado:
`tailscale serve --tcp=18789 off`

## Criterio para reativacao

Quando o Openclaw entrar em operacao:
1. Ativar publicacao tailnet (`tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`).
2. Definir `ASSISTANT_EDGE_CHECK_MODE=tcp` e `ASSISTANT_EDGE_HOST`.
3. Rodar validacao de backbone com edge habilitado.
