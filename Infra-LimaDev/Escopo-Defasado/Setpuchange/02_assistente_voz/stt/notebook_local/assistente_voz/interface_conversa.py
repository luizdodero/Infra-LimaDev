#!/usr/bin/env python3

import json
import os
import signal
import subprocess
import sys
import time
import tkinter as tk
from pathlib import Path
from tkinter import messagebox
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


class ConversaUI:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Controle de Conversa")
        self.root.geometry("480x250")
        self.root.resizable(False, False)

        self.escuta_process: subprocess.Popen | None = None
        self.escuta_log_handle = None
        self.escuta_log_path = Path(os.getenv("VOICE_RUNTIME_LOG_PATH", str(DEFAULT_ESCUTA_LOG_PATH)))

        self.piper_process: subprocess.Popen | None = None
        self.piper_log_handle = None
        self.piper_log_path = Path(os.getenv("PIPER_UI_LOG_PATH", str(DEFAULT_PIPER_LOG_PATH)))
        self.piper_started_by_ui = False

        self.conversa_var = tk.StringVar(value="Conversa: inativa")
        self.pid_var = tk.StringVar(value="PID escuta: -")
        self.piper_var = tk.StringVar(value="Piper: inativo")
        self.info_var = tk.StringVar(value=f"Log escuta: {self.escuta_log_path}")

        self._build_ui()
        self._refresh_state()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self) -> None:
        frame = tk.Frame(self.root, padx=16, pady=16)
        frame.pack(fill="both", expand=True)

        title = tk.Label(frame, text="Conversa por voz", font=("Arial", 14, "bold"))
        title.pack(anchor="w")

        subtitle = tk.Label(
            frame,
            text="Ativa/desativa escuta e Piper em conjunto.",
            font=("Arial", 10),
        )
        subtitle.pack(anchor="w", pady=(4, 14))

        buttons = tk.Frame(frame)
        buttons.pack(anchor="w")

        self.start_btn = tk.Button(
            buttons,
            text="Ativar conversa",
            width=18,
            command=self.start_conversation,
        )
        self.start_btn.pack(side="left")

        self.stop_btn = tk.Button(
            buttons,
            text="Desativar conversa",
            width=18,
            command=self.stop_conversation,
        )
        self.stop_btn.pack(side="left", padx=(8, 0))

        tk.Label(frame, textvariable=self.conversa_var, font=("Arial", 11)).pack(anchor="w", pady=(18, 2))
        tk.Label(frame, textvariable=self.pid_var, font=("Arial", 10)).pack(anchor="w", pady=(2, 2))
        tk.Label(frame, textvariable=self.piper_var, font=("Arial", 10)).pack(anchor="w", pady=(2, 2))
        tk.Label(
            frame,
            textvariable=self.info_var,
            font=("Arial", 9),
            fg="#555555",
            wraplength=440,
            justify="left",
        ).pack(anchor="w", pady=(2, 0))

    def _refresh_state(self) -> None:
        escuta_running = self.is_escuta_running()
        piper_running = self.is_piper_running()

        self.conversa_var.set("Conversa: ativa" if escuta_running else "Conversa: inativa")
        self.pid_var.set(f"PID escuta: {self.escuta_process.pid if escuta_running else '-'}")
        self.piper_var.set("Piper: ativo" if piper_running else "Piper: inativo")

        self.start_btn.config(state="disabled" if escuta_running else "normal")
        self.stop_btn.config(state="normal" if escuta_running or self._is_managed_piper_running() else "disabled")

        self.root.after(1000, self._refresh_state)

    def is_escuta_running(self) -> bool:
        return self.escuta_process is not None and self.escuta_process.poll() is None

    def is_piper_running(self) -> bool:
        health_url = os.getenv("PIPER_HEALTH_URL", DEFAULT_PIPER_HEALTH_URL)
        return is_http_ok(health_url)

    def _is_managed_piper_running(self) -> bool:
        return self.piper_process is not None and self.piper_process.poll() is None

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

    def start_conversation(self) -> None:
        if self.is_escuta_running():
            return

        try:
            self.ensure_piper_running()
        except Exception as err:  # pylint: disable=broad-except
            messagebox.showerror("Erro ao iniciar Piper", str(err))
            return

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

    def stop_escuta(self) -> None:
        if not self.is_escuta_running():
            if self.escuta_log_handle is not None:
                self.escuta_log_handle.close()
                self.escuta_log_handle = None
            self.escuta_process = None
            return

        assert self.escuta_process is not None
        self._terminate_process_group(self.escuta_process)
        self.escuta_process = None

        if self.escuta_log_handle is not None:
            self.escuta_log_handle.close()
            self.escuta_log_handle = None

    def stop_managed_piper(self) -> None:
        if self.piper_process is not None and self._is_managed_piper_running():
            self._terminate_process_group(self.piper_process)

        self.piper_process = None
        self.piper_started_by_ui = False

        if self.piper_log_handle is not None:
            self.piper_log_handle.close()
            self.piper_log_handle = None

    def stop_conversation(self) -> None:
        self.stop_escuta()
        if self.piper_started_by_ui:
            self.stop_managed_piper()

    def _on_close(self) -> None:
        self.stop_conversation()
        self.root.destroy()


def main() -> int:
    if not ESCUTA_PATH.exists():
        print(f"Arquivo nao encontrado: {ESCUTA_PATH}")
        return 2

    root = tk.Tk()
    ConversaUI(root)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
