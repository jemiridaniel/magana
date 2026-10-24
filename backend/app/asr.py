"""Speech recognition for short answers and commands, with NCAIR1's Whisper models.

ASR_ENGINE selects it (docs/MODELS.md):
- device  no server ASR (the default): /asr answers asr_unavailable and the app uses the
          phone's own speech recognition
- local   NCAIR1/Hausa-ASR, Yoruba-ASR, Igbo-ASR and NigerianAccentedEnglish (Whisper Small,
          fp32, about 1 GB each) on this server's CPU; needs requirements-asr.txt. One model is
          kept in memory at a time.

Audio is decoded in memory and never stored, like page photos (CLAUDE.md rule 5).
"""
from __future__ import annotations

import io
import os
from typing import Protocol

MODELS = {
    "ha": "NCAIR1/Hausa-ASR",
    "yo": "NCAIR1/Yoruba-ASR",
    "ig": "NCAIR1/Igbo-ASR",
    "en": "NCAIR1/NigerianAccentedEnglish",
}
# Whisper's language names; it has no Igbo token, so Igbo is not forced.
WHISPER_LANGUAGE = {"ha": "hausa", "yo": "yoruba", "en": "english", "ig": None}
SAMPLE_RATE = 16_000
MAX_SECONDS = 30  # Whisper's window; answers and commands are a few seconds


def looped(text: str, times: int = 4, longest: int = 6) -> bool:
    """Whisper sometimes repeats itself in noise ("ụlọ ụlọ ụlọ ụlọ ..."): the same run of up to
    `longest` words `times` times in a row. On the 120 benchmark clips this caught all 5
    loops and nothing else (docs/FINDINGS.md). Such a transcript is not an answer."""
    w = text.lower().split()
    for n in range(1, longest + 1):
        for i in range(len(w) - n * times + 1):
            if all(w[i + k * n:i + (k + 1) * n] == w[i:i + n] for k in range(1, times)):
                return True
    return False


class ASRUnavailable(Exception):
    pass


class ASREngine(Protocol):
    name: str

    def transcribe(self, audio: bytes, lang: str) -> str: ...


class DeviceOnly:
    """No server ASR: the phone's own recogniser is used."""

    name = "device"

    def transcribe(self, audio: bytes, lang: str) -> str:
        raise ASRUnavailable("asr_unavailable")


def decode(audio: bytes):
    """WAV/FLAC/OGG bytes -> 16 kHz mono float32, at most MAX_SECONDS."""
    import numpy as np
    import soundfile as sf

    data, rate = sf.read(io.BytesIO(audio), dtype="float32", always_2d=True)
    mono = data.mean(axis=1)
    if rate != SAMPLE_RATE:  # linear resampling is enough for speech at this length
        n = int(len(mono) * SAMPLE_RATE / rate)
        mono = np.interp(np.linspace(0, len(mono), n, endpoint=False), np.arange(len(mono)), mono)
    return mono[: SAMPLE_RATE * MAX_SECONDS].astype("float32")


class LocalWhisper:
    """The NCAIR1 Whisper Small models on CPU, loaded on first use, one at a time."""

    name = "local"

    def __init__(self):
        self._lang = None
        self._pipe = None

    def _pipeline(self, lang: str):
        if self._lang != lang:
            from transformers import pipeline

            self._pipe = None  # free the previous model first
            self._pipe = pipeline("automatic-speech-recognition", model=MODELS[lang], device="cpu",
                                  token=os.environ.get("HF_TOKEN") or None)
            self._lang = lang
        return self._pipe

    def transcribe(self, audio: bytes, lang: str) -> str:
        samples = decode(audio)
        kwargs = {"task": "transcribe"}
        if WHISPER_LANGUAGE[lang]:
            kwargs["language"] = WHISPER_LANGUAGE[lang]
        out = self._pipeline(lang)({"raw": samples, "sampling_rate": SAMPLE_RATE}, generate_kwargs=kwargs)
        return out["text"].strip()


def default_engine() -> ASREngine:
    kind = os.environ.get("ASR_ENGINE", "device").lower()
    if kind == "device":
        return DeviceOnly()
    if kind == "local":
        return LocalWhisper()
    raise RuntimeError(f"ASR_ENGINE={kind!r}: use device or local")
