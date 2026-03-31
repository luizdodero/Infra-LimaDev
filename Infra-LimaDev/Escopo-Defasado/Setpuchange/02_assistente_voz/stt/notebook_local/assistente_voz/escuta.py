import argparse
import json
import os
import socket
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import requests
import speech_recognition as sr
import urllib3
from faster_whisper import WhisperModel


DEFAULT_WEBHOOK_URL = "https://vps-assist.tailed51fe.ts.net/webhook/comando-voz"
DEFAULT_MODEL_SIZE = "small"
DEFAULT_DEVICE = "cpu"
DEFAULT_COMPUTE_TYPE = "int8"
DEFAULT_LANGUAGE = "pt"
DEFAULT_LISTEN_TIMEOUT = 5
DEFAULT_PHRASE_TIME_LIMIT = 15
DEFAULT_REQUEST_TIMEOUT = 15
DEFAULT_RETRY_COUNT = 2
DEFAULT_RETRY_BACKOFF_SECONDS = 1.5
DEFAULT_LOG_PATH = Path(__file__).resolve().parent / "stt_events.jsonl"
DEFAULT_VERIFY_TLS = False


def getenv_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def getenv_float(name: str, default: float) -> float:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return float(value)
    except ValueError:
        return default


def getenv_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    normalized = value.strip().lower()
    return normalized in {"1", "true", "yes", "on"}


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_config() -> dict:
    session_id = os.getenv("VOICE_SESSION_ID", str(uuid.uuid4()))
    return {
        "webhook_url": os.getenv("N8N_WEBHOOK_URL", DEFAULT_WEBHOOK_URL),
        "model_size": os.getenv("WHISPER_MODEL_SIZE", DEFAULT_MODEL_SIZE),
        "device": os.getenv("WHISPER_DEVICE", DEFAULT_DEVICE),
        "compute_type": os.getenv("WHISPER_COMPUTE_TYPE", DEFAULT_COMPUTE_TYPE),
        "language": os.getenv("STT_LANGUAGE", DEFAULT_LANGUAGE),
        "listen_timeout": getenv_int("STT_LISTEN_TIMEOUT_SECONDS", DEFAULT_LISTEN_TIMEOUT),
        "phrase_time_limit": getenv_int("STT_PHRASE_TIME_LIMIT_SECONDS", DEFAULT_PHRASE_TIME_LIMIT),
        "request_timeout": getenv_int("N8N_REQUEST_TIMEOUT_SECONDS", DEFAULT_REQUEST_TIMEOUT),
        "retry_count": getenv_int("N8N_RETRY_COUNT", DEFAULT_RETRY_COUNT),
        "retry_backoff_seconds": getenv_float("N8N_RETRY_BACKOFF_SECONDS", DEFAULT_RETRY_BACKOFF_SECONDS),
        "verify_tls": getenv_bool("N8N_VERIFY_TLS", DEFAULT_VERIFY_TLS),
        "source_node": os.getenv("VOICE_SOURCE_NODE", "notebook_local"),
        "source_component": os.getenv("VOICE_SOURCE_COMPONENT", "stt_faster_whisper"),
        "source_device_id": os.getenv("VOICE_DEVICE_ID", socket.gethostname()),
        "session_id": session_id,
        "log_path": Path(os.getenv("VOICE_PIPELINE_LOG_PATH", str(DEFAULT_LOG_PATH))),
    }


def build_payload(text: str, cfg: dict, request_id: str, timings_ms: dict) -> dict:
    normalized = " ".join(text.split()).strip()
    return {
        "request_id": request_id,
        "session_id": cfg["session_id"],
        "captured_at": now_utc_iso(),
        "comando": normalized,
        "source": {
            "node": cfg["source_node"],
            "component": cfg["source_component"],
            "device_id": cfg["source_device_id"],
        },
        "stt": {
            "provider": "faster-whisper",
            "model_size": cfg["model_size"],
            "language": cfg["language"],
            "text": normalized,
        },
        "timings_ms": timings_ms,
    }


def post_with_retry(
    url: str,
    payload: dict,
    timeout_seconds: int,
    retry_count: int,
    backoff_seconds: float,
    verify_tls: bool,
) -> tuple[bool, int, str]:
    last_status = 0
    last_error = ""

    for attempt in range(1, retry_count + 2):
        try:
            response = requests.post(url, json=payload, timeout=timeout_seconds, verify=verify_tls)
            last_status = response.status_code
            if 200 <= response.status_code < 300:
                response_text = (response.text or "")[:300]
                return True, response.status_code, response_text

            last_error = f"http_status={response.status_code}"
            if response.status_code < 500 and response.status_code != 429:
                break
        except requests.RequestException as err:
            last_error = str(err)

        if attempt < retry_count + 1:
            time.sleep(backoff_seconds * attempt)

    return False, last_status, last_error


def write_event_log(path: Path, event: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(event, ensure_ascii=True) + "\n")


def transcribe_once(recognizer: sr.Recognizer, model: WhisperModel, cfg: dict) -> dict:
    with sr.Microphone() as source:
        print("Ajustando ruido ambiente por 2 segundos...")
        recognizer.adjust_for_ambient_noise(source, duration=2)

        print("Fale agora...")
        listen_started = time.perf_counter()
        audio = recognizer.listen(
            source,
            timeout=cfg["listen_timeout"],
            phrase_time_limit=cfg["phrase_time_limit"],
        )
        listen_ended = time.perf_counter()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_audio:
        temp_audio.write(audio.get_wav_data())
        temp_path = temp_audio.name

    try:
        transcribe_started = time.perf_counter()
        segments, _info = model.transcribe(temp_path, language=cfg["language"])
        transcribe_ended = time.perf_counter()
    finally:
        try:
            os.remove(temp_path)
        except OSError:
            pass

    text = " ".join(segment.text for segment in segments).strip()
    return {
        "text": text,
        "listen_ms": int((listen_ended - listen_started) * 1000),
        "transcribe_ms": int((transcribe_ended - transcribe_started) * 1000),
    }


def run(cfg: dict, loop: bool) -> int:
    if not cfg["verify_tls"]:
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    print("Carregando modelo Faster-Whisper...")
    model = WhisperModel(cfg["model_size"], device=cfg["device"], compute_type=cfg["compute_type"])
    print("Modelo pronto.")

    recognizer = sr.Recognizer()
    print(f"Session ID: {cfg['session_id']}")
    print(f"Webhook n8n: {cfg['webhook_url']}")

    while True:
        request_id = str(uuid.uuid4())
        attempt_started = time.perf_counter()

        try:
            stt_result = transcribe_once(recognizer, model, cfg)
            text = stt_result["text"]

            if not text:
                print("Nenhum texto reconhecido.")
                if not loop:
                    return 0
                continue

            print(f"Texto reconhecido: {text}")
            timings_ms = {
                "listen": stt_result["listen_ms"],
                "transcribe": stt_result["transcribe_ms"],
            }

            payload = build_payload(text, cfg, request_id, timings_ms)

            send_started = time.perf_counter()
            ok, status, detail = post_with_retry(
                url=cfg["webhook_url"],
                payload=payload,
                timeout_seconds=cfg["request_timeout"],
                retry_count=cfg["retry_count"],
                backoff_seconds=cfg["retry_backoff_seconds"],
                verify_tls=cfg["verify_tls"],
            )
            send_ended = time.perf_counter()

            total_ms = int((send_ended - attempt_started) * 1000)
            payload["timings_ms"]["send"] = int((send_ended - send_started) * 1000)
            payload["timings_ms"]["total"] = total_ms

            event = {
                "ts": now_utc_iso(),
                "request_id": request_id,
                "ok": ok,
                "status_code": status,
                "detail": detail,
                "payload": payload,
            }
            write_event_log(cfg["log_path"], event)

            if ok:
                print(f"Enviado para n8n com sucesso (status {status}).")
            else:
                print(f"Falha ao enviar para n8n (status {status}). {detail}")

        except sr.WaitTimeoutError:
            print("Timeout de escuta: nenhum audio capturado.")
            if not loop:
                return 0
        except KeyboardInterrupt:
            print("\nInterrompido pelo usuario.")
            return 0
        except Exception as err:
            print(f"Erro no pipeline de voz: {err}")
            if not loop:
                return 1

        if not loop:
            return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Captura voz local, transcreve com Faster-Whisper e envia para webhook n8n.")
    parser.add_argument("--loop", action="store_true", help="Mantem captura continua ate Ctrl+C.")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    config = load_config()
    raise SystemExit(run(config, loop=args.loop))
