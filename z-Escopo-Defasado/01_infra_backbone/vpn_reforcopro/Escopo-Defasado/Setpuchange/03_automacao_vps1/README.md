# 03_automacao_vps1

## Objetivo
Consolidar a automacao do VPS 1, com n8n como orquestrador e pasta dedicada aos arquivos do assistente edge.

## Pastas

- `n8n/workflows`: exportacoes de fluxos e versoes.
- `n8n/docker`: compose, variaveis e scripts de operacao.
- `n8n/webhooks`: contratos de entrada/saida e exemplos.
- `assistente_edge`: codigo, configuracoes e runtime do assistente IA no VPS 1.
- `docs`: notas operacionais, arquitetura local e troubleshooting.

## Checklist inicial

- [x] Publicar `docker compose` do n8n com variaveis parametrizadas.
- [x] Versionar workflows base de voz em `n8n/workflows`.
- [x] Definir contrato de webhook para entrada STT (`/webhook/comando-voz`).
- [x] Definir contrato de resposta para TTS (`/webhook/resposta-openclaw`).
- [x] Isolar configuracoes do assistente edge em `assistente_edge/`.

## Arquivos ativos (fluxo de voz)

- `assistente_edge/bot.py`: ponte `n8n -> openclaw -> n8n`.
- `assistente_edge/piper_bridge.py`: ponte `n8n -> fila Piper`.
- `n8n/workflows/wf_voice_inbound_openclaw.json`: workflow de entrada STT.
- `n8n/workflows/wf_voice_return_piper.json`: workflow de retorno para TTS.
- `docs/2026-02-23_implantacao_fluxo_voz.md`: historico de implantacao.
