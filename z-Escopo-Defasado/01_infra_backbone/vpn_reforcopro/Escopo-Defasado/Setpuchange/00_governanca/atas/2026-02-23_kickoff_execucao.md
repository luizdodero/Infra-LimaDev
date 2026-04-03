# Ata de Kickoff - 2026-02-23

## Decisoes confirmadas

- Estrutura de pastas por frentes de trabalho aplicada no workspace.
- Backbone inclui acesso ao assistente IA edge no VPS 1.
- Frente `03_automacao_vps1` possui pasta dedicada para arquivos do assistente edge.
- Frente `04_producao_vps2` possui camada `infra_compartilhada` (nginx, TLS, firewall, observabilidade).
- Motor de TTS definido como Piper.
- Porta padrao do assistente edge (Openclaw) definida como `18789`.

## Entregas do kickoff

- Runbook inicial de validacao do backbone.
- Template de evidencias para a primeira rodada.
- Script reutilizavel de validacao em `99_shared/scripts/validate_backbone.sh`.
- Guia de acesso ao assistente edge no backbone.
- HTTPS corrigido nos VPSs (assist/prod/dev) e validado.
- SSH modernizado em assist/prod (algoritmos atuais + compatibilidade).
- Publicacao do gateway Openclaw na tailnet via `tailscale serve --tcp 18789`.

## Proxima acao imediata

Executar a primeira rodada com hosts reais e registrar evidencia em:
`01_infra_backbone/evidencias/`.
