#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$BASE_DIR/.venv"
VOICE_KEY="${PIPER_VOICE_KEY:-pt_BR-faber-medium}"
MODEL_DIR="$BASE_DIR/models/$VOICE_KEY"
MODEL_PATH="${PIPER_MODEL_PATH:-$MODEL_DIR/${VOICE_KEY}.onnx}"
CONFIG_PATH="${PIPER_CONFIG_PATH:-$MODEL_DIR/${VOICE_KEY}.onnx.json}"

if [[ ! -d "$VENV_DIR" ]]; then
  echo "Venv nao encontrado em $VENV_DIR" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if [[ ! -f "$MODEL_PATH" || ! -f "$CONFIG_PATH" ]]; then
  echo "Modelo/Config nao encontrados. Baixe primeiro:" >&2
  echo "  $BASE_DIR/scripts/download_voice.py --voice $VOICE_KEY" >&2
  exit 3
fi

export PIPER_MODEL_PATH="$MODEL_PATH"
export PIPER_CONFIG_PATH="$CONFIG_PATH"
export PIPER_OUTPUT_DIR="${PIPER_OUTPUT_DIR:-$BASE_DIR/out}"
export PIPER_LOG_PATH="${PIPER_LOG_PATH:-$BASE_DIR/logs/events.jsonl}"
export PIPER_SERVER_HOST="${PIPER_SERVER_HOST:-0.0.0.0}"
export PIPER_SERVER_PORT="${PIPER_SERVER_PORT:-18888}"
export PIPER_BIN="${PIPER_BIN:-$(command -v piper)}"

python3 "$BASE_DIR/piper_server.py"
