# Openclaw Gateway RPC Timeout - 2026-02-23

## Sintoma

- `openclaw gateway status` mostra servico em `running` na porta `18789`.
- `openclaw health` e `openclaw gateway call health` retornam timeout em `ws://127.0.0.1:18789`.

## Impacto

- Nao bloqueou a validacao da cadeia de voz porque o fluxo usa:
  `openclaw agent --local --json` (embedded/local), sem dependencia do RPC do gateway.

## Acao aplicada

- Fluxo do n8n foi ajustado para usar `openclaw agent --local` no `bot.py`.
- Validacao fim-a-fim ate fila do Piper concluida com sucesso.

## Pendencia

- Revisar causa raiz do timeout RPC do gateway quando houver janela de manutencao, sem bloquear o fluxo atual de voz.
