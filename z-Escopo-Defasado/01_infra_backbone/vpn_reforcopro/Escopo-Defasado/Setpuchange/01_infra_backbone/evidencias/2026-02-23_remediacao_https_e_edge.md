# Remediacao Backbone - 2026-02-23

## Escopo

- Correcoes de HTTPS nos VPSs.
- Normalizacao de SSH para clientes modernos.
- Publicacao do gateway Openclaw na tailnet (porta `18789`).

## Acoes executadas

1. `vps-assist`
- `n8n` ajustado para HTTPS nativo na `443` com certificado local.
- Compose atualizado em `/root/n8n-docker/docker-compose.yml` (backup local no host remoto).

2. `vps-prod`
- `Caddyfile` atualizado com bloco dedicado ao host tailnet.
- Reload de configuracao aplicado no container `voxgate_edge`.

3. `vps-dev`
- `nginx` instalado e configurado com TLS local na `443`.
- Endpoint de health em `/health`.

4. SSH (`vps-assist` e `vps-prod`)
- `HostKeyAlgorithms` atualizado para incluir `ssh-ed25519`, `ecdsa` e `rsa-sha2`.
- Conexao sem flags legadas validada na `22022`.

5. Assistente edge (Openclaw)
- Mantido bind loopback (requisito do modo funnel do Openclaw).
- Exposicao segura para a tailnet via:
  `tailscale serve --bg --tcp 18789 tcp://127.0.0.1:18789`

## Resultado de validacao

Comando:
`ASSISTANT_EDGE_CHECK_MODE=tcp ASSISTANT_EDGE_HOST=vps-assist.tailed51fe.ts.net bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv`

Resultado: `PASS` (falhas = 0).
