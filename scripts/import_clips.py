#!/usr/bin/env python3
"""Put native speakers' recordings into the app (docs/recording/RECORDING_GUIDE.md).

    backend/.venv/bin/python scripts/import_clips.py <folder of recordings> [--dry-run]

Each file is named <lang>-<phrase ID>.<m4a|mp3|wav|…> as in docs/recording/magana-phrases.xlsx.
Each one is checked against app/assets/voice/phrases.json (unknown names are listed, not used)
and for clipping in the ORIGINAL recording (CLIP_THRESHOLD_DB; a clipped original can't be fixed
by loudness normalisation, so this is checked before conversion, not after). It's then converted
with ffmpeg: mono, 22.05 kHz AAC in .m4a, loudness evened out (EBU R128, -16 LUFS), silence
trimmed at both ends. The results go to app/assets/voice/<lang>-<ID>.m4a and
app/assets/voice/clips.json, which the app reads (app/lib/clips.dart). The report at the end
also names every known phrase ID with no recording yet (not just a count), for each language.
Recordings are a person's voice: keep the originals out of the repository.
"""
from __future__ import annotations

import json
import re
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
# A peak this close to 0 dBFS means the original recording was almost certainly clipped (the
# microphone was overloaded) -- loudness normalisation can't recover audio that was never
# captured, so this is checked on the ORIGINAL file, before ffmpeg touches it.
CLIP_THRESHOLD_DB = -0.5
MAX_VOLUME_RE = re.compile(r"max_volume:\s*(-?[\d.]+)\s*dB")


def peak_level_db(path: Path) -> float | None:
    """The original file's peak level in dBFS (0 = the loudest a sample can be before clipping),
    via ffmpeg's volumedetect filter. None if ffmpeg can't read the file at all (reported
    separately, as a conversion failure, not a clipping one)."""
    r = subprocess.run(
        ["ffmpeg", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    )
    m = MAX_VOLUME_RE.search(r.stderr)
    return float(m.group(1)) if m else None


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
    added, unknown, failed, clipped = 0, [], [], []
    for f in sorted(p for p in src.rglob("*") if p.suffix.lower() in AUDIO):
        lang, _, pid = f.stem.partition("-")
        if pid not in ids.get(lang, set()):
            unknown.append(f.name)
            continue
        peak = peak_level_db(f)
        if peak is not None and peak >= CLIP_THRESHOLD_DB:
            clipped.append(f"{f.name}: peak {peak:+.1f} dB (re-record quieter or further from the mic)")
            continue  # a clipped original is unusable regardless of what conversion would do
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
    for line in clipped:
        print(f"  clipped, not imported: {line}")
    for line in failed:
        print(f"  not converted: {line}")
    MAX_LISTED = 60  # beyond this, naming every one is noise, not a report -- the CSV has the rest
    for lang in sorted(ids):
        have = {k for k in clips.get(lang, {}) if k in ids[lang]}
        missing = sorted(ids[lang] - have)
        print(f"  {lang}: {len(have)} of {len(ids[lang])} phrases recorded")
        if missing and len(missing) <= MAX_LISTED:
            print(f"    missing ({len(missing)}): {', '.join(missing)}")
        elif missing:
            print(f"    missing ({len(missing)}): see docs/recording/phrases-{lang}.csv "
                  f"-- too many to list here (first few: {', '.join(missing[:10])}, ...)")
    return 0 if not (failed or clipped) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
