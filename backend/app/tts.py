"""Voice notes for WhatsApp: the reading, said aloud, as an OGG/Opus file.

WHATSAPP_VOICE selects the engine:
- off  (default) no voice note; the text message, which is exact, is the reading
- mms  Meta's MMS voices on CPU (requirements-asr.txt: torch, transformers, soundfile).
       English (eng), Hausa (hau) and Yorùbá (yor). There is no MMS Igbo voice. Licence:
       CC BY-NC 4.0 (non-commercial; docs/MODELS.md). Two voices take about 0.8 GB of
       memory (docs/FINDINGS.md), so they are off on the t3.small.

Safety (CLAUDE.md rule 1): the voices can't say most digits, so every segment goes through
spoken.for_voice, which spells numbers out and refuses text with any character the voice
would skip. One refused segment means no voice note at all, never a voice note with a
number missing.
"""
from __future__ import annotations

import io
import os
from dataclasses import dataclass
from functools import lru_cache

from . import spoken

VOICES = {"en": "facebook/mms-tts-eng", "ha": "facebook/mms-tts-hau", "yo": "facebook/mms-tts-yor"}
PAUSE_S = 0.45


@dataclass(frozen=True)
class Segment:
    lang: str  # whose voice says it
    text: str


class VoiceUnsafe(Exception):
    """A segment holds something the voice can't say: send no voice note."""


class NoVoice:
    """WHATSAPP_VOICE=off."""

    def available(self, lang: str) -> bool:
        return False

    def vocab(self, lang: str) -> set[str]:
        return set()

    def synthesize(self, lang: str, text: str):  # pragma: no cover - never called
        raise RuntimeError("voice notes are off")

    sample_rate = 16000


class MmsVoice:
    """MMS-TTS (VITS) on CPU, one model per language, loaded on first use."""

    sample_rate = 16000

    def available(self, lang: str) -> bool:
        return lang in VOICES

    @lru_cache(maxsize=4)
    def _model(self, lang: str):
        from transformers import AutoTokenizer, VitsModel

        return VitsModel.from_pretrained(VOICES[lang]).eval(), AutoTokenizer.from_pretrained(VOICES[lang])

    def vocab(self, lang: str) -> set[str]:
        return {t for t in self._model(lang)[1].get_vocab() if len(t) == 1}

    def synthesize(self, lang: str, text: str):
        import torch

        model, tok = self._model(lang)
        with torch.no_grad():
            return model(**tok(text, return_tensors="pt")).waveform[0].numpy()


def default_voice():
    return MmsVoice() if os.environ.get("WHATSAPP_VOICE", "off").lower() == "mms" else NoVoice()


def prepare(voice, segments: list[Segment]) -> list[tuple[str, str]]:
    """Each segment as its voice will say it. Raises VoiceUnsafe if any can't be said whole."""
    out = []
    for s in segments:
        if not voice.available(s.lang):
            raise VoiceUnsafe(f"no {s.lang} voice")
        said = spoken.for_voice(s.text, voice.vocab(s.lang))
        if said is None:
            raise VoiceUnsafe("unsayable text")
        out.append((s.lang, said))
    return out


def voice_note(voice, segments: list[Segment]) -> bytes:
    """One OGG/Opus voice note (what WhatsApp plays as a voice message). Raises VoiceUnsafe."""
    import numpy as np
    import soundfile as sf

    said = prepare(voice, segments)
    pause = np.zeros(int(PAUSE_S * voice.sample_rate), dtype="float32")
    audio = []
    for lang, text in said:
        audio += [voice.synthesize(lang, text).astype("float32"), pause]
    buf = io.BytesIO()
    sf.write(buf, np.concatenate(audio), voice.sample_rate, format="OGG", subtype="OPUS")
    return buf.getvalue()
