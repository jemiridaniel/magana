#!/usr/bin/env python3
"""Put native speakers' recordings into the app (docs/recording/RECORDING_GUIDE.md).

    backend/.venv/bin/python scripts/import_clips.py <folder of recordings> [--dry-run] [--out DIR]
        [--shorten-pauses[=ID,ID,…]]

Each file is named <lang>-<phrase ID>.<m4a|mp3|wav|…> as in docs/recording/magana-phrases.xlsx.
Each one is checked against app/assets/voice/phrases.json (unknown names are listed, not used)
and for clipping in the ORIGINAL recording (CLIP_THRESHOLD_DB; a clipped original can't be fixed
by loudness normalisation, so this is checked before conversion, not after). It's then converted
with ffmpeg: mono, 22.05 kHz AAC in .m4a, loudness evened out (EBU R128, -16 LUFS), silence
trimmed at both ends (about 150 ms of quiet kept on each side). The results go to
app/assets/voice/<lang>-<ID>.m4a and app/assets/voice/clips.json, which the app reads
(app/lib/clips.dart); with --out DIR they go to DIR instead (a staging folder, for checking
before they go into the app). --shorten-pauses also shortens every pause inside a clip that is
longer than 0.6 s to about 0.4 s (and one of 0.4–0.6 s to 0.4 s) (all clips, or only the phrase IDs listed): a long pause
mid-prompt sounds like the end of it. The report at the end
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
TRIM = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.15,"
        "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.15,areverse")
LOUDNORM = "loudnorm=I=-16:TP=-1.5:LRA=11"
# --shorten-pauses: a pause inside the clip (below -45 dB) is cut to 0.4 s. silenceremove keeps
# stop_duration + stop_silence of each pause it cuts (ffmpeg 9: 0.6 + 0.4 left 1.0 s), so
# 0.2 + 0.2 = 0.4 s. A pause between 0.4 and 0.6 s is cut to 0.4 s too (at most 0.2 s shorter).
SHORTEN = "silenceremove=stop_periods=-1:stop_duration=0.2:stop_threshold=-45dB:stop_silence=0.2"
# Peaks held at -3 dBFS after normalising: AAC encoding overshoots by 1-2 dB, and without this
# some prompts peaked above 0 dBFS (+1.4), which a phone speaker plays as a crackle.
LIMIT = "alimiter=limit=0.708:attack=5:release=50:level=false"
LOUDNORM_JSON = re.compile(r"\{[^{}]*\"input_i\"[^{}]*\}", re.S)


def loudness_filter(path: Path, trim: str = TRIM) -> str:
    """Two-pass loudness normalisation: measure the trimmed clip, then correct it linearly. One
    pass leaves short prompts several LU apart (-19 to -14 LUFS for one speaker's 46 prompts,
    9 Nov 2026); two passes put each one at the same level, so no prompt is louder than the next."""
    r = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", str(path), "-ac", "1", "-ar", "22050",
                        "-af", f"{trim},{LOUDNORM}:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = LOUDNORM_JSON.search(r.stderr)
    if not m:
        return LOUDNORM
    v = json.loads(m.group(0))
    return (f"{LOUDNORM}:measured_I={v['input_i']}:measured_TP={v['input_tp']}:measured_LRA={v['input_lra']}"
            f":measured_thresh={v['input_thresh']}:offset={v['target_offset']}:linear=true")
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
    out_dir = Path(argv[argv.index("--out") + 1]).expanduser() if "--out" in argv else VOICE
    out_dir.mkdir(parents=True, exist_ok=True)
    shorten = next((a for a in argv if a.startswith("--shorten-pauses")), None)
    shorten_ids = set(shorten.partition("=")[2].split(",")) - {""} if shorten else set()
    if not shutil.which("ffmpeg") and not dry:
        print("ffmpeg is needed (brew install ffmpeg)")
        return 1
    ids = known_ids()
    clips_file = out_dir / "clips.json"
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
        out = out_dir / f"{lang}-{pid}.m4a"
        trim = f"{TRIM},{SHORTEN}" if shorten and (not shorten_ids or pid in shorten_ids) else TRIM
        if not dry:
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(f), "-ac", "1",
                                "-ar", "22050", "-af", f"{trim},{loudness_filter(f, trim)},{LIMIT}", "-c:a", "aac",
                                "-b:a", "64k", str(out)],
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
