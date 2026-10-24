"""ASR benchmark: word error rate of NCAIR1's Whisper models, clean and with added noise.

Test audio: the first --clips utterances of each language's FLEURS test set (google/fleurs,
CC BY 4.0; read speech), streamed so only those clips are downloaded. They are cached in
~/.cache/magana-bench/fleurs (not in the repo). FLEURS has no Nigerian-accented English, so
English uses en_us: a limitation for NCAIR1/NigerianAccentedEnglish.

Conditions: clean, and with white noise added at 10 dB and 5 dB signal-to-noise ratio
(a quiet room, then a noisy one). WER uses FLEURS's normalised transcription; for Hausa,
Yorùbá and Igbo it is also given with tone marks and under-dots removed, since spoken-answer
matching does not depend on them.

  backend/.venv/bin/python benchmark/asr/asr_bench.py --langs ha,yo,ig,en --clips 10 \
      --out benchmark/asr/results/<run>
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import statistics
import sys
import tarfile
import time
import unicodedata
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from app import asr  # noqa: E402

FLEURS = {"ha": "ha_ng", "yo": "yo_ng", "ig": "ig_ng", "en": "en_us"}
BASE = "https://huggingface.co/datasets/google/fleurs/resolve/main/data"
CACHE = Path.home() / ".cache" / "magana-bench" / "fleurs"


def fetch(lang: str, n: int) -> list[tuple[str, Path, str]]:
    """The first n test clips (id, wav path, normalised transcription), downloaded once."""
    config = FLEURS[lang]
    folder = CACHE / config
    folder.mkdir(parents=True, exist_ok=True)
    tsv = folder / "test.tsv"
    if not tsv.exists():
        tsv.write_bytes(urllib.request.urlopen(f"{BASE}/{config}/test.tsv").read())
    text_for = {}
    for line in tsv.read_text().splitlines():
        cols = line.split("\t")
        text_for[cols[1]] = cols[3]  # file_name -> normalised transcription
    have = sorted(p for p in folder.glob("*.wav"))
    if len(have) < n:
        with urllib.request.urlopen(f"{BASE}/{config}/audio/test.tar.gz") as stream:
            with tarfile.open(fileobj=stream, mode="r|gz") as tar:
                for member in tar:
                    name = Path(member.name).name
                    if not name.endswith(".wav") or name not in text_for:
                        continue
                    data = tar.extractfile(member).read()
                    (folder / name).write_bytes(data)
                    have = sorted(folder.glob("*.wav"))
                    if len(have) >= n:
                        break
    return [(p.stem, p, text_for[p.name]) for p in have[:n]]


def with_noise(samples: np.ndarray, snr_db: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    power = float(np.mean(samples ** 2)) or 1e-9
    noise = rng.normal(0, np.sqrt(power / 10 ** (snr_db / 10)), len(samples))
    return np.clip(samples + noise, -1, 1).astype("float32")


def wav_bytes(samples: np.ndarray, rate: int) -> bytes:
    buf = io.BytesIO()
    sf.write(buf, samples, rate, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def words(text: str, strip_marks: bool = False) -> list[str]:
    text = unicodedata.normalize("NFC", text.lower())
    if strip_marks:
        text = "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")
    text = "".join(c if c.isalnum() or c.isspace() or c == "'" else " " for c in text)
    return text.split()


def wer(ref: list[str], hyp: list[str]) -> tuple[int, int]:
    """(edits, reference length) by word-level Levenshtein distance."""
    d = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        prev, d[0] = d[0], i
        for j, h in enumerate(hyp, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (r != h))
    return d[len(hyp)], len(ref)


def run(args) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    engine = asr.LocalWhisper()
    conditions = [("clean", None), ("snr10", 10.0), ("snr5", 5.0)]
    rows = []
    for lang in args.langs.split(","):
        clips = fetch(lang, args.clips)
        for clip_id, path, ref in clips:
            samples, rate = sf.read(path, dtype="float32")
            if samples.ndim > 1:
                samples = samples.mean(axis=1)
            for name, snr in conditions:
                audio = samples if snr is None else with_noise(samples, snr, seed=hash(clip_id) & 0xFFFF)
                t = time.monotonic()
                hyp = engine.transcribe(wav_bytes(audio, rate), lang)
                seconds = time.monotonic() - t
                e, n = wer(words(ref), words(hyp))
                e2, n2 = wer(words(ref, True), words(hyp, True))
                rows.append({"lang": lang, "clip": clip_id, "condition": name, "reference": ref,
                             "hypothesis": hyp, "edits": e, "ref_words": n, "edits_no_marks": e2,
                             "ref_words_no_marks": n2, "seconds": round(seconds, 2),
                             "audio_seconds": round(len(samples) / rate, 2)})
                print(f"{lang} {clip_id} {name:6} WER {e}/{n}  {seconds:5.1f}s  {hyp[:60]}", flush=True)

    with open(out / "outputs.jsonl", "w") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    summary = {}
    for lang in args.langs.split(","):
        for name, _ in conditions:
            mine = [r for r in rows if r["lang"] == lang and r["condition"] == name]
            if not mine:
                continue
            summary[f"{lang}/{name}"] = {
                "clips": len(mine),
                "wer": round(sum(r["edits"] for r in mine) / sum(r["ref_words"] for r in mine), 3),
                "wer_no_marks": round(sum(r["edits_no_marks"] for r in mine)
                                      / sum(r["ref_words_no_marks"] for r in mine), 3),
                "median_seconds": statistics.median(r["seconds"] for r in mine),
                "median_audio_seconds": statistics.median(r["audio_seconds"] for r in mine),
            }
    (out / "summary.json").write_text(json.dumps({"note": args.note, "by_condition": summary}, indent=2))
    with open(out / "transcripts_for_review.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["lang", "clip", "condition", "reference", "hypothesis", "reviewer_notes"])
        for r in rows:
            w.writerow([r["lang"], r["clip"], r["condition"], r["reference"], r["hypothesis"], ""])
    lines = ["| Language / condition | Clips | WER | WER without tone marks | Median s (audio s) |",
             "|---|---|---|---|---|"]
    for k, s in summary.items():
        lines.append(f"| {k} | {s['clips']} | {s['wer']} | {s['wer_no_marks']} | "
                     f"{s['median_seconds']} ({s['median_audio_seconds']}) |")
    (out / "summary.md").write_text(f"# ASR benchmark\n\n{args.note}\n\n" + "\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--langs", default="ha,yo,ig,en")
    p.add_argument("--clips", type=int, default=10)
    p.add_argument("--out", required=True)
    p.add_argument("--note", default="")
    run(p.parse_args())
