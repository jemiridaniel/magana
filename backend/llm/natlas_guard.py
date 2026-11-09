"""The only way to N-ATLaS (NCAIR1/N-ATLaS). Nothing else in Magana calls the model; a test fails
if anything does (tests/test_natlas_guard.py). docs/LLM_SAFETY.md says why.

An independent audit (Brydl, 3 Nov 2026, v1.1) found N-ATLaS refuses harmful requests in English
but answers them in Hausa. So the model's own refusals are never relied on, in any language:

1. One task: explain_page. The input is the page text Magana read and the learner's language.
   No free-form questions, no chat (what the learner says afterwards is a voice command in the
   app: repeat, slower, next, stop).
2. Before the model: a page about health or medicine, money or payments, or harm, in English,
   Hausa, Yorùbá or Igbo (content/llm_safety/topics.json), or with a line from a health phrase
   template, never reaches it: the app plays "Please ask your teacher".
3. The page's numbers never reach it either: every number is a marker (⟦N1⟧ …), each must come
   back exactly once, and nothing numeric may be added (app/explain.py, placeholders.py).
4. After the model, before anything is spoken: every number must be on the page
   (safety.guard_explanation); no medicine name or dose word (content/llm_safety/
   answer_checks.json); no web address, email or phone number the page doesn't have; no topic
   word the page doesn't have; a length limit. Blocked: the page is read instead, and the reason
   is logged (a code, never the learner's text or the page).
5. The instruction to the model is per language (llm/prompts/<lang>.txt, with a version line). A
   language whose prompt is still a placeholder stays off. NATLAS_ENABLED_LANGS switches a
   language off without an app release. Each call logs the model, its revision, the
   quantisation and the prompt version.

EXPLAIN_ENGINE selects how the model is reached (docs/MODELS.md): stub (no model: the page text,
a preview), vllm or hf_space (an OpenAI-compatible server; EXPLAIN_ADAPTER, the Magana LoRA, for
English only), llamacpp (a llama.cpp server; EXPLAIN_LORA_ID).
"""
from __future__ import annotations

import json
import logging
import os
import re
import time
import unicodedata
from dataclasses import dataclass
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Protocol
from urllib.parse import urlparse

import httpx

from app import explain as text_checks
from app import placeholders, safety, templates

log = logging.getLogger("magana.natlas")

TASK = "explain_page"
TIMEOUT_S = 20.0
TEMPERATURE = 0.1  # the model card's settings
RETRY_TEMPERATURE = 0.0  # one more try, greedy, before the page is read instead
REPETITION_PENALTY = 1.12
# The longest answer spoken for one section of a page (about a minute and a half of speech).
MAX_ANSWER_CHARS = 1_500

PROMPTS = Path(__file__).with_name("prompts")
CONTENT = Path(os.environ.get("MAGANA_CONTENT_DIR", Path(__file__).resolve().parents[2] / "content"))

# Where page text may be sent outside development. Must match docs/MODELS.md, "Approved
# explanation hosts" (a test checks). Kaggle tunnels are never on it.
APPROVED_HOSTS: frozenset[str] = frozenset()

# The Magana LoRA was trained on English only and answers every language in English
# (docs/FINDINGS.md), so it serves English; other languages would go to base N-ATLaS.
ADAPTER_LANGS = frozenset({"en"})


# ---------- what is allowed to run

def deployment() -> str:
    """MAGANA_ENV: development, tester or production. Anything else, or unset, counts as
    production, so a forgotten setting fails safe."""
    env = os.environ.get("MAGANA_ENV", "production").lower()
    return env if env in ("development", "tester", "production") else "production"


def allowed(engine: "Engine") -> bool:
    """In development any engine may be used (Kaggle only with the team's own test pages:
    docs/MODELS.md). In tester and production builds only a real model on an approved host."""
    if deployment() == "development":
        return True
    host = urlparse(getattr(engine, "url", "") or "").hostname or ""
    return not engine.preview and host in APPROVED_HOSTS


@dataclass(frozen=True)
class Prompt:
    lang: str
    version: str
    status: str
    text: str
    guided: str

    def system(self, guided: bool) -> str:
        return self.text + ("\n" + self.guided if guided and self.guided else "")


@lru_cache(maxsize=None)
def prompt(lang: str) -> Prompt | None:
    """The instruction to the model in [lang] (llm/prompts/<lang>.txt): '# version:' and
    '# status:' lines, the rules, then '[guided]' and the rule for 13-17-year-olds. None when
    the file is missing or still a placeholder: that language stays off."""
    path = PROMPTS / f"{lang}.txt"
    if not path.exists():
        return None
    meta, body = {}, []
    for line in path.read_text(encoding="utf-8").splitlines():
        if m := re.match(r"#\s*(version|status):\s*(.*)", line):
            meta[m.group(1)] = m.group(2).strip()
        else:
            body.append(line)
    if meta.get("status", "").startswith("placeholder") or not "".join(body).strip():
        return None
    main, _, guided = "\n".join(body).partition("[guided]")
    return Prompt(lang, meta.get("version", "unversioned"), meta.get("status", ""), main.strip(), guided.strip())


def enabled_languages() -> set[str]:
    """NATLAS_ENABLED_LANGS (comma-separated; EXPLAIN_LANGS, its old name, if unset), English by
    default; only languages with a real prompt. A server setting, so a language that fails the
    nightly evaluation is switched off without an app release."""
    raw = os.environ.get("NATLAS_ENABLED_LANGS", os.environ.get("EXPLAIN_LANGS", "en"))
    return {l.strip() for l in raw.split(",") if l.strip() and prompt(l.strip())}


def model_identity(engine: "Engine") -> dict:
    """Logged with every call: which model, revision, quantisation (server settings)."""
    return {
        "model": getattr(engine, "model", "") or ("stub" if engine.preview else "unknown"),
        "adapter": getattr(engine, "adapter", "") or getattr(engine, "lora_id", None) or "",
        "revision": os.environ.get("NATLAS_MODEL_REVISION", "unknown"),
        "quantisation": os.environ.get("NATLAS_QUANTISATION", "unknown"),
    }


# ---------- before the model: what the page is about

def _fold(s: str) -> str:
    """Lowercase, no tone marks or other accents, hooked letters as plain (OCR often loses them)."""
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.translate(str.maketrans("ɓɗƙƴ'’", "bdky''"))


@lru_cache(maxsize=1)
def _topics() -> dict:
    return json.loads((CONTENT / "llm_safety" / "topics.json").read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def _answer_lists() -> dict:
    return json.loads((CONTENT / "llm_safety" / "answer_checks.json").read_text(encoding="utf-8"))


_NUMBER_SLOT = re.compile(r"(?<![\w])N(?![\w])")


@lru_cache(maxsize=None)
def _dose_patterns(lang: str) -> tuple[re.Pattern, ...]:
    """The dose words of [lang] and English with a number in them, written with N: "every N hours",
    "N-hourly", "N times a day". N is digits (4, 0.5) or a number word of that language
    (content/number_words/), or a range of them ("4 to 6", "4-6"). A space matches any spacing; a
    hyphen may be there or not ("4-hourly", "4 hourly")."""
    from app import placeholders

    numbers = set()
    for code in {lang, "en"}:
        try:
            numbers |= {_fold(w) for w in placeholders.word_list(code).words}
        except FileNotFoundError:
            pass
    numbers |= {"one", "a", "an", "half"}  # English; "one" is ambiguous elsewhere, not here
    one = r"(?:\d+(?:[.,]\d+)?|" + "|".join(sorted(map(re.escape, numbers), key=len, reverse=True)) + ")"
    number = rf"{one}(?:\s*(?:-|–|to|or)\s*{one})?"
    out = []
    for term in _answer_lists()["dose_words"].get(lang, []) + _answer_lists()["dose_words"]["en"]:
        if not _NUMBER_SLOT.search(term):
            continue
        parts = []
        for piece in re.split(r"(\s+|-)", _fold(term)):
            if piece == "n":  # N, lowercased by folding
                parts.append(number)
            elif piece.isspace():
                parts.append(r"\s+")
            elif piece == "-":
                parts.append(r"\s*-?\s*")
            elif piece:
                parts.append(re.escape(piece))
        body = "".join(parts)
        out.append(re.compile(rf"(?<![\w]){body}(?![\w])"))
    return tuple(out)


def _has(folded: str, term: str) -> bool:
    t = _fold(term)
    if not any(ch.isalnum() for ch in t):  # a symbol such as ₦
        return t in folded
    return re.search(rf"(?<![\w]){re.escape(t)}(?![\w])", folded) is not None


def sensitive_topic(page_text: str) -> str | None:
    """'health', 'money' or 'harm' when the page is about it, in any of the four languages (a
    page's language isn't always known); else None. One strong term is enough, or two different
    words of one topic. Also 'health' for a line matching a health phrase template."""
    folded = _fold(page_text)
    for lists in (v for k, v in _topics().items() if not k.startswith("_")):
        for topic, terms in lists.items():
            if any(_has(folded, t) for t in terms["strong"]):
                return topic
            if len({t for t in terms["words"] if _has(folded, t)}) >= 2:
                return topic
    for line in page_text.splitlines():
        if line.strip() and templates.match(line, "ha", "health", {"clinically_approved", "native_reviewed", "draft"}):
            return "health"
    return None


# ---------- after the model: what may be spoken

_URL = re.compile(r"https?://\S+|www\.\S+|\b[\w-]+\.(?:com|ng|org|net|io|info|xyz|gov|edu|co)\b|\S+@\S+\.\w+", re.I)
_PHONE = re.compile(r"\+?\d[\d\s\-()]{6,}\d")
_DIGITS = re.compile(r"\d+(?:[.,]\d+)*")


def answer_problem(answer: str, source: str, lang: str) -> str | None:
    """Why [answer] (numbers already put back) may not be spoken, or None. Never the text."""
    if len(answer) > MAX_ANSWER_CHARS:
        return "too_long"
    for m in _URL.finditer(answer):
        if m.group(0).lower() not in source.lower():
            return "address_not_on_page"
    for m in _PHONE.finditer(answer):
        if re.sub(r"\D", "", m.group(0)) not in re.sub(r"\D", "", source):
            return "phone_not_on_page"
    have_digits = set(_DIGITS.findall(source))
    if any(d not in have_digits for d in _DIGITS.findall(answer)):
        return "number_not_on_page"
    if not safety.guard_explanation(source, answer).ok:
        return "number_not_on_page"
    folded, folded_source = _fold(answer), _fold(source)
    lists = _answer_lists()
    if any(_has(folded, m) for m in lists["medicines"]):
        return "medicine_name"
    dose = lists["dose_words"].get(lang, []) + lists["dose_words"]["en"]
    if any(_has(folded, w) for w in dose if not _NUMBER_SLOT.search(w)) or any(
            p.search(folded) for p in _dose_patterns(lang)):
        return "dose_word"
    for lists_ in (v for k, v in _topics().items() if not k.startswith("_")):
        for topic, terms in lists_.items():
            for t in terms["strong"]:
                if _has(folded, t) and not _has(folded_source, t):
                    return f"{topic}_word_added"
    return None


# ---------- engines: the only code that reaches the model

class Engine(Protocol):
    preview: bool

    def complete(self, system: str, user: str, timeout: float, temperature: float = TEMPERATURE) -> str: ...


class ExplainUnavailable(Exception):
    """The model was slow, down or answered with nothing; read the page instead."""


def today() -> str:
    """The date for the model's chat template, as N-ATLaS's model card formats it."""
    return date.today().strftime("%d %b %Y")


def render_llama31(system: str, user: str, date_string: str) -> str:
    """N-ATLaS's chat template (Llama 3.1, no tools) for engines that take a raw prompt."""
    return (
        "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n"
        "Cutting Knowledge Date: December 2023\n"
        f"Today Date: {date_string}\n\n"
        f"{system.strip()}<|eot_id|>"
        f"<|start_header_id|>user<|end_header_id|>\n\n{user.strip()}<|eot_id|>"
        "<|start_header_id|>assistant<|end_header_id|>\n\n"
    )


class StubEngine:
    """No model: the page text unchanged, so nothing can be added or invented."""

    preview = True

    def complete(self, system: str, user: str, timeout: float, temperature: float = TEMPERATURE) -> str:
        return user.split("<page>\n", 1)[1].split("\n</page>", 1)[0]


class OpenAIChatEngine:
    """vLLM (or another OpenAI-compatible server) running N-ATLaS; the server applies the
    model's chat template, and date_string is passed through chat_template_kwargs."""

    preview = False

    def __init__(self, url: str, api_key: str, model: str, transport: httpx.BaseTransport | None = None,
                 adapter: str = ""):
        self.url = url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.adapter = adapter  # the Magana LoRA's name on the server; English only
        self.transport = transport
        self.lang = ""

    def for_language(self, lang: str) -> "OpenAIChatEngine":
        e = OpenAIChatEngine(self.url, self.api_key, self.model, self.transport, self.adapter)
        e.lang = lang
        return e

    def complete(self, system: str, user: str, timeout: float, temperature: float = TEMPERATURE) -> str:
        body = {
            "model": self.adapter if self.adapter and self.lang in ADAPTER_LANGS else self.model,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "temperature": temperature,
            "repetition_penalty": REPETITION_PENALTY,
            "max_tokens": text_checks.ANSWER_TOKENS,
            "chat_template_kwargs": {"date_string": today()},
        }
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        try:
            with httpx.Client(timeout=timeout, transport=self.transport) as c:
                r = c.post(f"{self.url}/v1/chat/completions", json=body, headers=headers)
                r.raise_for_status()
                return r.json()["choices"][0]["message"]["content"] or ""
        except (httpx.HTTPError, KeyError, IndexError, ValueError) as e:
            raise ExplainUnavailable(type(e).__name__) from e


class LlamaCppEngine:
    """A llama.cpp server with an N-ATLaS GGUF: Magana renders the chat template itself."""

    preview = False

    def __init__(self, url: str, api_key: str, transport: httpx.BaseTransport | None = None,
                 lora_id: int | None = None):
        self.url = url.rstrip("/")
        self.api_key = api_key
        self.transport = transport
        self.lora_id = lora_id  # the Magana LoRA loaded with --lora: on for English, off otherwise
        self.lang = ""
        self.model = os.environ.get("EXPLAIN_MODEL", "NCAIR1/N-ATLaS")

    def for_language(self, lang: str) -> "LlamaCppEngine":
        e = LlamaCppEngine(self.url, self.api_key, self.transport, self.lora_id)
        e.lang = lang
        return e

    def complete(self, system: str, user: str, timeout: float, temperature: float = TEMPERATURE) -> str:
        body: dict = {
            "prompt": render_llama31(system, user, today()),
            "temperature": temperature,
            "repeat_penalty": REPETITION_PENALTY,
            "n_predict": text_checks.ANSWER_TOKENS,
            "stop": ["<|eot_id|>"],
            "cache_prompt": True,
        }
        if self.lora_id is not None:
            body["lora"] = [{"id": self.lora_id, "scale": 1.0 if self.lang in ADAPTER_LANGS else 0.0}]
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        try:
            with httpx.Client(timeout=timeout, transport=self.transport) as c:
                r = c.post(f"{self.url}/completion", json=body, headers=headers)
                r.raise_for_status()
                return r.json()["content"] or ""
        except (httpx.HTTPError, KeyError, ValueError) as e:
            raise ExplainUnavailable(type(e).__name__) from e


def for_language(engine: Engine, lang: str) -> Engine:
    """The engine set up for one request's language (base model or the English adapter)."""
    pick = getattr(engine, "for_language", None)
    return pick(lang) if pick else engine


def default_engine() -> Engine:
    """From EXPLAIN_ENGINE (stub by default), EXPLAIN_URL, EXPLAIN_API_KEY, EXPLAIN_MODEL, and
    the English adapter: EXPLAIN_ADAPTER (vllm) or EXPLAIN_LORA_ID (llamacpp)."""
    kind = os.environ.get("EXPLAIN_ENGINE", "stub").lower()
    url = os.environ.get("EXPLAIN_URL", "")
    key = os.environ.get("EXPLAIN_API_KEY", "")
    model = os.environ.get("EXPLAIN_MODEL", "NCAIR1/N-ATLaS")
    if kind == "stub":
        return StubEngine()
    if not url:
        raise RuntimeError(f"EXPLAIN_ENGINE={kind} needs EXPLAIN_URL")
    if kind in ("vllm", "hf_space"):
        return OpenAIChatEngine(url, key, model, adapter=os.environ.get("EXPLAIN_ADAPTER", ""))
    if kind == "llamacpp":
        lora = os.environ.get("EXPLAIN_LORA_ID", "")
        return LlamaCppEngine(url, key, lora_id=int(lora) if lora else None)
    raise RuntimeError(f"EXPLAIN_ENGINE={kind!r}: use stub, vllm, hf_space or llamacpp")


def trained_for(engine: Engine, lang: str) -> bool:
    """English goes to the Magana LoRA only, never the base model (its English answers were
    refused 4 times in 5). The stub (a preview) needs none."""
    if getattr(engine, "preview", False) or lang not in ADAPTER_LANGS:
        return True
    return bool(getattr(engine, "adapter", "") or getattr(engine, "lora_id", None) is not None)


# ---------- the one task

@dataclass
class Explanation:
    code: str  # explained | explain_preview | explain_ask_teacher | numbers_unconfirmed |
    #            explain_unavailable | explain_language_coming | explain_not_available
    explanation: str | None
    read_instead: str | None
    preview: bool
    reason: str | None = None  # why it was blocked or refused (logged; a code, never text)


def _record(outcome: Explanation, engine: Engine, lang: str, started: float, sections: int,
            prompt_: Prompt | None) -> Explanation:
    """One log line per explanation: what ran and what happened. Never page or learner text."""
    log.info(json.dumps({
        "task": TASK, "lang": lang, "outcome": outcome.code, "reason": outcome.reason,
        "sections": sections, "seconds": round(time.monotonic() - started, 2),
        "prompt_version": prompt_.version if prompt_ else None, **model_identity(engine),
    }))
    return outcome


def _answer(engine: Engine, system: str, user: str, page: "placeholders.Masked", lang: str,
            section: str, deadline: float) -> tuple[str | None, str | None]:
    """(the checked answer, None) or (None, the refusal reason). One retry at RETRY_TEMPERATURE."""
    reason = "numbers_unconfirmed"
    for temperature in (TEMPERATURE, RETRY_TEMPERATURE):
        left = deadline - time.monotonic()
        if left <= 0:
            if temperature == TEMPERATURE:
                raise ExplainUnavailable("timeout")
            break  # no time to try again: read the page
        raw = engine.complete(system, user, left, temperature=temperature).strip()
        if not raw:
            raise ExplainUnavailable("empty")
        text, problems = text_checks.check_answer(raw, page, None, lang, allow_left_out=False)
        if problems:
            reason = "wrong_language" if any(p.code == "wrong_language" for p in problems) else problems[0].code
            continue
        if engine.preview:
            return text, None  # the stub gives the page back as it is: nothing to check
        if (why := answer_problem(text, section, lang)) is None:
            return text, None
        reason = why
    return None, reason


def explain_page(engine: Engine, page_text: str, lang: str, guided: bool,
                 timeout_s: float = TIMEOUT_S) -> Explanation:
    """Explain the page Magana read, in [lang]. The only entry point to the model."""
    started = time.monotonic()
    p = prompt(lang)

    def done(code, explanation=None, read_instead=None, reason=None, sections=0):
        return _record(Explanation(code, explanation, read_instead, code == "explain_preview", reason),
                       engine, lang, started, sections, p)

    if lang not in enabled_languages() or p is None:
        return done("explain_language_coming", reason="language_off")
    if (topic := sensitive_topic(page_text)) is not None:
        return done("explain_ask_teacher", reason=f"page_about_{topic}")
    if not allowed(engine):
        return done("explain_not_available", read_instead=page_text, reason="no_approved_host")
    engine = for_language(engine, lang)
    if not trained_for(engine, lang):
        return done("explain_unavailable", read_instead=page_text, reason="no_adapter")
    deadline = time.monotonic() + timeout_s
    parts = text_checks.sections(page_text)
    system = p.system(guided)
    answers = []
    try:
        for n, section in enumerate(parts, 1):
            page = placeholders.mask(section)
            markers = [f"⟦N{k}⟧" for k in range(1, len(page.slots) + 1)]
            user = text_checks.user_prompt(page.text, (n, len(parts)), markers)
            text, refused = _answer(engine, system, user, page, lang, section, deadline)
            if refused:
                code = "explain_wrong_language" if refused == "wrong_language" else "numbers_unconfirmed"
                return done(code, read_instead=page_text, reason=refused, sections=len(parts))
            answers.append(text)
    except ExplainUnavailable as e:
        return done("explain_unavailable", read_instead=page_text, reason=f"model_{e}", sections=len(parts))
    return done("explain_preview" if engine.preview else "explained", "\n\n".join(answers), sections=len(parts))


# ---------- not the app: evaluation and developer tools (never reachable from the API)

def eval_prompt(lang: str, guided: bool = False) -> Prompt:
    """The prompt the nightly evaluation uses: [lang]'s own when written, else the English rules
    asking for an answer in [lang] (so a language can be measured before it is switched on)."""
    if (p := prompt(lang)) is not None:
        return p
    en = prompt("en")
    name = text_checks.LANGUAGE_NAMES[lang]
    return Prompt(lang, f"{en.version}+as-{lang}", "evaluation", en.text.replace("in English", f"in {name}"), en.guided)


def evaluate(engine: Engine, page_text: str, lang: str, timeout_s: float = TIMEOUT_S) -> dict:
    """For the nightly evaluation (tests/safety/natlas_refusal) and the Explain benchmark only.
    What the app would do with this page (topic check, answer checks), and what the model itself
    answers when the topic check is bypassed, as the audit did: so a language whose model answers
    harmful pages can be switched off (NATLAS_ENABLED_LANGS). Logged like every call."""
    started = time.monotonic()
    p = eval_prompt(lang)
    page = placeholders.mask(page_text)
    markers = [f"⟦N{k}⟧" for k in range(1, len(page.slots) + 1)]
    out = {"topic": sensitive_topic(page_text), "raw": None, "checks": None, "error": None}
    try:
        raw = for_language(engine, lang).complete(
            p.system(False), text_checks.user_prompt(page.text, (1, 1), markers), timeout_s).strip()
        out["raw"] = raw
        text, problems = text_checks.check_answer(raw, page, None, lang, allow_left_out=False)
        out["checks"] = problems[0].code if problems else answer_problem(text, page_text, lang)
    except ExplainUnavailable as e:
        out["error"] = str(e)
    log.info(json.dumps({"task": "evaluation", "lang": lang, "topic": out["topic"], "blocked_by_checks": out["checks"],
                         "error": out["error"], "seconds": round(time.monotonic() - started, 2),
                         "prompt_version": p.version, **model_identity(engine)}))
    return out


def benchmark_complete(engine: Engine, system: str, user: str, timeout: float) -> str:
    """The Explain benchmark's raw call (benchmark/explain/explain_bench.py), logged; never the API."""
    log.info(json.dumps({"task": "benchmark", **model_identity(engine)}))
    return engine.complete(system, user, timeout)


def local_tool_completion(url: str, system: str, user: str, schema: dict, n_predict: int = 400) -> str:
    """A developer tool on this Mac only (backend/scripts/lesson_notes.py: labels for teachers'
    private notes): N-ATLaS on llama.cpp at [url], which must be this machine. Never the API."""
    if not url.startswith(("http://127.0.0.1", "http://localhost")):
        raise ValueError("local_tool_completion: the model must run on this machine")
    log.info(json.dumps({"task": "local_tool", "revision": os.environ.get("NATLAS_MODEL_REVISION", "unknown")}))
    r = httpx.post(f"{url}/completion", timeout=600, json={
        "prompt": render_llama31(system, user, today()), "temperature": 0, "n_predict": n_predict,
        "json_schema": schema})
    return r.json()["content"]
