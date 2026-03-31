# Control UI Openclaw via HTTPS (Tailscale Serve) - 2026-02-24

## Sintoma
Dashboard abriu via HTTP, mas retornou erro:
"control ui requires device identity (use HTTPS or localhost secure context)".

## Acao
Publicacao HTTPS na tailnet apontando para o gateway local:

```bash
tailscale serve --bg --https 18790 http://127.0.0.1:18789
```

## Validacao
```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://vps-assist.tailed51fe.ts.net:18790/
```
Resultado: `200`.

## URL de acesso
`https://vps-assist.tailed51fe.ts.net:18790/`
