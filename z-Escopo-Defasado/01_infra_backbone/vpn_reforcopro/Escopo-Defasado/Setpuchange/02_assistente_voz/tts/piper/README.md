# Piper (TTS) - Host Local

## Objetivo

Receber texto do `n8n` (via VPS 1) e reproduzir audio local com Piper.
Na topologia atual, o destino preferencial para essa carga passa a ser o `mini-pc`, mantendo o `note-limdev` como interface operacional.

## Preparacao

1. Criar venv e instalar dependencias:

```bash
python3 -m venv 02_assistente_voz/tts/piper/.venv
source 02_assistente_voz/tts/piper/.venv/bin/activate
pip install --upgrade pip
pip install piper-tts pathvalidate
```

2. Baixar voz (default pt_BR-faber-medium):

```bash
02_assistente_voz/tts/piper/scripts/download_voice.py --voice pt_BR-faber-medium
```

## Subir servidor local

```bash
02_assistente_voz/tts/piper/scripts/run_piper_server.sh
```

Servidor sobe em `http://0.0.0.0:18888/tts`.

Para parar:
`pkill -f piper_server.py`

## Variaveis uteis

- `PIPER_VOICE_KEY`: altera a voz baixada/selecionada.
- `PIPER_MODEL_PATH` / `PIPER_CONFIG_PATH`: override direto do modelo.
- `PIPER_SERVER_PORT`: porta do servidor (default `18888`).
- `PIPER_PLAYBACK=0`: desliga reproducao de audio (teste silencioso).

## Teste manual

```bash
curl -sS -X POST http://127.0.0.1:18888/tts \
  -H 'Content-Type: application/json' \
  -d '{"request_id":"teste-local","assistant_text":"teste de voz"}'
```
