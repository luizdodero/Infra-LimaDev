# Validacao de Cadeia de Voz - 2026-02-23

## Cadeia validada

`faster-whisper -> n8n -> openclaw -> n8n -> piper (fila)`

## Escopo desta validacao

- Entrada STT simulada com payload no formato do `faster-whisper`.
- Workflow 1 (`/webhook/comando-voz`) aciona `bot.py` no VPS 1.
- `bot.py` chama `openclaw agent --local --json` e envia retorno para o webhook de volta no n8n.
- Workflow 2 (`/webhook/resposta-openclaw`) aciona `piper_bridge.py` e grava fila para TTS.

## Comando executado

`bash 02_assistente_voz/testes/validate_voice_chain.sh`

## Evidencias locais

- Log principal: `02_assistente_voz/logs/voice_chain_2026-02-23_152136.log`
- Check do n8n: `02_assistente_voz/logs/check_voice-e2e-2026-02-23_152136.json`
- Payload usado: `02_assistente_voz/logs/payload_voice-e2e-2026-02-23_152136.json`

## Resultado

- Webhook de entrada: HTTP `200`.
- Execucao workflow inbound (`PndQfLZsfDZ7X9YQ`): `success`.
- Execucao workflow retorno (`VozRetn8nPiper01`): `success`.
- Fila de TTS encontrada para o `request_id` testado (`/root/piper_queue.jsonl`).

## Observacoes

- A etapa final do Piper ainda esta em modo fila no VPS 1.
- Para audio final no notebook, falta ativar endpoint/worker local do Piper para consumir a fila/retorno.
