#!/usr/bin/env python3

import json
import os
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_CALLBACK_URL = "https://vps-assist.tailed51fe.ts.net/webhook/resposta-openclaw"
DEFAULT_TIMEOUT_SECONDS = 30
DEFAULT_LOG_PATH = Path("/root/openclaw_bridge.log")


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_log(entry: dict) -> None:
    path = Path(os.getenv("OPENCLAW_BRIDGE_LOG_PATH", str(DEFAULT_LOG_PATH)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=True) + "\n")


def parse_args() -> tuple[str, str]:
    command_text = sys.argv[1] if len(sys.argv) > 1 else ""
    request_id = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else str(uuid.uuid4())
    return command_text.strip(), request_id


def run_openclaw(command_text: str, request_id: str) -> tuple[bool, str, dict]:
    session_id = f"voice-{request_id}"
    cmd = [
        "openclaw",
        "agent",
        "--local",
        "--json",
        "--session-id",
        session_id,
        "-m",
        command_text,
    ]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    except Exception as err:  # pylint: disable=broad-except
        return False, "", {"error": f"openclaw_exec_error: {err}"}

    raw_stdout = (proc.stdout or "").strip()
    raw_stderr = (proc.stderr or "").strip()
    if proc.returncode != 0:
        return False, "", {
            "error": "openclaw_nonzero_exit",
            "returncode": proc.returncode,
            "stderr": raw_stderr[:800],
            "stdout": raw_stdout[:800],
        }

    try:
        parsed = json.loads(raw_stdout)
    except json.JSONDecodeError as err:
        return False, "", {
            "error": "openclaw_invalid_json",
            "detail": str(err),
            "stdout": raw_stdout[:800],
        }

    payloads = parsed.get("payloads") if isinstance(parsed, dict) else None
    reply = ""
    if isinstance(payloads, list) and payloads:
        first = payloads[0]
        if isinstance(first, dict):
            reply = str(first.get("text") or "").strip()

    if not reply:
        return False, "", {"error": "openclaw_empty_reply", "raw": parsed}

    return True, reply, {"raw": parsed}


def post_callback(url: str, payload: dict, timeout_seconds: int) -> tuple[bool, int, str]:
    data = json.dumps(payload, ensure_ascii=True).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    verify_tls = os.getenv("OPENCLAW_CALLBACK_VERIFY_TLS", "0") == "1"
    ctx = None
    if not verify_tls:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds, context=ctx) as resp:  # nosec B310
            body = (resp.read() or b"").decode("utf-8", errors="replace")[:1000]
            return True, int(resp.status), body
    except urllib.error.HTTPError as err:
        body = (err.read() or b"").decode("utf-8", errors="replace")[:1000]
        return False, int(err.code), body
    except Exception as err:  # pylint: disable=broad-except
        return False, 0, str(err)


def main() -> int:
    command_text, request_id = parse_args()
    callback_url = os.getenv("OPENCLAW_CALLBACK_URL", DEFAULT_CALLBACK_URL)
    timeout_seconds = int(os.getenv("OPENCLAW_CALLBACK_TIMEOUT_SECONDS", str(DEFAULT_TIMEOUT_SECONDS)))

    if not command_text:
        result = {
            "ok": False,
            "request_id": request_id,
            "error": "empty_command",
            "ts": now_utc_iso(),
        }
        print(json.dumps(result, ensure_ascii=True))
        append_log(result)
        return 2

    ok_openclaw, reply_text, openclaw_meta = run_openclaw(command_text, request_id)
    if not ok_openclaw:
        result = {
            "ok": False,
            "request_id": request_id,
            "error": openclaw_meta,
            "ts": now_utc_iso(),
        }
        print(json.dumps(result, ensure_ascii=True))
        append_log(result)
        return 3

    callback_payload = {
        "request_id": request_id,
        "captured_at": now_utc_iso(),
        "source": {
            "node": "vps-assist",
            "component": "openclaw_agent_local",
        },
        "input_text": command_text,
        "assistant_text": reply_text,
        "tts": {
            "provider": "piper",
            "status": "pending_dispatch",
        },
    }

    ok_cb, status_code, body = post_callback(callback_url, callback_payload, timeout_seconds)
    result = {
        "ok": ok_openclaw and ok_cb,
        "request_id": request_id,
        "callback_ok": ok_cb,
        "callback_status": status_code,
        "assistant_text": reply_text,
        "callback_detail": body,
        "ts": now_utc_iso(),
    }

    print(json.dumps(result, ensure_ascii=True))
    append_log(result)

    if not ok_cb:
        return 4
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
