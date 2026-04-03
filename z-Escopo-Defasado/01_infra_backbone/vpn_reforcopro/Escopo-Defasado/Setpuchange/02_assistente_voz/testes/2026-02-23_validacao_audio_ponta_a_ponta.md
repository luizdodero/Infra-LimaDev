# Validacao Audio Ponta a Ponta - 2026-02-23

## Cadeia validada

`faster-whisper -> n8n -> openclaw -> n8n -> piper (audio local)`

## Preparacao

- Servidor Piper local ativo em `http://0.0.0.0:18888/tts`.
- Workflow `VozRetn8nPiper01` configurado com:
  `PIPER_NOTEBOOK_WEBHOOK_URL="http://note-limdev.tailed51fe.ts.net:18888/tts"`

## Execucao

- Comando: `RUN_BACKBONE_CHECK=0 bash 02_assistente_voz/testes/validate_voice_chain.sh`
- `request_id`: `voice-e2e-2026-02-23_164612`

## Evidencias locais

- Log principal: `02_assistente_voz/logs/voice_chain_2026-02-23_164612.log`
- Check do n8n: `02_assistente_voz/logs/check_voice-e2e-2026-02-23_164612.json`
- WAV gerado: `02_assistente_voz/tts/piper/out/voice-e2e-2026-02-23_164612.wav`

## Resultado

- Workflow inbound: `success`.
- Workflow retorno: `success`.
- Audio gerado localmente via Piper.
