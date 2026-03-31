#!/usr/bin/env python3

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

VOICE_INDEX_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/voices.json"
BASE_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=60) as resp:  # nosec B310
        data = resp.read()
    dest.write_bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser(description="Download Piper voice model and config")
    parser.add_argument("--voice", default="pt_BR-faber-medium", help="Voice key from voices.json")
    parser.add_argument("--out-dir", default="02_assistente_voz/tts/piper/models", help="Base output directory")
    args = parser.parse_args()

    with urllib.request.urlopen(VOICE_INDEX_URL, timeout=30) as resp:  # nosec B310
        voices = json.load(resp)

    if args.voice not in voices:
        print(f"Voice not found: {args.voice}")
        print("Available voices (pt_*):")
        for key in sorted(k for k in voices if k.startswith("pt_")):
            print(f"- {key}")
        return 2

    voice = voices[args.voice]
    files = voice.get("files", {})
    if not files:
        print(f"No files listed for voice: {args.voice}")
        return 3

    out_dir = Path(args.out_dir) / args.voice
    out_dir.mkdir(parents=True, exist_ok=True)

    model_path = None
    config_path = None

    for rel_path in files:
        filename = os.path.basename(rel_path)
        url = BASE_URL + rel_path
        dest = out_dir / filename
        print(f"Downloading {url} -> {dest}")
        download(url, dest)
        if filename.endswith(".onnx"):
            model_path = dest
        elif filename.endswith(".onnx.json"):
            config_path = dest

    print("Downloaded")
    print(f"MODEL={model_path}")
    print(f"CONFIG={config_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
