#!/usr/bin/env python3
"""Put native speakers' recordings into the app (docs/recording/RECORDING_GUIDE.md).

    backend/.venv/bin/python scripts/import_clips.py <folder of recordings> [--dry-run]

Each file is named <lang>-<phrase ID>.<m4a|mp3|wav|…> as in docs/recording/magana-phrases.xlsx.
Each one is checked against app/assets/voice/phrases.json (unknown names are listed, not used),
then converted with ffmpeg: mono, 22.05 kHz AAC in .m4a, loudness evened out (EBU R128, -16 LUFS),
silence trimmed at both ends. The results go to app/assets/voice/<lang>-<ID>.m4a and
app/assets/voice/clips.json, which the app reads (app/lib/clips.dart).
Recordings are a person's voice: keep the originals out of the repository.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VOICE = ROOT / "app/assets/voice"
AUDIO = {".m4a", ".mp3", ".wav", ".aac", ".ogg", ".opus", ".flac", ".caf", ".3gp", ".amr"}
FILTER = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.15,"
          "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.25,areverse,"
          "loudnorm=I=-16:TP=-1.5:LRA=11")


def known_ids() -> dict[str, set[str]]:
    data = json.loads((VOICE / "phrases.json").read_text(encoding="utf-8"))
    ids = {lang: set(byText.values()) for lang, byText in data.items() if not lang.startswith("_")}
    for lang, patterns in data.get("_patterns", {}).items():
        for p in patterns:
            ids.setdefault(lang, set()).update(x["id"] for x in p["pattern"] if x.get("id"))
    return ids


def main(argv: list[str]) -> int:
    if not argv or argv[0].startswith("-"):
        print(__doc__)
        return 2
    src, dry = Path(argv[0]), "--dry-run" in argv
    if not shutil.which("ffmpeg") and not dry:
        print("ffmpeg is needed (brew install ffmpeg)")
        return 1
    ids = known_ids()
    clips_file = VOICE / "clips.json"
    clips = json.loads(clips_file.read_text(encoding="utf-8")) if clips_file.exists() else {}
    added, unknown, failed = 0, [], []
    for f in sorted(p for p in src.rglob("*") if p.suffix.lower() in AUDIO):
        lang, _, pid = f.stem.partition("-")
        if pid not in ids.get(lang, set()):
            unknown.append(f.name)
            continue
        out = VOICE / f"{lang}-{pid}.m4a"
        if not dry:
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(f), "-ac", "1",
                                "-ar", "22050", "-af", FILTER, "-c:a", "aac", "-b:a", "64k", str(out)],
                               capture_output=True, text=True)
            if r.returncode != 0 or not out.exists() or out.stat().st_size < 1000:
                failed.append(f"{f.name}: {r.stderr.strip()[:120] or 'empty after trimming'}")
                continue
            clips.setdefault(lang, {})[pid] = out.name
        added += 1
    if not dry:
        clips["_about"] = "Made by scripts/import_clips.py from the recordings."
        clips_file.write_text(json.dumps(clips, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                              encoding="utf-8")
    print(f"{'would add' if dry else 'added'}: {added}")
    for name in unknown:
        print(f"  not a phrase ID (check the file name): {name}")
    for line in failed:
        print(f"  not converted: {line}")
    for lang in sorted(ids):
        have = len([k for k in clips.get(lang, {}) if k in ids[lang]])
        print(f"  {lang}: {have} of {len(ids[lang])} phrases recorded")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
