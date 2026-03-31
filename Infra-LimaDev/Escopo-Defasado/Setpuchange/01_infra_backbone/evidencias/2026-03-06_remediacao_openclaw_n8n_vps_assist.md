# Remediacao Openclaw + n8n no vps-assist - 2026-03-06

## Sintoma reportado

- Openclaw caiu depois de atualizacao no `vps-assist`.
- Navegacao "padrao" da UI ja nao funcionava corretamente antes do crash.
- `https://vps-assist.tailed51fe.ts.net` respondia `502`.
- Portas `18789` e `18790` recusavam conexao na tailnet.

## Causa raiz confirmada

1. O gateway do Openclaw (`openclaw-gateway.service`) estava parado no host.
2. A publicacao do `tailscale serve` na `443` estava apontando para `http://127.0.0.1:18789`.
3. Como o gateway em `18789` estava parado, a `443` da tailnet passou a devolver erro no lugar do `n8n`.
4. Durante a tentativa de recriacao, o container `n8n_automations` ficou em estado inconsistente e precisou ser recriado.
5. A navegacao remota correta da Control UI nao era a HTTP em `:18789`; o acesso correto precisa de contexto seguro em `https://vps-assist.tailed51fe.ts.net:18790/`.

## Ajustes aplicados no host

- Reiniciado o `openclaw-gateway.service`.
- Ajustado `/root/.openclaw/openclaw.json` para:
  - `gateway.mode = local`
  - `gateway.port = 18789`
  - `gateway.bind = loopback`
  - `gateway.tailscale.mode = off`
  - `gateway.controlUi.allowedOrigins` incluindo `https://vps-assist.tailed51fe.ts.net:18790`
- Resetada a configuracao errada do `tailscale serve` na `443`.
- Recriada a publicacao correta do Openclaw:
  - `tailscale serve --bg --tcp 18789 127.0.0.1:18789`
  - `tailscale serve --bg --https 18790 http://127.0.0.1:18789`
- Removido e recriado o container `n8n_automations`, restabelecendo o bind `443:5678`.

## Validacao apos correcao

- `nc -z 100.65.159.1 443`: OK
- `nc -z 100.65.159.1 18789`: OK
- `curl -k https://vps-assist.tailed51fe.ts.net/`: `200`
- `curl -k https://vps-assist.tailed51fe.ts.net/rest/settings`: `200`
- `curl -k https://vps-assist.tailed51fe.ts.net/webhook/comando-voz`: `404` em `GET` (esperado para webhook que espera metodo apropriado)
- `curl -k https://vps-assist.tailed51fe.ts.net:18790/`: `200`
- `openclaw agent --local --json --session-id voice-healthcheck --message "ping de validacao"`: resposta JSON valida com texto de retorno

## Estado final esperado

- `n8n` acessivel na `443`.
- Gateway Openclaw publicado na tailnet via TCP `18789`.
- Control UI Openclaw acessivel em `https://vps-assist.tailed51fe.ts.net:18790/`.
- Nao usar navegacao remota em `http://vps-assist.tailed51fe.ts.net:18789/`.
