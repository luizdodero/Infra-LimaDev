# notebook_local

## Papel do host

`note-limdev` e o host de operacao humana do ciclo de voz:
- navegador e observabilidade
- VS Code Remote
- disparo manual da UI de conversa
- acesso a Control UI do OpenClaw

## OpenClaw no note-limdev

Depois da formatacao do `note-limdev` em `2026-03-29`, a Control UI do OpenClaw voltou a aparecer como um device novo e perdeu a aprovacao anterior do gateway.

Sintoma observado:
- Control UI em `https://vps-assist.tailed51fe.ts.net:18790/`
- erro `pairing required`

Contexto do reparo:
- host do gateway: `vps-assist`
- gateway WS: `ws://vps-assist.tailed51fe.ts.net`
- note novo na tailnet: `100.123.108.43`
- device antigo ainda pareado: `100.123.109.53`

## Procedimento de recuperacao

1. Abrir a Control UI no `note-limdev` e clicar `Connect`.
2. No `vps-assist`, aprovar o pending do Control UI:

```bash
openclaw devices approve --latest --token <admin_token> --url ws://127.0.0.1:18789
```

3. Validar que o novo device entrou em `/root/.openclaw/devices/paired.json`.

## Evidencia do ultimo reparo

Data: `2026-03-30`

Novo device aprovado:
- `deviceId`: `44d7ec2ee532b8930bfb51a8872883f097c09394343372bfbe8d0db63510816f`
- `clientId`: `openclaw-control-ui`
- `remoteIp`: `100.123.108.43`

Request capturado no pending:
- `requestId`: `0b9dee1d-9587-46ae-a8fd-705ef1ba25fd`

## Observacao operacional

Se o `pairing required` reaparecer depois de nova reinstalacao do notebook, nao tentar reinstalar o OpenClaw no note primeiro. O reparo correto e:
- gerar novo `Connect` na Control UI
- aprovar o device no `vps-assist`
