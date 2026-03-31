# Implantacao Fluxo de Voz no VPS 1 - 2026-02-23

## Itens aplicados

- Script de entrada Openclaw: `03_automacao_vps1/assistente_edge/bot.py`
- Script de ponte para Piper: `03_automacao_vps1/assistente_edge/piper_bridge.py`
- Workflow inbound: `03_automacao_vps1/n8n/workflows/wf_voice_inbound_openclaw.json`
- Workflow retorno: `03_automacao_vps1/n8n/workflows/wf_voice_return_piper.json`

## Webhooks

- Entrada STT: `POST /webhook/comando-voz`
- Retorno Openclaw: `POST /webhook/resposta-openclaw`

## Fluxo funcional

1. Notebook envia texto reconhecido (`stt.text` e `comando`) para `/webhook/comando-voz`.
2. `n8n` executa `python3 /root/bot.py` (SSH node).
3. `bot.py` chama `openclaw agent --local --json` e gera resposta textual.
4. `bot.py` envia a resposta para `/webhook/resposta-openclaw`.
5. `n8n` executa `python3 /root/piper_bridge.py` (SSH node).
6. `piper_bridge.py` registra a mensagem na fila local (`/root/piper_queue.jsonl`).

## Pendencia para fechar audio

- Configurar o consumo final no notebook com Piper ativo (endpoint local ou worker de fila).

## Atualizacao para audio ponta a ponta

- O workflow de retorno deve exportar `PIPER_NOTEBOOK_WEBHOOK_URL` apontando para:
  `http://note-limdev.tailed51fe.ts.net:18888/tts`
- O servidor local do Piper deve estar ativo no notebook (ver `02_assistente_voz/tts/piper/README.md`).
