"""The WhatsApp conversation (design canvas, boards W1–W5): 18+ only, photo in, the page read
exactly as printed out (text, then a voice note), and the Ibà quick check for a call-back.

- W1 Language list, then the age check (buttons). Wording: content/whatsapp/<lang>.json
  (Hausa, Yorùbá, Igbo are drafts pending native review).
- W2 Under 18: one reply, one goodbye, then nothing is processed (photos are never fetched).
- W3 A photo: read with the strictest checks (the health and money second pass, whatever the
  paper), sent as numbered lines with "[unclear number]" where a number isn't reliable, the
  warnings, then a voice note, then Read again / Health worker / Help. Never explained.
- W4 The Ibà quick check: Ibà's questions (or the danger-sign fallback), blind-user wording,
  "I can't tell" on every question, sent to Ibà as unanswered. A danger sign answered Yes
  ends the check with the emergency message at once.
- W5 The call-back request is logged with a reference (wa_store). OK / Change my number /
  Cancel the call.

Privacy: no message text and no phone number is logged; users appear in logs as the first
8 characters of a keyed hash. Triage answers live in memory until the check ends.
"""
from __future__ import annotations

import json
import logging
import os
import re
from dataclasses import dataclass
from functools import lru_cache
from typing import Awaitable, Callable

import httpx
from starlette.concurrency import run_in_threadpool

from . import language, safety, triage, tts, wa_store as store
from .iba_client import IbaClient
from .messages import ENGLISH
from .placeholders import content_dir
from .wa_client import WhatsAppClient, WhatsAppError

log = logging.getLogger("magana.whatsapp")

LANGS = ("en", "ha", "yo", "ig")
NUMBER_CODES = {"unreadable_number", "low_confidence_number", "number_mismatch"}
# Below the hard limit, keep a few messages for people already mid-conversation: new photos
# and checks get "limit reached" instead.
SOFT_MARGIN = 50
_reading: set[str] = set()


@lru_cache(maxsize=None)
def strings(lang: str) -> dict:
    return json.loads((content_dir() / "whatsapp" / f"{lang}.json").read_text(encoding="utf-8"))


def t(lang: str, key: str, **values) -> str:
    text = strings(lang).get(key) or strings("en")[key]
    return text.format(**values) if values else text


def app_text(lang: str, code: str) -> str:
    """The app's own wording for a message code (synced by scripts/sync_whatsapp_text.py)."""
    return strings(lang)["app"].get(code) or strings("en")["app"].get(code) or ENGLISH[code]


def _norm(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s'’-]", " ", text.lower())).strip()


def command(lang: str, text: str) -> str | None:
    said = _norm(text)
    for lang_ in {lang, "en"}:
        for name, words in strings(lang_)["commands"].items():
            if said in {_norm(w) for w in words}:
                return name
    return None


@dataclass
class Inbound:
    wa_id: str
    kind: str   # text | button | image | other
    value: str  # text body, button id or media id


def parse(msg: dict) -> Inbound:
    kind = msg.get("type")
    wa_id = msg.get("from", "")
    if kind == "text":
        return Inbound(wa_id, "text", msg.get("text", {}).get("body", ""))
    if kind == "interactive":
        i = msg.get("interactive", {})
        reply = i.get("button_reply") or i.get("list_reply") or {}
        return Inbound(wa_id, "button", reply.get("id", ""))
    if kind == "image":
        return Inbound(wa_id, "image", msg.get("image", {}).get("id", ""))
    if kind == "document" and str(msg.get("document", {}).get("mime_type", "")).startswith("image/"):
        return Inbound(wa_id, "image", msg["document"].get("id", ""))
    return Inbound(wa_id, "other", "")


# ---------- reading a photo (the same checks as /read in health mode)

def read_photo(data: bytes, engine) -> dict | None:
    """Lines, warnings and faint regions for a photo held in memory; None if it won't open."""
    import io

    from PIL import Image

    from .reader import SECOND_PASS_SCALE, read_page

    try:
        image = Image.open(io.BytesIO(data))
        image.load()
    except Exception:
        return None
    result = read_page(image, engine, second_pass=True)
    warnings = (safety.confidence_warnings(result["lines"]) + safety.number_warnings(result["lines"])
                + safety.line_end_warnings(result["lines"]))
    if "second_pass" in result:
        warnings += safety.number_mismatches(result, result.pop("second_pass"), scale=SECOND_PASS_SCALE)[0]
    return {"lines": result["lines"], "warnings": [w.__dict__ for w in warnings],
            "faint_regions": result.get("faint_regions", [])}


def reading_messages(lang: str, result: dict) -> tuple[list[str], list[tuple[str, str | None]]]:
    """(the text messages, the voice note's lines as (line text, warning key or None))."""
    lines = result["lines"]
    codes: dict[int, list[str]] = {}
    unclear: dict[int, set[int]] = {}
    for w in result["warnings"]:
        codes.setdefault(w["block_index"], []).append(w["code"])
        if w["code"] in NUMBER_CODES and isinstance(w.get("word_index"), int):
            unclear.setdefault(w["block_index"], set()).add(w["word_index"])
    marker = t(lang, "unclear_number")
    shown, voice, warnings = [], [], []
    for i, line in enumerate(lines):
        words = [w["text"] for w in line.get("words") or []] or line["text"].split()
        text = " ".join(marker if j in unclear.get(i, ()) else w for j, w in enumerate(words))
        shown.append(f"{i + 1}. {text}")
        c = codes.get(i, [])
        key = ("number" if any(x in NUMBER_CODES for x in c) else "line_end" if "line_end_unclear" in c
               else "unsure" if c else None)
        if key:
            warnings.append(t(lang, f"warn_{key}", line=i + 1))
        said = " ".join(spoken_unclear if j in unclear.get(i, ()) else w for j, w in enumerate(words))
        voice.append((said, key))
    header = t(lang, "page_header_one") if len(lines) == 1 else t(lang, "page_header", count=len(lines))
    messages = _chunks(header, shown)
    if warnings:
        messages.append("\n\n".join(warnings))
    for region in result.get("faint_regions", []):
        messages.append(t(lang, "faint", where=t(lang, f"where_{region.get('where', 'middle')}")))
    return messages, voice


spoken_unclear = "[unclear number]"  # spoken.for_voice says it as "unclear number"


def _chunks(header: str, lines: list[str], limit: int = 3800) -> list[str]:
    out, cur = [], header
    for line in lines:
        if len(cur) + len(line) + 1 > limit:
            out.append(cur)
            cur = line
        else:
            cur += "\n" + line
    out.append(cur)
    return out


# ---------- the conversation

class Flow:
    def __init__(self, client: WhatsAppClient, ocr_engine: Callable[[], object], voice=None,
                 iba: Callable[[], IbaClient | None] = IbaClient.from_env,
                 alert: Callable[[str], None] | None = None):
        self.client = client
        self.ocr_engine = ocr_engine
        self.voice = voice if voice is not None else tts.default_voice()
        self.iba = iba
        self.alert = alert or _alert

    # -- sending, counted against the month's free messages

    async def _send(self, make: Callable[[], Awaitable[None]], emergency: bool = False) -> bool:
        if store.sent_this_month() >= store.monthly_limit() and not emergency:
            log.warning("whatsapp monthly limit reached: message not sent")
            return False
        try:
            await make()
        except WhatsAppError as e:
            log.error("whatsapp send failed: %s", e)
            return False
        total, first = store.count_sent()
        if first:
            self.alert(f"Magana WhatsApp: {total} of {store.monthly_limit()} free messages used this month.")
        return True

    async def text(self, to: str, body: str, emergency: bool = False) -> bool:
        return await self._send(lambda: self.client.text(to, body), emergency)

    async def buttons(self, to: str, body: str, buttons: list[tuple[str, str]]) -> bool:
        return await self._send(lambda: self.client.buttons(to, body, buttons))

    async def options(self, to: str, body: str, button: str, section: str, rows: list[tuple[str, str]]) -> bool:
        return await self._send(lambda: self.client.list(to, body, button, section, rows))

    def near_limit(self) -> bool:
        return store.sent_this_month() >= store.monthly_limit() - SOFT_MARGIN

    # -- entry point

    async def handle(self, msg: dict) -> None:
        m = parse(msg)
        if not m.wa_id:
            return
        log.info("whatsapp in kind=%s user=%s", m.kind, store.user_key(m.wa_id)[:8])
        profile = store.get_profile(m.wa_id)
        if profile.get("age") == "under_18":
            # W2: one goodbye, then nothing is processed.
            if not profile.get("goodbye_sent"):
                store.set_profile(m.wa_id, goodbye_sent=True)
                await self.text(m.wa_id, t(profile.get("lang", "en"), "under_18_goodbye"))
            return
        s = store.session(m.wa_id)
        lang = profile.get("lang")

        if m.kind == "button" and m.value.startswith("lang:") and m.value[5:] in LANGS:
            await self.set_language(m.wa_id, m.value[5:], profile)
            return
        if lang is None:
            await self.ask_language(m.wa_id, "en", first=True)
            return
        if m.kind == "text" and command(lang, m.value) == "language":
            await self.ask_language(m.wa_id, lang)
            return
        if profile.get("age") is None:
            await self.age(m, lang)
            return

        # An adult with a language from here on.
        if m.kind == "button":
            await self.button(m.wa_id, lang, s, m.value)
        elif m.kind == "image":
            if s.step == "triage":
                await self.ask_question(m.wa_id, lang, s)  # finish the check first
            else:
                await self.read(m.wa_id, lang, s, m.value)
        elif m.kind == "text":
            await self.typed(m.wa_id, lang, s, m.value)
        else:
            await self.text(m.wa_id, t(lang, "send_a_photo"))

    # -- W1, W2

    async def ask_language(self, wa: str, lang: str, first: bool = False) -> None:
        store.session(wa).step = "language"
        rows = [(f"lang:{code}", strings(code)["language_name"]) for code in LANGS]
        body = t(lang, "greeting") if first else t(lang, "language_question")
        await self.options(wa, body, t(lang, "choose_language"), t(lang, "language_section"), rows)

    async def set_language(self, wa: str, lang: str, profile: dict) -> None:
        store.set_profile(wa, lang=lang)
        store.session(wa).step = None
        if profile.get("age") == "adult":
            await self.text(wa, t(lang, "language_set"))
            return
        await self.buttons(wa, t(lang, "language_set") + "\n\n" + t(lang, "age_question"),
                           [("age:yes", t(lang, "btn_age_yes")), ("age:no", t(lang, "btn_age_no"))])

    async def age(self, m: Inbound, lang: str) -> None:
        if m.kind == "button" and m.value == "age:yes":
            store.set_profile(m.wa_id, age="adult")
            await self.text(m.wa_id, t(lang, "adult_ready"))
        elif m.kind == "button" and m.value == "age:no":
            store.set_profile(m.wa_id, age="under_18")  # stored only as "under 18"
            store.clear_session(m.wa_id)
            await self.text(m.wa_id, t(lang, "under_18"))
        else:
            await self.buttons(m.wa_id, t(lang, "age_question"),
                               [("age:yes", t(lang, "btn_age_yes")), ("age:no", t(lang, "btn_age_no"))])

    # -- buttons and typed words

    async def button(self, wa: str, lang: str, s: store.Session, value: str) -> None:
        if value.startswith("t:") and s.step == "triage":
            await self.answer(wa, lang, s, value)
        elif value == "act:read_again":
            await self.read_again(wa, lang, s)
        elif value == "act:health":
            await self.start_check(wa, lang, s)
        elif value == "act:help":
            await self.text(wa, t(lang, "help_text"))
        elif value.startswith("cb:"):
            await self.callback_button(wa, lang, s, value)
        else:
            await self.text(wa, t(lang, "send_a_photo"))

    async def typed(self, wa: str, lang: str, s: store.Session, text: str) -> None:
        if s.step == "phone":
            await self.change_number(wa, lang, s, text)
            return
        name = command(lang, text)
        if s.step == "triage" and name is None:
            await self.ask_question(wa, lang, s)  # answer with the buttons
        elif name == "help":
            await self.text(wa, t(lang, "help_text"))
        elif name == "health_worker":
            await self.start_check(wa, lang, s)
        elif name == "read_again":
            await self.read_again(wa, lang, s)
        else:
            await self.text(wa, t(lang, "send_a_photo"))

    # -- W3: reading a page

    async def read(self, wa: str, lang: str, s: store.Session, media_id: str) -> None:
        key = store.user_key(wa)
        if key in _reading:
            await self.text(wa, t(lang, "busy"))
            return
        if self.near_limit():
            await self.text(wa, t(lang, "limit_reached"))
            return
        _reading.add(key)
        try:
            await self.text(wa, t(lang, "got_page"))
            try:
                data = await self.client.download(media_id)
            except WhatsAppError:
                await self.text(wa, t(lang, "unreadable_photo"))
                return
            result = await run_in_threadpool(read_photo, data, self.ocr_engine())
            del data  # the photo is gone: it only ever lived in memory
            if result is None:
                await self.text(wa, t(lang, "unreadable_photo"))
                return
            if not result["lines"]:
                await self.text(wa, t(lang, "no_text"))
                for region in result.get("faint_regions", []):
                    await self.text(wa, t(lang, "faint", where=t(lang, f"where_{region.get('where', 'middle')}")))
                return
            messages, voice_lines = reading_messages(lang, result)
            for body in messages:
                await self.text(wa, body)
            voice_id = await self.voice_note(wa, lang, s, voice_lines)
            s.last_reading = {"messages": messages, "voice_id": voice_id}
            await self.after_reading(wa, lang)
        finally:
            _reading.discard(key)

    async def voice_note(self, wa: str, lang: str, s: store.Session, voice_lines) -> str | None:
        """The reading as a voice note in the chosen language, or None (with a word why)."""
        if not self.voice.available(lang):
            if not s.voice_told:
                s.voice_told = True
                await self.text(wa, t(lang, "voice_not_ready"))
            return None
        page = " ".join(text for text, _ in voice_lines)
        scores = language.scores(page)
        page_lang = max(scores, key=scores.get) if max(scores.values()) >= language.MIN_POINTS else "en"
        if not self.voice.available(page_lang):
            page_lang = "en"
        segments = [tts.Segment(lang, t(lang, "voice_intro"))]
        for text, warn in voice_lines:
            segments.append(tts.Segment(page_lang, text))
            if warn:
                segments.append(tts.Segment(lang, t(lang, f"voice_warn_{warn}")))
        segments.append(tts.Segment(lang, t(lang, "voice_outro")))
        try:
            ogg = await run_in_threadpool(tts.voice_note, self.voice, segments)
            media_id = await self.client.upload_voice(ogg)
        except tts.VoiceUnsafe:
            await self.text(wa, t(lang, "voice_unsafe"))
            return None
        except WhatsAppError as e:
            log.error("whatsapp voice upload failed: %s", e)
            return None
        await self._send(lambda: self.client.voice(wa, media_id))
        return media_id

    async def after_reading(self, wa: str, lang: str) -> None:
        await self.buttons(wa, t(lang, "after_reading"), [
            ("act:read_again", t(lang, "btn_read_again")),
            ("act:health", t(lang, "btn_health_worker")),
            ("act:help", t(lang, "btn_help")),
        ])

    async def read_again(self, wa: str, lang: str, s: store.Session) -> None:
        if not s.last_reading:
            await self.text(wa, t(lang, "read_again_expired"))
            return
        for body in s.last_reading["messages"]:
            await self.text(wa, body)
        if s.last_reading.get("voice_id"):
            media_id = s.last_reading["voice_id"]
            await self._send(lambda: self.client.voice(wa, media_id))
        await self.after_reading(wa, lang)

    # -- W4: the Ibà quick check

    async def start_check(self, wa: str, lang: str, s: store.Session) -> None:
        if self.near_limit():
            await self.text(wa, t(lang, "limit_reached"))
            return
        questions, _source = await triage.questions(lang, self.iba())
        s.step = "triage"
        s.triage = {"questions": questions, "i": 0, "answers": {}}
        await self.text(wa, t(lang, "triage_intro"))
        await self.ask_question(wa, lang, s)

    def _current(self, s: store.Session) -> dict | None:
        tri = s.triage
        qs = tri["questions"]
        while tri["i"] < len(qs):
            q = qs[tri["i"]]
            depends = q.get("ask_if")
            if depends and tri["answers"].get(depends) is not True:
                tri["i"] += 1
                continue
            if q.get("type") not in ("yes_no", "number"):
                tri["answers"][q["id"]] = None  # not askable here: unanswered, never "no"
                tri["i"] += 1
                continue
            return q
        return None

    async def ask_question(self, wa: str, lang: str, s: store.Session) -> None:
        q = self._current(s)
        if q is None:
            await self.finish_check(wa, lang, s)
            return
        wording = q.get("text") or app_text(lang, q["message"])
        body = t(lang, "question_of", i=s.triage["i"] + 1, n=len(s.triage["questions"])) + "\n" + wording
        if q["type"] == "number":
            rows = [(f"t:n:{n}", t(lang, "day_1") if n == 1 else t(lang, "day_n", n=n)) for n in range(1, 7)]
            rows += [("t:n:7", t(lang, "day_7_or_more")), ("t:cant", t(lang, "btn_cant_tell"))]
            await self.options(wa, body, t(lang, "choose_days"), t(lang, "days_section"), rows)
        else:
            await self.buttons(wa, body, [("t:yes", t(lang, "btn_yes")), ("t:no", t(lang, "btn_no")),
                                          ("t:cant", t(lang, "btn_cant_tell"))])

    async def answer(self, wa: str, lang: str, s: store.Session, value: str) -> None:
        q = self._current(s)
        if q is None:
            await self.finish_check(wa, lang, s)
            return
        if value == "t:cant":
            answer = triage.CANT_TELL  # never "no": Ibà gets it as unanswered
        elif q["type"] == "yes_no" and value in ("t:yes", "t:no"):
            answer = value == "t:yes"
        elif q["type"] == "number" and value.startswith("t:n:") and value[4:].isdigit():
            answer = int(value[4:])
        else:
            await self.ask_question(wa, lang, s)
            return
        s.triage["answers"][q["id"]] = answer
        s.triage["i"] += 1
        if q["id"] in triage.DANGER_SIGNS and answer is True:
            await self.finish_check(wa, lang, s, danger=True)  # don't make them answer the rest
            return
        if q["id"] in triage.DANGER_SIGNS and answer == triage.CANT_TELL:
            await self.text(wa, t(lang, "cant_tell_noted"))
        await self.ask_question(wa, lang, s)

    async def finish_check(self, wa: str, lang: str, s: store.Session, danger: bool = False) -> None:
        answers = s.triage.get("answers", {})
        s.step, s.triage = None, {}  # the answers leave memory with this check
        result = await triage.assess(answers, self.iba())
        del answers
        emergency = result.priority is triage.Priority.EMERGENCY
        if emergency:
            await self.text(wa, "🚨 " + app_text(lang, result.message), emergency=True)
        elif not danger:
            await self.text(wa, t(lang, "last_question"))
        ref = await self.log_callback(wa, lang, result.priority.value)
        s.callback_ref = ref
        body = (t(lang, "callback_ref", ref=ref) if emergency
                else app_text(lang, result.message) + "\n\n" + t(lang, "keep_phone_near"))
        await self.buttons(wa, body, [("cb:ok", t(lang, "btn_ok")), ("cb:change", t(lang, "btn_change_number")),
                                      ("cb:cancel", t(lang, "btn_cancel_call"))])

    # -- W5: the call-back request

    async def log_callback(self, wa: str, lang: str, priority: str) -> str:
        phone = "+" + wa.lstrip("+")
        ref = store.add_callback(phone, lang, priority)
        url = os.environ.get("MAGANA_CALLBACK_URL", "").strip()
        if url:  # the nurse desk, once connected; the local queue is kept either way
            try:
                async with httpx.AsyncClient(timeout=3) as c:
                    r = await c.post(url, json={"reference": ref, "phone": phone, "language": lang,
                                                "priority": priority, "reason": "other", "channel": "whatsapp"})
                    r.raise_for_status()
            except httpx.HTTPError as e:
                log.error("callback desk failed: %s", type(e).__name__)
        log.info("callback logged ref=%s priority=%s channel=whatsapp", ref, priority)
        return ref

    async def callback_button(self, wa: str, lang: str, s: store.Session, value: str) -> None:
        ref = s.callback_ref
        if not ref:
            await self.text(wa, t(lang, "callback_expired"))
            return
        if value == "cb:ok":
            await self.text(wa, t(lang, "callback_ref", ref=ref))
        elif value == "cb:change":
            s.step = "phone"
            await self.text(wa, t(lang, "ask_number"))
        elif value == "cb:cancel":
            ok = store.update_callback(ref, status="cancelled")
            s.callback_ref = None
            await self.text(wa, t(lang, "call_cancelled" if ok else "callback_expired"))

    async def change_number(self, wa: str, lang: str, s: store.Session, text: str) -> None:
        number = nigerian_number(text)
        if number is None:
            await self.text(wa, t(lang, "bad_number"))
            return
        s.step = None
        if s.callback_ref and store.update_callback(s.callback_ref, phone=number):
            await self.text(wa, t(lang, "number_changed", number=number) + "\n" + t(lang, "callback_ref", ref=s.callback_ref))
        else:
            await self.text(wa, t(lang, "callback_expired"))


def nigerian_number(text: str) -> str | None:
    """"0803 123 4567" or "+234 803 123 4567" → "+2348031234567"; None if not a Nigerian mobile."""
    digits = re.sub(r"[\s\-().]", "", text.strip())
    if re.fullmatch(r"0[789][01]\d{8}", digits):
        return "+234" + digits[1:]
    if re.fullmatch(r"\+?234[789][01]\d{8}", digits):
        return "+" + digits.lstrip("+")
    return None


def _alert(text: str) -> None:
    from .iba_monitor import _post_webhook

    log.warning(text)
    _post_webhook(text)


async def process(flow: Flow, messages: list[dict]) -> None:
    """Handle one webhook delivery's messages, one at a time per delivery."""
    for msg in messages:
        try:
            await flow.handle(msg)
        except Exception as e:  # never let one message break the next; no text, no traceback
            log.error("whatsapp message failed kind=%s error=%s", msg.get("type"), type(e).__name__)
