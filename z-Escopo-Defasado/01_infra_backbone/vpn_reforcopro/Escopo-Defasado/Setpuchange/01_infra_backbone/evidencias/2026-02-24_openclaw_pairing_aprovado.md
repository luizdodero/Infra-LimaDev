# Pairing Control UI Openclaw - 2026-02-24

## Sintoma
Control UI conectou via HTTPS, mas retornou:
`disconnected (1008): pairing required`.

## Diagnostico
Havia um device pendente em `/root/.openclaw/devices/pending.json` (clientId: `openclaw-control-ui`).

## Acao
Aprovado o device pendente via CLI do gateway:

```bash
openclaw devices approve --latest --token <admin_token> --url ws://127.0.0.1:18789
```

## Resultado
`pending.json` vazio e Control UI passa a conectar apos refresh.
