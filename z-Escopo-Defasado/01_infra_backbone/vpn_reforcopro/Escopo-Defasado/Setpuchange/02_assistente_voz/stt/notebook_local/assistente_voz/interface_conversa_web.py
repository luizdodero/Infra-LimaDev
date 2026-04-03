#!/usr/bin/env python3

import json
import os
import signal
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

BASE_DIR = Path(__file__).resolve().parent
ASSISTENTE_VOZ_DIR = BASE_DIR.parents[2]
ESCUTA_PATH = BASE_DIR / "escuta.py"
PIPER_RUN_SCRIPT = ASSISTENTE_VOZ_DIR / "tts" / "piper" / "scripts" / "run_piper_server.sh"
VENV_PYTHON = BASE_DIR / "venv" / "bin" / "python"

DEFAULT_ESCUTA_LOG_PATH = BASE_DIR / "conversa_runtime.log"
DEFAULT_PIPER_LOG_PATH = ASSISTENTE_VOZ_DIR / "tts" / "piper" / "logs" / "server_ui.log"
DEFAULT_PIPER_HEALTH_URL = "http://127.0.0.1:18888/health"
DEFAULT_BIND_HOST = "127.0.0.1"
DEFAULT_BIND_PORT = 18900

HTML_PAGE = """<!doctype html>
<html lang=\"pt-BR\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Conversa LimaDev</title>
  <style>
    :root { --bg: #0f172a; --card: #111827; --txt: #e5e7eb; --ok: #10b981; --off: #ef4444; --muted: #9ca3af; }
    body { margin: 0; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto; background: linear-gradient(135deg, #0b1220, #111827); color: var(--txt); }
    .wrap { max-width: 720px; margin: 40px auto; padding: 0 16px; }
    .card { background: rgba(17,24,39,.95); border: 1px solid #1f2937; border-radius: 14px; padding: 20px; box-shadow: 0 12px 32px rgba(0,0,0,.35); }
    h1 { margin: 0 0 8px; font-size: 1.4rem; }
    .sub { margin: 0 0 16px; color: var(--muted); }
    .status { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 16px; }
    .pill { border: 1px solid #374151; border-radius: 10px; padding: 10px; }
    .label { font-size: .85rem; color: var(--muted); }
    .value { font-size: 1rem; font-weight: 600; }
    .on { color: var(--ok); }
    .off { color: var(--off); }
    .btns { display: flex; gap: 10px; margin: 14px 0; }
    button { border: 0; border-radius: 10px; padding: 10px 14px; font-weight: 600; cursor: pointer; }
    .start { background: #10b981; color: #032117; }
    .stop { background: #ef4444; color: #2a0909; }
    pre { background: #0b1220; border: 1px solid #1f2937; border-radius: 10px; padding: 10px; overflow: auto; color: #cbd5e1; }
  </style>
</head>
<body>
  <div class=\"wrap\">
    <div class=\"card\">
      <h1>Conversa LimaDev</h1>
      <p class=\"sub\">Controle de conversa por voz (escuta + Piper)</p>

      <div class=\"status\">
        <div class=\"pill\"><div class=\"label\">Conversa</div><div id=\"st-conv\" class=\"value off\">inativa</div></div>
        <div class=\"pill\"><div class=\"label\">Piper</div><div id=\"st-piper\" class=\"value off\">inativo</div></div>
        <div class=\"pill\"><div class=\"label\">PID Escuta</div><div id=\"pid\" class=\"value\">-</div></div>
        <div class=\"pill\"><div class=\"label\">Piper iniciado pela UI</div><div id=\"managed\" class=\"value\">nao</div></div>
      </div>

      <div class=\"btns\">
        <button class=\"start\" onclick=\"action('start')\">Ativar conversa</button>
        <button class=\"stop\" onclick=\"action('stop')\">Desativar conversa</button>
      </div>

      <div class=\"label\">Resposta</div>
      <pre id=\"out\">pronto</pre>
    </div>
  </div>
  <script>
    async function api(path, method='GET') {
      const r = await fetch(path, { method });
      return await r.json();
    }
    function paint(onEl, on) {
      onEl.textContent = on ? onEl.dataset.on : onEl.dataset.off;
      onEl.className = 'value ' + (on ? 'on' : 'off');
    }
    async function refresh() {
      try {
        const st = await api('/api/status');
        const conv = document.getElementById('st-conv');
        const piper = document.getElementById('st-piper');
        conv.dataset.on = 'ativa'; conv.dataset.off = 'inativa';
        piper.dataset.on = 'ativo'; piper.dataset.off = 'inativo';
        paint(conv, st.escuta_running);
        paint(piper, st.piper_running);
        document.getElementById('pid').textContent = st.escuta_pid || '-';
        document.getElementById('managed').textContent = st.piper_started_by_ui ? 'sim' : 'nao';
      } catch (e) {
        document.getElementById('out').textContent = String(e);
      }
    }
    async function action(name) {
      const out = document.getElementById('out');
      out.textContent = 'processando...';
      try {
        const r = await api('/api/' + name, 'POST');
        out.textContent = JSON.stringify(r, null, 2);
        await refresh();
      } catch (e) {
        out.textContent = String(e);
      }
    }
    refresh();
    setInterval(refresh, 1500);
  </script>
</body>
</html>
"""


def resolve_python_bin() -> str:
    custom = os.getenv("VOICE_RUNNER_PYTHON", "").strip()
    if custom:
        return custom
    if VENV_PYTHON.exists():
        return str(VENV_PYTHON)
    return sys.executable


def is_http_ok(url: str, timeout: float = 1.2) -> bool:
    try:
        with urlopen(url, timeout=timeout) as response:  # nosec B310
            if response.status != 200:
                return False
            body = response.read() or b"{}"
            data = json.loads(body.decode("utf-8", errors="replace"))
            return bool(data.get("ok", True))
    except (URLError, TimeoutError, ValueError, json.JSONDecodeError):
        return False


class ConversationController:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.escuta_process: subprocess.Popen | None = None
        self.escuta_log_handle = None
        self.escuta_log_path = Path(os.getenv("VOICE_RUNTIME_LOG_PATH", str(DEFAULT_ESCUTA_LOG_PATH)))

        self.piper_process: subprocess.Popen | None = None
        self.piper_log_handle = None
        self.piper_log_path = Path(os.getenv("PIPER_UI_LOG_PATH", str(DEFAULT_PIPER_LOG_PATH)))
        self.piper_started_by_ui = False

    def _terminate_process_group(self, process: subprocess.Popen, timeout_seconds: int = 5) -> None:
        if os.name == "posix":
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            except ProcessLookupError:
                return
        else:
            process.terminate()

        try:
            process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            if os.name == "posix":
                try:
                    os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                except ProcessLookupError:
                    pass
            else:
                process.kill()

    def is_escuta_running(self) -> bool:
        return self.escuta_process is not None and self.escuta_process.poll() is None

    def is_piper_running(self) -> bool:
        health_url = os.getenv("PIPER_HEALTH_URL", DEFAULT_PIPER_HEALTH_URL)
        return is_http_ok(health_url)

    def ensure_piper_running(self) -> None:
        if self.is_piper_running():
            return
        if not PIPER_RUN_SCRIPT.exists():
            raise FileNotFoundError(f"Script do Piper nao encontrado: {PIPER_RUN_SCRIPT}")

        self.piper_log_path.parent.mkdir(parents=True, exist_ok=True)
        self.piper_log_handle = self.piper_log_path.open("a", encoding="utf-8")

        popen_kwargs = {
            "args": [str(PIPER_RUN_SCRIPT)],
            "stdout": self.piper_log_handle,
            "stderr": subprocess.STDOUT,
            "cwd": str(ASSISTENTE_VOZ_DIR),
            "env": os.environ.copy(),
        }
        if os.name == "posix":
            popen_kwargs["preexec_fn"] = os.setsid

        self.piper_process = subprocess.Popen(**popen_kwargs)
        self.piper_started_by_ui = True

        for _ in range(40):
            if self.is_piper_running():
                return
            time.sleep(0.5)

        self.stop_managed_piper()
        raise RuntimeError("Piper nao respondeu no healthcheck apos iniciar.")

    def start(self) -> dict:
        with self.lock:
            if self.is_escuta_running():
                return self.status(extra={"message": "conversa ja ativa"})

            self.ensure_piper_running()

            python_bin = resolve_python_bin()
            env = os.environ.copy()
            env.setdefault("N8N_VERIFY_TLS", "0")

            self.escuta_log_path.parent.mkdir(parents=True, exist_ok=True)
            self.escuta_log_handle = self.escuta_log_path.open("a", encoding="utf-8")

            popen_kwargs = {
                "args": [python_bin, str(ESCUTA_PATH), "--loop"],
                "stdout": self.escuta_log_handle,
                "stderr": subprocess.STDOUT,
                "cwd": str(BASE_DIR),
                "env": env,
            }
            if os.name == "posix":
                popen_kwargs["preexec_fn"] = os.setsid

            self.escuta_process = subprocess.Popen(**popen_kwargs)
            return self.status(extra={"message": "conversa ativada"})

    def stop_escuta(self) -> None:
        if self.is_escuta_running() and self.escuta_process is not None:
            self._terminate_process_group(self.escuta_process)

        self.escuta_process = None
        if self.escuta_log_handle is not None:
            self.escuta_log_handle.close()
            self.escuta_log_handle = None

    def stop_managed_piper(self) -> None:
        if self.piper_process is not None and self.piper_process.poll() is None:
            self._terminate_process_group(self.piper_process)

        self.piper_process = None
        self.piper_started_by_ui = False
        if self.piper_log_handle is not None:
            self.piper_log_handle.close()
            self.piper_log_handle = None

    def stop(self) -> dict:
        with self.lock:
            self.stop_escuta()
            if self.piper_started_by_ui:
                self.stop_managed_piper()
            return self.status(extra={"message": "conversa desativada"})

    def status(self, extra: dict | None = None) -> dict:
        data = {
            "ok": True,
            "escuta_running": self.is_escuta_running(),
            "escuta_pid": self.escuta_process.pid if self.is_escuta_running() and self.escuta_process else None,
            "piper_running": self.is_piper_running(),
            "piper_started_by_ui": self.piper_started_by_ui,
            "escuta_log": str(self.escuta_log_path),
            "piper_log": str(self.piper_log_path),
        }
        if extra:
            data.update(extra)
        return data


CONTROLLER = ConversationController()


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html: str) -> None:
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/":
            self._send_html(HTML_PAGE)
            return
        if self.path == "/api/status":
            self._send_json(200, CONTROLLER.status())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/api/start":
            try:
                self._send_json(200, CONTROLLER.start())
            except Exception as err:  # pylint: disable=broad-except
                self._send_json(500, {"ok": False, "error": str(err)})
            return
        if self.path == "/api/stop":
            self._send_json(200, CONTROLLER.stop())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def main() -> int:
    if not ESCUTA_PATH.exists():
        print(f"Arquivo nao encontrado: {ESCUTA_PATH}")
        return 2

    host = os.getenv("VOICE_UI_HOST", DEFAULT_BIND_HOST)
    port = int(os.getenv("VOICE_UI_PORT", str(DEFAULT_BIND_PORT)))

    httpd = ThreadingHTTPServer((host, port), Handler)
    url = f"http://{host}:{port}/"
    print(f"Conversa UI web em {url}")

    if os.getenv("VOICE_UI_OPEN_BROWSER", "1") == "1":
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        CONTROLLER.stop()
        httpd.server_close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
