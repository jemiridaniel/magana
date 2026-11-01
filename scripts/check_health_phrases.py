#!/usr/bin/env python3
"""Check that Dr. Amos's HEALTH-category recordings say the approved text exactly, word for
word (docs/recording/RECORDING_PACK_AMOS.md). Run on the raw recordings, before or after
scripts/import_clips.py -- this script only reads them; it never writes to app/assets/voice/.

    backend/.venv/bin/python scripts/check_health_phrases.py <folder of recordings>

For each file named en-<HEALTH phrase ID>.<ext> (HEALTH_IDS, scripts/export_priority_phrases.py),
transcribes it with the app's own English ASR (NCAIR1/NigerianAccentedEnglish -- the same model
and engine used in production, backend/app/asr.py's LocalWhisper) and compares the transcript to
the approved text in app/lib/l10n/app_en.arb, word for word after lowercasing and stripping
punctuation. Flags anything short of an exact match for a human to listen to and judge: ASR makes
its own mistakes too, so this flags for review, it does not reject on its own.

Needs the optional ASR dependencies (backend/requirements-asr.txt: torch, transformers,
soundfile) and ffmpeg; downloads the model (about 1 GB) on first run. If either isn't available,
or a specific file can't be transcribed, that file is reported as "not checked", not as a pass.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "backend"))

from export_priority_phrases import HEALTH_IDS, load_arb  # noqa: E402

AUDIO = {".m4a", ".mp3", ".wav", ".aac", ".ogg", ".opus", ".flac", ".caf", ".3gp", ".amr"}


def normalize(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s']", " ", text)  # keep words and apostrophes, drop other punctuation
    return " ".join(text.split())


def to_wav(src: Path) -> bytes:
    """ffmpeg: any audio format -> 16 kHz mono WAV bytes, what asr.py's decode() expects."""
    r = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(src), "-ac", "1", "-ar", "16000",
         "-f", "wav", "-"],
        capture_output=True,
    )
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors="replace")[:200])
    return r.stdout


def main(argv: list[str]) -> int:
    if not argv or argv[0].startswith("-"):
        print(__doc__)
        return 2
    src = Path(argv[0])
    if not src.is_dir():
        print(f"not a folder: {src}")
        return 2

    try:
        from app.asr import LocalWhisper
    except ImportError as exc:
        print(f"ASR dependencies not installed ({exc.name or exc}); nothing checked.\n"
              f"pip install -r backend/requirements-asr.txt to enable this check (needs ffmpeg "
              f"too, and downloads about 1 GB on first run).")
        return 0
    engine = LocalWhisper()

    english = load_arb()
    files = sorted(p for p in src.rglob("en-*") if p.suffix.lower() in AUDIO)
    health_files = [f for f in files if f.stem.partition("-")[2] in HEALTH_IDS]
    if not health_files:
        print(f"no en-<HEALTH phrase ID>.<audio> files found under {src} "
              f"({len(HEALTH_IDS)} HEALTH ids expected -- see priority-phrases.csv)")
        return 0

    checked, flagged, skipped = 0, [], []
    for f in health_files:
        pid = f.stem.partition("-")[2]
        approved = english[pid]  # HEALTH_IDS is built from this same ARB file; always present
        try:
            heard = engine.transcribe(to_wav(f), "en")
        except Exception as exc:  # ffmpeg failure, model download failure, corrupt audio, ...
            skipped.append(f"{f.name}: couldn't transcribe ({type(exc).__name__}: {exc})")
            continue
        checked += 1
        if normalize(heard) != normalize(approved):
            flagged.append(f"{f.name} ({pid}):\n    approved: {approved}\n    heard:    {heard}")

    print(f"checked {checked} of {len(HEALTH_IDS)} HEALTH recordings against the approved text")
    for line in skipped:
        print(f"  not checked: {line}")
    if flagged:
        print(f"\n{len(flagged)} to listen to and confirm (a flag means the transcript differs, "
              f"not that the recording is wrong -- ASR mishears things too):")
        for block in flagged:
            print(f"  {block}")
    elif checked:
        print("  every one transcribed to an exact match of the approved text.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
