"""WhatsApp (design canvas W1–W5): webhook security, the conversation, privacy, limits."""
import asyncio
import hashlib
import hmac
import json
import logging
import re
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import blobs, spoken, triage, tts, wa_flow, wa_store
from app.main import app, get_whatsapp_flow
from app.reader import TesseractEngine

ROOT = Path(__file__).resolve().parents[2]
SMUDGED = Path(__file__).parent / "fixtures" / "misreads" / "dose_smudged_registered.png"
USER = "2348031234567"
SECRET = "test-app-secret"


class FakeClient:
    """Records what Magana would send; serves one photo."""

    def __init__(self, photo: bytes = b""):
        self.sent: list[tuple] = []
        self.photo = photo
        self.downloads = 0
        self.uploads: list[bytes] = []

    async def text(self, to, body):
        self.sent.append(("text", to, body))

    async def buttons(self, to, body, buttons):
        self.sent.append(("buttons", to, body, buttons))

    async def list(self, to, body, button, section, rows):
        self.sent.append(("list", to, body, rows))

    async def upload_voice(self, ogg):
        self.uploads.append(ogg)
        return "media-1"

    async def voice(self, to, media_id):
        self.sent.append(("voice", to, media_id))

    async def download(self, media_id):
        self.downloads += 1
        return self.photo

    def bodies(self):
        return [s[2] for s in self.sent if s[0] in ("text", "buttons", "list")]


class FakeVoice:
    sample_rate = 16000

    def __init__(self, langs=("en", "ha", "yo"), vocab=None):
        self.langs = set(langs)
        self._vocab = vocab or set("abcdefghijklmnopqrstuvwxyzàáèéìíòóùúẹọṣńǹɓɗƙ' -")
        self.said: list[tuple[str, str]] = []

    def available(self, lang):
        return lang in self.langs

    def vocab(self, lang):
        return self._vocab


@pytest.fixture(autouse=True)
def store(tmp_path, monkeypatch):
    monkeypatch.setenv("MAGANA_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("WHATSAPP_APP_SECRET", SECRET)
    monkeypatch.delenv("MAGANA_CALLBACK_URL", raising=False)
    wa_store.clear_sessions()
    wa_flow._reading.clear()
    yield tmp_path
    wa_store.clear_sessions()


@pytest.fixture
def fake_voice_note(monkeypatch):
    """The voice note without encoding audio (soundfile isn't in the production image): the
    safety gate (tts.prepare) still runs on every segment."""
    made = []

    def note(voice, segments):
        made.append(tts.prepare(voice, segments))
        return b"OggS-fake"

    monkeypatch.setattr(tts, "voice_note", note)
    return made


def flow(client, voice=None, iba=lambda: None, alert=None):
    return wa_flow.Flow(client, lambda: TesseractEngine(), voice=voice or FakeVoice(), iba=iba,
                        alert=alert or (lambda text: None))


def say(f, *messages):
    for m in messages:
        asyncio.run(f.handle(m))


def text(body, frm=USER):
    return {"from": frm, "id": f"t-{body}", "type": "text", "text": {"body": body}}


def tap(button_id, frm=USER):
    return {"from": frm, "id": f"b-{button_id}", "type": "interactive",
            "interactive": {"type": "button_reply", "button_reply": {"id": button_id, "title": "x"}}}


def photo(frm=USER):
    return {"from": frm, "id": "p-1", "type": "image", "image": {"id": "media-in", "mime_type": "image/jpeg"}}


def adult(f, lang="en"):
    say(f, text("Hi"), tap(f"lang:{lang}"), tap("age:yes"))


# ---------- W1: language, then age

def test_first_message_offers_the_four_languages_then_asks_the_age_in_that_language():
    c = FakeClient()
    f = flow(c)
    say(f, text("Hi"))
    kind, _, body, rows = c.sent[0]
    assert kind == "list" and "Magana" in body
    assert [r[0] for r in rows] == ["lang:en", "lang:ha", "lang:yo", "lang:ig"]
    say(f, tap("lang:yo"))
    kind, _, body, buttons = c.sent[-1]
    assert kind == "buttons" and "Yorùbá" in body
    assert [b[0] for b in buttons] == ["age:yes", "age:no"]
    say(f, tap("age:yes"))
    assert "PIN" in c.sent[-1][2]
    assert wa_store.get_profile(USER) == {"lang": "yo", "age": "adult"}


# ---------- W2: under 18

def test_under_18_get_one_reply_and_one_goodbye_then_nothing_is_processed():
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c)
    say(f, text("Hi"), tap("lang:en"), tap("age:no"))
    assert "for adults" in c.sent[-1][2]
    say(f, text("ok"))
    assert c.sent[-1][2].startswith("Take care!")
    n = len(c.sent)
    say(f, photo(), text("help"), tap("act:health"), text("language"))
    assert len(c.sent) == n          # nothing more is said
    assert c.downloads == 0          # their photos are never fetched
    assert wa_store.get_profile(USER)["age"] == "under_18"


# ---------- W3: a photo

def test_a_photo_is_read_exactly_with_unclear_number_a_warning_a_voice_note_and_the_three_buttons(fake_voice_note):
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c)
    adult(f)
    say(f, photo())
    bodies = c.bodies()
    assert any("Reading your page" in b for b in bodies)
    page = next(b for b in bodies if b.startswith("*Your page*"))
    assert "Do not take more than [unclear number] in 24 hours" in page
    assert "®" not in page
    assert "PARACETAMOL 500 mg TABLETS" in page
    assert any("couldn’t read a number clearly on line 3" in b for b in bodies)
    assert ("voice", USER, "media-1") in c.sent
    said = " ".join(text for _, text in fake_voice_note[0])
    assert "unclear number in twenty four hours" in said and "five hundred" in said
    assert not re.search(r"\d", said)
    kind, _, _, buttons = c.sent[-1]
    assert [b[0] for b in buttons] == ["act:read_again", "act:health", "act:help"]
    assert c.downloads == 1


def test_read_again_resends_the_same_reading_and_voice_note(fake_voice_note):
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c)
    adult(f)
    say(f, photo())
    first = [s for s in c.sent if s[0] in ("text", "voice")][-3:]
    say(f, tap("act:read_again"))
    assert c.downloads == 1  # not read again from a photo: Magana kept no photo
    assert [s for s in c.sent if s[0] in ("text", "voice")][-3:] == first


def test_read_again_without_a_reading_asks_for_the_photo():
    c = FakeClient()
    f = flow(c)
    adult(f)
    say(f, tap("act:read_again"))
    assert "30 minutes" in c.sent[-1][2]


def test_no_voice_note_when_the_voice_cant_say_every_character(fake_voice_note):
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c, voice=FakeVoice(vocab=set("abcdefghijklmnorstuvwxyz ")))  # no "p"
    adult(f)
    say(f, photo())
    assert not c.uploads and not any(s[0] == "voice" for s in c.sent)
    assert any("text only" in b for b in c.bodies())
    assert any("[unclear number]" in b for b in c.bodies())  # the exact text still goes


def test_igbo_users_hear_once_that_voice_notes_arent_ready(fake_voice_note):
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c)
    adult(f, "ig")
    say(f, photo())
    say(f, photo() | {"id": "p-2"})
    notes = [b for b in c.bodies() if "Ozi olu n'Igbo" in b]
    assert len(notes) == 1 and not c.uploads


def test_photo_is_not_stored_and_logs_hold_no_number_or_text(store, caplog, fake_voice_note):
    caplog.set_level(logging.DEBUG)
    c = FakeClient(SMUDGED.read_bytes())
    f = flow(c)
    adult(f)
    say(f, photo())
    files = set(blobs.names("whatsapp"))
    assert files <= {"profiles.json", "usage.json"}
    stored = "".join(blobs.get_text("whatsapp", n) for n in files)
    assert USER not in stored and "PARACETAMOL" not in stored
    assert not (store / "whatsapp").exists()  # nothing on the server's disk
    logged = caplog.text
    assert USER not in logged and "PARACETAMOL" not in logged and "Hi" not in logged


# ---------- W4, W5: the Ibà quick check and the call-back

def answer_all(f, first, rest="t:no"):
    say(f, tap("act:health"), tap(first))
    for _ in range(len(triage.FALLBACK_QUESTIONS) - 1):
        say(f, tap(rest))


def test_cant_tell_on_a_danger_sign_is_noted_never_no_and_the_call_back_is_logged(store):
    c = FakeClient()
    f = flow(c)
    adult(f)
    answer_all(f, "t:cant")
    bodies = c.bodies()
    assert any("ask someone near you to check" in b for b in bodies)
    assert any(b.startswith("Question 1 of 10") for b in bodies)
    assert any("Blood" in b or "blood" in b for b in bodies)  # sight-based sign in blind-user wording
    assert "That was the last question" in " ".join(bodies)
    kind, _, body, buttons = c.sent[-1]
    assert "Please ask someone near you to check, or go to a clinic." in body  # floor: at least urgent
    assert [b[0] for b in buttons] == ["cb:ok", "cb:change", "cb:cancel"]
    [cb] = wa_store.callbacks()
    assert cb["priority"] == "urgent" and cb["phone"] == "+" + USER and re.fullmatch(r"MG-\d{4}", cb["ref"])
    assert set(cb) == {"ref", "phone", "language", "priority", "channel", "created", "status"}  # no answers
    say(f, tap("cb:ok"))
    assert cb["ref"] in c.sent[-1][2]


def test_a_danger_sign_ends_the_check_with_the_emergency_message_at_once():
    c = FakeClient()
    f = flow(c)
    adult(f)
    say(f, tap("act:health"), tap("t:yes"))
    bodies = c.bodies()
    assert any(b.startswith("🚨 This could be serious") for b in bodies)
    assert not any(b.startswith("Question 2") for b in bodies)
    assert wa_store.callbacks()[0]["priority"] == "emergency"


class FakeIba:
    def __init__(self):
        self.sent = None

    async def questions(self, lang):
        return [{"id": "fever", "type": "yes_no", "text": "Do you have a fever?"},
                {"id": "fever_days", "type": "number", "unit": "days", "ask_if": "fever", "text": "How many days?"},
                {"id": "bleeding", "type": "yes_no", "text": "Do you see blood?"}]

    async def assess(self, answers):
        self.sent = dict(answers)
        return {"priority": "routine", "message": "nurse_call_working_hours", "rule_version": "t"}


def test_ibas_questions_number_as_a_list_sight_wording_and_cant_tell_sent_as_unanswered():
    iba = FakeIba()
    c = FakeClient()
    f = flow(c, iba=lambda: iba)
    adult(f)
    say(f, tap("act:health"), tap("t:yes"))
    kind, _, body, rows = c.sent[-1]
    assert kind == "list" and "How many days?" in body
    assert [r[0] for r in rows][-2:] == ["t:n:7", "t:cant"]
    say(f, tap("t:n:3"))
    assert "Do you see blood?" not in c.sent[-1][2]  # Ibà's sighted wording replaced
    assert "felt or tasted blood" in c.sent[-1][2]
    say(f, tap("t:cant"))
    assert iba.sent == {"fever": True, "fever_days": 3, "bleeding": None}  # never False
    assert "Please ask someone near you to check" in c.sent[-1][2]  # routine raised by the floor


def test_skipped_questions_when_there_is_no_fever():
    iba = FakeIba()
    c = FakeClient()
    f = flow(c, iba=lambda: iba)
    adult(f)
    say(f, tap("act:health"), tap("t:no"))
    assert "felt or tasted blood" in c.sent[-1][2]  # fever_days skipped


def test_change_number_and_cancel():
    c = FakeClient()
    f = flow(c)
    adult(f)
    answer_all(f, "t:no")
    say(f, tap("cb:change"), text("0803 999 1234"))
    assert "+2348039991234" in c.sent[-1][2]
    assert wa_store.callbacks()[0]["phone"] == "+2348039991234"
    say(f, tap("cb:cancel"))
    assert wa_store.callbacks()[0]["status"] == "cancelled"


@pytest.mark.parametrize("typed, number", [
    ("0803 123 4567", "+2348031234567"), ("+234 803 123 4567", "+2348031234567"), ("07012345678", "+2347012345678"),
    ("12345", None), ("0603 123 4567", None),
])
def test_nigerian_numbers(typed, number):
    assert wa_flow.nigerian_number(typed) == number


# ---------- the month's free messages

def test_warns_once_at_the_threshold_and_stops_at_the_limit_except_emergencies(monkeypatch):
    monkeypatch.setattr(wa_store, "WARN_AT", 3)
    monkeypatch.setenv("WHATSAPP_MONTHLY_LIMIT", "60")
    alerts = []
    c = FakeClient()
    f = flow(c, alert=alerts.append)
    adult(f)                                # 3 messages
    say(f, text("help"), text("help"))
    assert len(alerts) == 1 and "3 of 60" in alerts[0]
    monkeypatch.setenv("WHATSAPP_MONTHLY_LIMIT", str(wa_store.sent_this_month()))
    n = len(c.sent)
    say(f, text("help"))
    assert len(c.sent) == n                 # over the limit: not sent
    say(f, tap("act:health"))
    assert len(c.sent) == n                 # nor a new check (it says "limit reached" only below the limit)
    asyncio.run(f.text(USER, "🚨 emergency", emergency=True))
    assert c.sent[-1][2] == "🚨 emergency"  # the emergency message always goes


# ---------- the webhook

def signed(body: dict) -> tuple[bytes, dict]:
    raw = json.dumps(body).encode()
    sig = "sha256=" + hmac.new(SECRET.encode(), raw, hashlib.sha256).hexdigest()
    return raw, {"X-Hub-Signature-256": sig, "Content-Type": "application/json"}


def delivery(*messages):
    return {"object": "whatsapp_business_account",
            "entry": [{"changes": [{"value": {"messages": list(messages)}}]}]}


@pytest.fixture
def webhook(monkeypatch):
    handled = []

    class Recorder:
        async def handle(self, msg):
            handled.append(msg["id"])

    app.dependency_overrides[get_whatsapp_flow] = lambda: Recorder()
    yield TestClient(app), handled
    app.dependency_overrides.clear()


def test_verify_handshake(monkeypatch, webhook):
    client, _ = webhook
    monkeypatch.setenv("WHATSAPP_VERIFY_TOKEN", "tok")
    r = client.get("/whatsapp/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "tok", "hub.challenge": "42"})
    assert r.status_code == 200 and r.text == "42"
    r = client.get("/whatsapp/webhook", params={"hub.mode": "subscribe", "hub.verify_token": "no", "hub.challenge": "42"})
    assert r.status_code == 403


def test_unsigned_or_wrongly_signed_deliveries_are_refused(webhook, monkeypatch):
    client, handled = webhook
    monkeypatch.setenv("MAGANA_API_KEY", "app-key")  # the webhook needs no app key, only Meta's signature
    raw, headers = signed(delivery(text("Hi")))
    assert client.post("/whatsapp/webhook", content=raw, headers={"Content-Type": "application/json"}).status_code == 401
    assert client.post("/whatsapp/webhook", content=raw, headers={**headers, "X-Hub-Signature-256": "sha256=00"}).status_code == 401
    assert handled == []
    assert client.post("/whatsapp/webhook", content=raw, headers=headers).status_code == 200
    assert handled == ["t-Hi"]


def test_a_redelivered_message_is_handled_once(webhook):
    client, handled = webhook
    msg = text("Hi") | {"id": "wamid.unique-1"}
    for _ in range(2):
        raw, headers = signed(delivery(msg))
        client.post("/whatsapp/webhook", content=raw, headers=headers)
    assert handled == ["wamid.unique-1"]


def test_not_configured_is_503(monkeypatch):
    monkeypatch.delenv("WHATSAPP_APP_SECRET")
    raw, headers = signed(delivery(text("Hi")))
    assert TestClient(app).post("/whatsapp/webhook", content=raw, headers=headers).status_code == 503


# ---------- wording

LANGS = ("en", "ha", "yo", "ig")


def _units(s: str) -> int:
    return len(s.encode("utf-16-le")) // 2


@pytest.mark.parametrize("lang", LANGS)
def test_every_language_has_every_string_and_fits_metas_limits(lang):
    en = wa_flow.strings("en")
    s = wa_flow.strings(lang)
    assert set(s) == set(en)
    for key in [k for k in s if k.startswith("btn_")] + ["choose_language", "choose_days"]:
        assert _units(s[key]) <= 20, (key, s[key])
    for key in ("day_1", "day_7_or_more", "language_name", "language_section", "days_section"):
        assert _units(s[key].format(n=6)) <= 24, (key, s[key])
    for key, value in s.items():
        if isinstance(value, str) and not key.startswith("_"):
            assert set(re.findall(r"\{(\w+)\}", value)) == set(re.findall(r"\{(\w+)\}", en[key])), key


@pytest.mark.parametrize("lang", LANGS)
def test_triage_wording_is_the_apps_own(lang):
    arb = json.loads((ROOT / "app" / "lib" / "l10n" / f"app_{lang}.arb").read_text(encoding="utf-8"))
    for code, text in wa_flow.strings(lang)["app"].items():
        assert arb[f"msg_{code}"] == text, f"run scripts/sync_whatsapp_text.py ({lang} {code})"
    for q in triage.FALLBACK_QUESTIONS:
        assert q["message"] in wa_flow.strings(lang)["app"]


@pytest.mark.parametrize("lang", ["ha", "yo"])
def test_magana_sentences_for_the_voice_hold_no_digits(lang):
    for key, value in wa_flow.strings(lang).items():
        if key.startswith("voice_"):
            assert not re.search(r"\d", value), key


# ---------- numbers for the voice

@pytest.mark.parametrize("printed, said", [
    ("8", "eight"), ("24", "twenty four"), ("500", "five hundred"), ("2,350.00", "two thousand three hundred and fifty point zero zero"),
    ("-2,350.00", "minus two thousand three hundred and fifty point zero zero"), ("08", "zero eight"),
    ("1000001", "one million and one"), ("2,000,500", "two million five hundred"), ("PCM2291", "PCM two two nine one"),
    ("[unclear number]", "unclear number"),
])
def test_numbers_are_spelled_exactly(printed, said):
    assert " ".join(spoken.spell_numbers(printed).split()) == said


def test_for_voice_refuses_what_the_voice_would_skip():
    english = set(" '-0123456_abcdefghijklmnopqrstuvwxyz–")
    assert spoken.for_voice("Take 8 tablets.", english) == "take eight tablets"
    assert spoken.for_voice("Ọmọ", english) is None
    assert spoken.for_voice("Take 1/2 tablet", english) == "take one slash two tablet"


# ---------- numbers in Hausa, Yorùbá and Igbo voice notes: English words, or left out

class LangVoice(FakeVoice):
    """A voice per language, each with its own letters (Yorùbá has no c, q, v, x or z)."""

    def __init__(self, vocabs):
        super().__init__(langs=tuple(vocabs))
        self.vocabs = {k: set(v) for k, v in vocabs.items()}

    def vocab(self, lang):
        return self.vocabs[lang]


YO = "abdefghijklmnoprstuwyàáèéìíòóùúẹọṣńǹ' -"
EN = "abcdefghijklmnopqrstuvwxyz' -"


def test_a_yoruba_line_says_its_numbers_in_english_with_the_english_voice():
    parts, dropped = wa_flow.number_segments("Lo tábúlẹ́ẹ̀tì 5 ní ìgbà 3", "yo", "yo", LangVoice({"yo": YO, "en": EN}))
    assert [(p.lang, p.text.strip()) for p in parts] == [
        ("yo", "Lo tábúlẹ́ẹ̀tì"), ("en", "five"), ("yo", "ní ìgbà"), ("en", "three")]
    assert not dropped
    # Never translated number words: no Yorùbá voice ever says a number.
    assert all(p.lang == "en" for p in parts if any(w in p.text for w in ("five", "three")))


def test_amounts_codes_and_english_lines():
    v = LangVoice({"ha": EN, "en": EN})
    parts, _ = wa_flow.number_segments("Sha 500 mg, PCM2291, ₦2,350.00", "ha", "ha", v)
    said = [(p.lang, p.text.strip(" ,")) for p in parts]
    assert ("en", "five hundred") in said
    assert ("en", "two two nine one") in said  # a code, digit by digit
    assert ("en", "two thousand three hundred and fifty point zero zero") in said
    parts, _ = wa_flow.number_segments("Take 2 tablets", "en", "ha", v)
    assert [(p.lang, p.text) for p in parts] == [("en", "Take 2 tablets")]  # English text: as before


def test_a_number_that_cant_be_said_is_left_out_and_the_text_is_the_reference():
    v = LangVoice({"ig": "abcdefghijklmnopqrstuvwxyzịọụṅ' -"})  # no English voice
    parts, dropped = wa_flow.number_segments("Ṅụọ mkpụrụ ọgwụ 2", "ig", "ig", v)
    assert dropped and parts[-1] == tts.Segment("ig", wa_flow.t("ig", "voice_number_left_out"))
    assert not any(ch.isdigit() for p in parts for ch in p.text)


@pytest.mark.parametrize("lang", ["en", "ha", "yo", "ig"])
def test_the_left_out_phrases_have_no_digits(lang):
    for key in ("voice_number_left_out", "voice_numbers_in_text"):
        assert not any(ch.isdigit() for ch in wa_flow.t(lang, key))
