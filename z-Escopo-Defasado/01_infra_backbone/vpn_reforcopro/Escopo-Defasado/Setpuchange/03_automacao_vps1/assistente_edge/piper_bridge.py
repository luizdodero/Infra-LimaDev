#!/usr/bin/env python3

import json
import os
import ssl
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_QUEUE_PATH = Path("/root/piper_queue.jsonl")
DEFAULT_LOG_PATH = Path("/root/piper_bridge.log")
DEFAULT_TIMEOUT_SECONDS = 20


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_jsonl(path: Path, event: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(event, ensure_ascii=True) + "\n")


def post_to_notebook(url: str, payload: dict, timeout_seconds: int, verify_tls: bool) -> tuple[bool, int, str]:
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), method="POST")
    req.add_header("Content-Type", "application/json")

    ctx = None
    if not verify_tls:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds, context=ctx) as resp:  # nosec B310
            body = (resp.read() or b"").decode("utf-8", errors="replace")[:800]
            return True, int(resp.status), body
    except urllib.error.HTTPError as err:
        body = (err.read() or b"").decode("utf-8", errors="replace")[:800]
        return False, int(err.code), body
    except Exception as err:  # pylint: disable=broad-except
        return False, 0, str(err)


def main() -> int:
    assistant_text = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    request_id = sys.argv[2].strip() if len(sys.argv) > 2 else str(uuid.uuid4())

    event = {
        "request_id": request_id,
        "assistant_text": assistant_text,
        "received_at": now_utc_iso(),
        "provider": "piper",
        "status": "queued",
    }

    queue_path = Path(os.getenv("PIPER_QUEUE_PATH", str(DEFAULT_QUEUE_PATH)))
    log_path = Path(os.getenv("PIPER_BRIDGE_LOG_PATH", str(DEFAULT_LOG_PATH)))
    append_jsonl(queue_path, event)

    notebook_url = os.getenv("PIPER_NOTEBOOK_WEBHOOK_URL", "").strip()
    verify_tls = os.getenv("PIPER_NOTEBOOK_VERIFY_TLS", "0") == "1"
    timeout_seconds = int(os.getenv("PIPER_NOTEBOOK_TIMEOUT_SECONDS", str(DEFAULT_TIMEOUT_SECONDS)))

    result = {
        "ok": True,
        "request_id": request_id,
        "queued": True,
        "queue_path": str(queue_path),
        "forwarded": False,
        "status": "queued",
        "ts": now_utc_iso(),
    }

    if notebook_url:
        ok, status_code, detail = post_to_notebook(notebook_url, event, timeout_seconds, verify_tls)
        result["forwarded"] = ok
        result["forward_status"] = status_code
        result["forward_detail"] = detail
        result["status"] = "forwarded" if ok else "forward_failed_queued"

    append_jsonl(log_path, result)
    print(json.dumps(result, ensure_ascii=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
