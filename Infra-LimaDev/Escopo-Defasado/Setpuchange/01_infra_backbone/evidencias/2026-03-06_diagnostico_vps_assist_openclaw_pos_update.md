# Diagnostico pos-update Openclaw no vps-assist - 2026-03-06

## Escopo

Verificacao externa do `vps-assist` apos relato de queda do Openclaw depois de atualizacao, incluindo checagem da configuracao de navegacao da Control UI.

## Evidencias desta rodada

- `tailscale ping 100.65.159.1`: `pong` em `1ms`.
- MagicDNS local nao resolveu `vps-assist.tailed51fe.ts.net` neste ambiente porque o proprio cliente Tailscale local reportou falha para escrever em `/etc/resolv.conf`.
- `100.65.159.1:22022` aberto.
- `100.65.159.1:80` aberto.
- `100.65.159.1:443` aberto.
- `100.65.159.1:18789` recusando conexao.
- `100.65.159.1:18790` recusando conexao.
- `https://vps-assist.tailed51fe.ts.net/` com `--resolve` para `100.65.159.1`: TLS valido, resposta `HTTP/2 502`.
- `https://vps-assist.tailed51fe.ts.net/webhook/comando-voz` com `--resolve` para `100.65.159.1`: `HTTP/2 502`.
- `http://100.65.159.1/`: pagina padrao `nginx/1.24.0 (Ubuntu)`.

## Leitura do incidente

- O no `vps-assist` esta vivo e acessivel na tailnet.
- O proxy HTTPS na `443` sobe certificado valido para `vps-assist.tailed51fe.ts.net`, mas o backend publicado atras dele nao responde e retorna `502`.
- O Openclaw nao esta mais exposto nas portas esperadas (`18789` gateway e `18790` Control UI HTTPS).
- Como o fluxo de voz do projeto usa `openclaw agent --local --json` em `03_automacao_vps1/assistente_edge/bot.py`, a queda do Openclaw local e a falha do backend HTTPS afetam tanto o agente quanto o callback para o n8n.

## Configuracao esperada segundo o repositorio

Base documentada:

- `gateway.mode = local`
- `gateway.bind = loopback`
- `gateway.tailscale.mode = off`
- `gateway.remote.url = ws://vps-assist.tailed51fe.ts.net:18789`
- Publicacao tailnet do gateway:
  `tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`
- Publicacao HTTPS da Control UI:
  `tailscale serve --bg --https 18790 http://127.0.0.1:18789`
- Regra de firewall necessaria:
  `iptables -I INPUT 2 -i lo -p tcp --dport 18789 -j ACCEPT`

## Configuracao de navegacao da Control UI

O comportamento "navegacao padrao" por HTTP remoto ja era incompativel com a UI do Openclaw antes da queda.

Segundo a evidencia anterior em `2026-02-24_openclaw_control_ui_https.md`:

- `http://vps-assist.tailed51fe.ts.net:18789/` nao atende ao requisito de contexto seguro.
- A Control UI exige `localhost` ou `HTTPS`.
- O acesso correto para navegador remoto era:
  `https://vps-assist.tailed51fe.ts.net:18790/`
- Alternativa local no VPS:
  `http://127.0.0.1:18789/`
- So se houver decisao explicita de aceitar HTTP remoto:
  `gateway.controlUi.allowInsecureAuth: true`

## Hipoteses mais provaveis apos a atualizacao

1. O processo/servico do Openclaw nao voltou apos reboot ou update.
2. O `tailscale serve` perdeu publicacoes persistidas para `18789` e `18790`.
3. A regra de loopback para `18789` foi perdida no firewall, recriando o timeout local documentado em `2026-02-24_openclaw_gateway_firewall_fix.md`.
4. O backend do n8n ou do proxy HTTPS em `443` nao voltou corretamente, por isso o `502`.

## Proxima verificacao no host

Rodar no host com acesso SSH valido:

```bash
bash 01_infra_backbone/scripts/diagnose_vps_assist_openclaw.sh
```

Se a credencial local nao usar `root` ou IP direto:

```bash
SSH_TARGET=usuario@vps-assist.tailed51fe.ts.net SSH_PORT=22022 \
  bash 01_infra_backbone/scripts/diagnose_vps_assist_openclaw.sh
```

## Comandos provaveis de remediacao

Se o Openclaw estiver instalado e o bind local continuar correto:

```bash
tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789
tailscale serve --bg --https 18790 http://127.0.0.1:18789
iptables -I INPUT 2 -i lo -p tcp --dport 18789 -j ACCEPT
```

Se o backend HTTPS do `vps-assist` continuar em `502`, revisar tambem o servico do `n8n` e o upstream publicado na `443`.
