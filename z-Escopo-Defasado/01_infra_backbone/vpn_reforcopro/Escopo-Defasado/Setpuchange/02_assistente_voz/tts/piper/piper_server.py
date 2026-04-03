#!/usr/bin/env python3

import json
import os
import subprocess
import tempfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 18888
DEFAULT_ENDPOINT = "/tts"
DEFAULT_HEALTH = "/health"
DEFAULT_OUTPUT_DIR = Path("02_assistente_voz/tts/piper/out")
DEFAULT_LOG_PATH = Path("02_assistente_voz/tts/piper/logs/events.jsonl")


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_log(entry: dict) -> None:
    path = Path(os.getenv("PIPER_LOG_PATH", str(DEFAULT_LOG_PATH)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=True) + "\n")


def run_piper(text: str, request_id: str) -> Path:
    model = os.getenv("PIPER_MODEL_PATH")
    if not model:
        raise RuntimeError("PIPER_MODEL_PATH not set")

    config = os.getenv("PIPER_CONFIG_PATH")
    piper_bin = os.getenv("PIPER_BIN", "piper")
    output_dir = Path(os.getenv("PIPER_OUTPUT_DIR", str(DEFAULT_OUTPUT_DIR)))
    output_dir.mkdir(parents=True, exist_ok=True)

    out_path = output_dir / f"{request_id}.wav"

    cmd = [piper_bin, "--model", model, "--output_file", str(out_path)]
    if config:
        cmd.extend(["--config", config])

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as tmp:
        tmp.write(text)
        tmp_path = tmp.name

    try:
        cmd.extend(["--input_file", tmp_path])
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    if proc.returncode != 0:
        raise RuntimeError(f"piper failed: {proc.stderr.strip() or proc.stdout.strip()}")

    return out_path


def play_audio(path: Path) -> None:
    if os.getenv("PIPER_PLAYBACK", "1") in {"0", "false", "False"}:
        return
    aplay_bin = os.getenv("APLAY_BIN", "aplay")
    subprocess.run([aplay_bin, str(path)], check=False)


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == DEFAULT_HEALTH:
            self._send(200, {"ok": True, "ts": now_utc_iso()})
            return
        self._send(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path != DEFAULT_ENDPOINT:
            self._send(404, {"ok": False, "error": "not_found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw.decode("utf-8")) if raw else {}
        except json.JSONDecodeError:
            self._send(400, {"ok": False, "error": "invalid_json"})
            return

        request_id = payload.get("request_id") or payload.get("id") or f"tts-{int(datetime.now().timestamp())}"
        text = payload.get("assistant_text") or payload.get("text") or ""
        text = str(text).strip()

        if not text:
            self._send(400, {"ok": False, "error": "empty_text"})
            return

        entry = {
            "request_id": request_id,
            "received_at": now_utc_iso(),
            "text": text,
        }

        try:
            wav_path = run_piper(text, request_id)
            play_audio(wav_path)
            entry.update({
                "status": "ok",
                "wav_path": str(wav_path),
            })
            write_log(entry)
            self._send(200, {"ok": True, "request_id": request_id, "wav_path": str(wav_path)})
        except Exception as err:  # pylint: disable=broad-except
            entry.update({
                "status": "error",
                "error": str(err),
            })
            write_log(entry)
            self._send(500, {"ok": False, "error": str(err)})

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def main() -> None:
    host = os.getenv("PIPER_SERVER_HOST", DEFAULT_HOST)
    port = int(os.getenv("PIPER_SERVER_PORT", str(DEFAULT_PORT)))
    server = HTTPServer((host, port), Handler)
    print(f"Piper server listening on http://{host}:{port}{DEFAULT_ENDPOINT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
