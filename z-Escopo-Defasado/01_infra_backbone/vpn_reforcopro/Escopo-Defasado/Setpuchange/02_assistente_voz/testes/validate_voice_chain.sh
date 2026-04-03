#!/usr/bin/env bash

set -uo pipefail

N8N_BASE_URL="${N8N_BASE_URL:-https://vps-assist.tailed51fe.ts.net}"
VOICE_WEBHOOK_PATH="${VOICE_WEBHOOK_PATH:-/webhook/comando-voz}"
REMOTE_SSH_TARGET="${REMOTE_SSH_TARGET:-root@vps-assist.tailed51fe.ts.net}"
REMOTE_SSH_PORT="${REMOTE_SSH_PORT:-22022}"
REMOTE_DB_PATH="${REMOTE_DB_PATH:-/var/lib/docker/volumes/n8n-docker_n8n_data/_data/database.sqlite}"
REMOTE_QUEUE_PATH="${REMOTE_QUEUE_PATH:-/root/piper_queue.jsonl}"
WORKFLOW_INBOUND_ID="${WORKFLOW_INBOUND_ID:-PndQfLZsfDZ7X9YQ}"
WORKFLOW_RETURN_ID="${WORKFLOW_RETURN_ID:-VozRetn8nPiper01}"
LOG_DIR="${LOG_DIR:-02_assistente_voz/logs}"
REQUEST_TEXT="${REQUEST_TEXT:-fale um resumo rapido do setup atual em uma frase}"
RUN_BACKBONE_CHECK="${RUN_BACKBONE_CHECK:-1}"
BACKBONE_STRICT="${BACKBONE_STRICT:-0}"
POLL_ATTEMPTS="${POLL_ATTEMPTS:-20}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"

mkdir -p "$LOG_DIR"
TS_TAG="$(date +%F_%H%M%S)"
LOG_FILE="${LOG_FILE:-$LOG_DIR/voice_chain_${TS_TAG}.log}"
REQUEST_ID="voice-e2e-${TS_TAG}"
START_UTC="$(date -u '+%Y-%m-%d %H:%M:%S')"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

log "Iniciando validacao: faster-whisper -> n8n -> openclaw -> n8n -> piper"
log "request_id=$REQUEST_ID"

if [[ "$RUN_BACKBONE_CHECK" == "1" ]]; then
  log "Executando check rapido de backbone com edge TCP"
  ASSISTANT_EDGE_CHECK_MODE=tcp \
  ASSISTANT_EDGE_HOST=vps-assist.tailed51fe.ts.net \
  bash 99_shared/scripts/validate_backbone.sh 01_infra_backbone/checklists/hosts.csv >>"$LOG_FILE" 2>&1 || {
    if [[ "$BACKBONE_STRICT" == "1" ]]; then
      log "Falha no backbone. Abortando fluxo E2E (modo estrito)."
      exit 2
    fi
    log "Aviso: backbone com falhas em outros hosts. Continuando no escopo do fluxo de voz."
  }
fi

PAYLOAD_FILE="$LOG_DIR/payload_${REQUEST_ID}.json"
cat >"$PAYLOAD_FILE" <<EOF
{
  "request_id": "$REQUEST_ID",
  "session_id": "voice-session-local",
  "captured_at": "$(date -u +%FT%TZ)",
  "comando": "$REQUEST_TEXT",
  "source": {
    "node": "notebook_local",
    "component": "faster_whisper_manual_test",
    "device_id": "$(hostname)"
  },
  "stt": {
    "provider": "faster-whisper",
    "model_size": "small",
    "language": "pt",
    "text": "$REQUEST_TEXT"
  },
  "timings_ms": {
    "listen": 0,
    "transcribe": 0,
    "send": 0,
    "total": 0
  }
}
EOF

log "Disparando webhook de entrada: ${N8N_BASE_URL}${VOICE_WEBHOOK_PATH}"
RESP_FILE="$LOG_DIR/response_${REQUEST_ID}.txt"
HTTP_CODE="$(curl -k -sS -o "$RESP_FILE" -w '%{http_code}' -X POST "${N8N_BASE_URL}${VOICE_WEBHOOK_PATH}" -H 'Content-Type: application/json' --data-binary "@$PAYLOAD_FILE" || true)"
BODY="$(cat "$RESP_FILE" 2>/dev/null || true)"
log "Resposta webhook: HTTP=$HTTP_CODE body=$BODY"

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  log "Falha ao iniciar fluxo no n8n."
  exit 3
fi

log "Conferindo execucoes no n8n e fila Piper"
CHECK_JSON="$LOG_DIR/check_${REQUEST_ID}.json"
for ((attempt=1; attempt<=POLL_ATTEMPTS; attempt++)); do
  ssh -p "$REMOTE_SSH_PORT" "$REMOTE_SSH_TARGET" "python3 - <<'PY' '$REMOTE_DB_PATH' '$WORKFLOW_INBOUND_ID' '$WORKFLOW_RETURN_ID' '$START_UTC' '$REQUEST_ID' '$REMOTE_QUEUE_PATH'
import json
import sqlite3
import sys
from pathlib import Path

db_path, wf_in, wf_ret, start_utc, request_id, queue_path = sys.argv[1:]
res = {
    'inbound_success': False,
    'return_success': False,
    'inbound_exec_id': None,
    'return_exec_id': None,
    'recent': [],
    'queue_hit': False,
}

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute(
    \"\"\"
    SELECT id, workflowId, status, startedAt, stoppedAt
    FROM execution_entity
    WHERE startedAt >= ?
      AND workflowId IN (?, ?)
    ORDER BY id DESC
    LIMIT 40
    \"\"\",
    (start_utc, wf_in, wf_ret),
)
rows = cur.fetchall()
conn.close()

for exec_id, wf_id, status, started_at, stopped_at in rows:
    item = {
        'id': exec_id,
        'workflowId': wf_id,
        'status': status,
        'startedAt': started_at,
        'stoppedAt': stopped_at,
    }
    res['recent'].append(item)
    if wf_id == wf_in and status == 'success' and not res['inbound_success']:
        res['inbound_success'] = True
        res['inbound_exec_id'] = exec_id
    if wf_id == wf_ret and status == 'success' and not res['return_success']:
        res['return_success'] = True
        res['return_exec_id'] = exec_id

qp = Path(queue_path)
if qp.exists():
    for line in reversed(qp.read_text(encoding='utf-8', errors='replace').splitlines()[-200:]):
        if request_id in line:
            res['queue_hit'] = True
            break

print(json.dumps(res, ensure_ascii=True))
PY" > "$CHECK_JSON"

CHECK_OUT="$(cat "$CHECK_JSON")"
  log "Tentativa $attempt/$POLL_ATTEMPTS: $CHECK_OUT"

INBOUND_OK="$(python3 - <<'PY' "$CHECK_JSON"
import json, sys
obj=json.load(open(sys.argv[1], 'r', encoding='utf-8'))
print('1' if obj.get('inbound_success') else '0')
PY
)"
RETURN_OK="$(python3 - <<'PY' "$CHECK_JSON"
import json, sys
obj=json.load(open(sys.argv[1], 'r', encoding='utf-8'))
print('1' if obj.get('return_success') else '0')
PY
)"
QUEUE_OK="$(python3 - <<'PY' "$CHECK_JSON"
import json, sys
obj=json.load(open(sys.argv[1], 'r', encoding='utf-8'))
print('1' if obj.get('queue_hit') else '0')
PY
)"

  if [[ "$INBOUND_OK" == "1" && "$RETURN_OK" == "1" && "$QUEUE_OK" == "1" ]]; then
    break
  fi

  if [[ "$attempt" -lt "$POLL_ATTEMPTS" ]]; then
    sleep "$POLL_INTERVAL_SECONDS"
  fi
done

if [[ "$INBOUND_OK" != "1" ]]; then
  log "Falha: etapa n8n inbound nao concluiu com sucesso."
  exit 4
fi

if [[ "$RETURN_OK" != "1" ]]; then
  log "Falha: etapa n8n retorno (openclaw -> n8n) nao concluiu com sucesso."
  exit 5
fi

if [[ "$QUEUE_OK" != "1" ]]; then
  log "Aviso: retorno chegou no n8n, mas nao localizei item na fila do Piper."
  exit 6
fi

log "PASS: cadeia validada ate a fila do Piper."
exit 0
