"""Quiz-answer recognition: is the RIGHT answer understood? (Not word error rate.)

For each language, short answers are synthesised (we have no recordings yet):
  letters A, B, C, D as learners say them (Yorùbá "à, bí, sí, dí"), yes, no, true, false.
Voices: Meta's MMS-TTS (facebook/mms-tts-eng, -hau, -yor; CC BY-NC 4.0: internal testing
only, clips are never published or kept in the repo) at three speaking rates; for English
also four macOS voices (there is no Nigerian-English one); for Igbo, which MMS lacks, the
VITS OpenBible Igbo voice (CC BY-SA 4.0, synth_igbo_coqui.py). Each clip is padded with silence,
then tested clean and with white noise at 10 dB and 5 dB SNR.

Each clip goes through Magana's server ASR (NCAIR1 Whisper, backend/app/asr.py), then the
app's own answer rules (app/test_tool/score_answers_test.dart: quiz.dart's letter and
true/false rules, voice_answers.yesNo for the yes/no confirmation). Outcomes:
  right    the answer the learner meant
  wrong    a different answer (the app then asks "You said C. Is that right?")
  unclear  nothing usable (the app asks again, then offers tapping)

Synthetic speech is cleaner and more uniform than learners; treat these as a best case.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(Path(__file__).parent))

from asr_bench import with_noise  # noqa: E402

from app import asr  # noqa: E402

CACHE = Path.home() / ".cache" / "magana-bench" / "answers"
RATE = 16000

# (what the learner means, what they say) per language. Drafts for native review.
ANSWERS = {
    "en": [("A", "ay"), ("B", "bee"), ("C", "see"), ("D", "dee"),
           ("yes", "yes"), ("no", "no"), ("true", "true"), ("false", "false")],
    "ha": [("A", "ei"), ("B", "bi"), ("C", "si"), ("D", "di"),
           ("yes", "ee"), ("no", "a'a"), ("true", "gaskiya"), ("false", "ƙarya")],
    "yo": [("A", "à"), ("B", "bí"), ("C", "sí"), ("D", "dí"),
           ("yes", "bẹ́ẹ̀ni"), ("no", "rárá"), ("true", "òótọ́"), ("false", "irọ́")],
    "ig": [("A", "ei"), ("B", "bi"), ("C", "si"), ("D", "di"),
           ("yes", "ee"), ("no", "mba"), ("true", "eziokwu"), ("false", "ụgha")],
}
MMS = {"en": "facebook/mms-tts-eng", "ha": "facebook/mms-tts-hau", "yo": "facebook/mms-tts-yor"}
MMS_RATES = (0.85, 1.0, 1.2)
# English letters from macOS voices. Lower case: macOS reads "B" as "capital B".
SAY_VOICES = ("Samantha", "Daniel", "Rishi", "Flo (English (UK))")


def pad(samples: np.ndarray) -> np.ndarray:
    silence = np.zeros(int(0.5 * RATE), dtype=np.float32)
    return np.concatenate([silence, samples.astype(np.float32), silence])


def wav_bytes(samples: np.ndarray) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())
    return buf.getvalue()


def synth_mms(lang: str) -> list[dict]:
    import torch
    from transformers import AutoTokenizer, VitsModel

    tok = AutoTokenizer.from_pretrained(MMS[lang])
    model = VitsModel.from_pretrained(MMS[lang])
    out = []
    for intended, said in ANSWERS[lang]:
        for rate in MMS_RATES:
            path = CACHE / f"mms-{lang}-{intended}-{rate}.npy"
            if not path.exists():
                torch.manual_seed(7)
                model.speaking_rate = rate
                with torch.no_grad():
                    wave_ = model(**tok(said, return_tensors="pt")).waveform[0].numpy()
                assert model.config.sampling_rate == RATE
                path.parent.mkdir(parents=True, exist_ok=True)
                np.save(path, wave_)
            out.append({"lang": lang, "intended": intended, "said": said, "voice": f"mms x{rate}",
                        "samples": np.load(path)})
    return out


def synth_igbo() -> list[dict]:
    """MMS-TTS has no Igbo voice: the VITS OpenBible Igbo voice, through Coqui TTS in its own
    environment (COQUI_PYTHON), up to three of its speakers."""
    model_dir = Path(os.environ.get("IGBO_TTS_DIR", CACHE.parent / "igbo-vits"))
    python = os.environ.get("COQUI_PYTHON")
    if not python or not (model_dir / "model_last.pth").exists():
        raise SystemExit("Igbo needs COQUI_PYTHON (coqui-tts) and IGBO_TTS_DIR (VITS-OpenBible-Igbo)")
    if not list(CACHE.glob("coqui-ig-*.npy")):
        subprocess.run([python, str(Path(__file__).parent / "synth_igbo_coqui.py"), str(model_dir), str(CACHE),
                        json.dumps(ANSWERS["ig"])], check=True)
    said = dict(ANSWERS["ig"])
    return [{"lang": "ig", "intended": p.stem.rsplit("-", 1)[1], "said": said[p.stem.rsplit("-", 1)[1]],
             "voice": "VITS " + p.stem.split("-", 2)[2].rsplit("-", 1)[0], "samples": np.load(p)}
            for p in sorted(CACHE.glob("coqui-ig-*.npy"))]


def synth_say() -> list[dict]:
    out = []
    for intended, said in ANSWERS["en"]:
        text = intended.lower() if intended in "ABCD" else said
        for voice in SAY_VOICES:
            path = CACHE / f"say-lower-{voice.split()[0]}-{intended}.npy"
            if not path.exists():
                with tempfile.TemporaryDirectory() as tmp:
                    aiff, wav = Path(tmp) / "a.aiff", Path(tmp) / "a.wav"
                    subprocess.run(["say", "-v", voice, "-o", str(aiff), text], check=True)
                    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1",
                                    str(aiff), str(wav)], check=True)
                    with wave.open(str(wav)) as w:
                        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
                path.parent.mkdir(parents=True, exist_ok=True)
                np.save(path, data.astype(np.float32) / 32768)
            out.append({"lang": "en", "intended": intended, "said": text, "voice": f"macOS {voice}",
                        "samples": np.load(path)})
    return out


def run(args) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    langs = args.langs.split(",")
    engine = asr.LocalWhisper()
    rows = []
    for lang in langs:
        clips = (synth_igbo() if lang == "ig" else synth_mms(lang)) + (synth_say() if lang == "en" else [])
        for i, clip in enumerate(clips):
            base = pad(clip["samples"])
            for name, snr in (("clean", None), ("snr10", 10), ("snr5", 5)):
                samples = base if snr is None else with_noise(base, snr, seed=i)
                t0 = time.monotonic()
                text = engine.transcribe(wav_bytes(samples), lang)
                rows.append({"lang": lang, "intended": clip["intended"], "said": clip["said"],
                             "voice": clip["voice"], "condition": name, "transcript": text,
                             "looped": asr.looped(text), "seconds": round(time.monotonic() - t0, 2)})
                print(f"{lang} {clip['voice']:22} {clip['intended']:5} {name:6} -> {text[:50]!r}", flush=True)
    transcripts = out / "transcripts.jsonl"
    with open(transcripts, "w") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    score(out)


def score(out: Path) -> None:
    """The app's rules decide: right, wrong or unclear (app/test_tool/score_answers_test.dart)."""
    out = out.resolve()  # the Dart scorer runs in app/
    # Score what the app receives: the server turns a looping transcript into "heard nothing".
    seen = out / "as_app_receives.jsonl"
    with open(seen, "w") as f:
        for line in open(out / "transcripts.jsonl"):
            r = json.loads(line)
            r["transcript_raw"], r["transcript"] = r["transcript"], "" if asr.looped(r["transcript"]) else r["transcript"]
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    env = {**os.environ, "ANSWERS_IN": str(seen), "ANSWERS_OUT": str(out / "scored.jsonl")}
    flutter = os.environ.get("FLUTTER", str(Path.home() / "development/flutter/bin/flutter"))
    subprocess.run([flutter, "test", "test_tool/score_answers_test.dart"], cwd=ROOT / "app", env=env,
                   check=True, stdout=subprocess.DEVNULL)
    rows = [json.loads(line) for line in open(out / "scored.jsonl")]
    summary: dict = {}
    for r in rows:
        kind = "letters" if r["intended"] in "ABCD" else ("yes/no" if r["intended"] in ("yes", "no") else "true/false")
        key = f"{r['lang']}/{r['condition']}"
        s = summary.setdefault(key, {}).setdefault(kind, {"right": 0, "wrong": 0, "unclear": 0})
        s[r["outcome"]] += 1
    (out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    lines = ["| Language / condition | Letters A–D right (wrong) | Yes/no right (wrong) | True/false right (wrong) |",
             "|---|---|---|---|"]
    for key, kinds in summary.items():
        cells = []
        for kind in ("letters", "yes/no", "true/false"):
            s = kinds.get(kind, {"right": 0, "wrong": 0, "unclear": 0})
            n = sum(s.values())
            cells.append(f"{s['right']}/{n} ({s['wrong']})")
        lines.append(f"| {key} | " + " | ".join(cells) + " |")
    (out / "summary.md").write_text("# Quiz-answer recognition (synthetic voices)\n\n"
                                    "Right / clips, and in brackets how many were taken for a different answer.\n\n"
                                    + "\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--langs", default="en,ha,yo,ig")
    p.add_argument("--out", required=True)
    p.add_argument("--rescore", action="store_true", help="score --out/transcripts.jsonl again (after rule changes)")
    a = p.parse_args()
    score(Path(a.out)) if a.rescore else run(a)
