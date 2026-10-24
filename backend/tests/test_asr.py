"""/asr: engine selection, the device fallback, limits; audio is never stored."""
import io
import math
import struct
import wave

import pytest
from fastapi.testclient import TestClient

from app import asr
from app.main import app, get_asr_engine

client = TestClient(app)


def wav(seconds: float = 1.0, rate: int = 16000) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(8000 * math.sin(i / 20))) for i in range(int(rate * seconds))))
    return buf.getvalue()


@pytest.fixture
def engine():
    def install(e):
        app.dependency_overrides[get_asr_engine] = lambda: e
    yield install
    app.dependency_overrides.clear()


class Echo:
    name = "fake"

    def __init__(self):
        self.calls = []

    def transcribe(self, audio, lang):
        self.calls.append((len(audio), lang))
        return " option B "


def test_device_only_by_default_so_the_app_uses_the_phone():
    assert isinstance(asr.default_engine(), asr.DeviceOnly)
    r = client.post("/asr", files={"file": ("a.wav", wav())}, data={"lang": "ha"})
    assert (r.status_code, r.json()["detail"]) == (503, {"code": "asr_unavailable"})


def test_transcribes_in_the_requested_language(engine):
    e = Echo()
    engine(e)
    r = client.post("/asr", files={"file": ("a.wav", wav())}, data={"lang": "yo"})
    assert r.json() == {"text": "option B", "engine": "fake"}
    assert e.calls[0][1] == "yo"


def test_unknown_language_and_long_audio_are_refused(engine):
    engine(Echo())
    assert client.post("/asr", files={"file": ("a.wav", wav())}, data={"lang": "fr"}).status_code == 422
    assert client.post("/asr", files={"file": ("a.wav", b"x" * 2_000_001)}, data={"lang": "en"}).status_code == 413


def test_each_language_has_its_ncair1_model():
    assert asr.MODELS == {"ha": "NCAIR1/Hausa-ASR", "yo": "NCAIR1/Yoruba-ASR", "ig": "NCAIR1/Igbo-ASR",
                          "en": "NCAIR1/NigerianAccentedEnglish"}
    assert asr.WHISPER_LANGUAGE["ig"] is None  # Whisper has no Igbo token


def test_decode_resamples_to_16k_mono_and_caps_length():
    pytest.importorskip("soundfile")
    samples = asr.decode(wav(seconds=2, rate=8000))
    assert abs(len(samples) - 32000) <= 1
    assert len(asr.decode(wav(seconds=31))) == 16000 * 30


def test_engine_selection(monkeypatch):
    monkeypatch.setenv("ASR_ENGINE", "local")
    assert isinstance(asr.default_engine(), asr.LocalWhisper)
    monkeypatch.setenv("ASR_ENGINE", "cloud")
    with pytest.raises(RuntimeError):
        asr.default_engine()


class Looping(Echo):
    def transcribe(self, audio, lang):
        return "ụgbọ n'akụkụ eti, ụgbọ nwere ụlọ ụlọ ụlọ ụlọ ụlọ ụlọ ụlọ ụlọ"


def test_a_transcript_that_loops_counts_as_heard_nothing(engine):
    engine(Looping())
    r = client.post("/asr", files={"file": ("a.wav", wav())}, data={"lang": "ig"})
    assert r.json() == {"text": "", "engine": "fake"}


@pytest.mark.parametrize("text, loops", [
    ("ndị ahụrụma mere ka ndị ahụrụma mere ka ndị ahụrụma mere ka ndị ahụrụma mere ka", True),
    ("akụkọ akụkọ akụkọ akụkọ", True),
    ("B", False),
    ("bẹ́ẹ̀ni bẹ́ẹ̀ni", False),  # said twice is still an answer
    ("no no no", False),
    ("the hospital has followed protocols for infection control", False),
])
def test_looped(text, loops):
    assert asr.looped(text) is loops
