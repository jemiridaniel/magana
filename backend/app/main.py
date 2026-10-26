"""Magana API (hackathon MVP)."""
from __future__ import annotations

import asyncio
import hmac
import json
import io
from contextlib import asynccontextmanager
from functools import lru_cache
import os

from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from PIL import Image
import logging
from typing import Literal

import httpx
from pydantic import BaseModel, ConfigDict, Field

from . import asr, codes, curriculum, explain, handwriting, learner_api, pdfs, policy, portal_api, quizzes, ratelimit, safety, templates, triage, uploads_api, wa_flow
from .wa_client import WhatsAppClient
from .iba_client import IbaClient, IbaUnavailable
from .iba_monitor import monitor as iba_monitor
from .messages import CodedError
from .reader import SECOND_PASS_SCALE, OCREngine, check_number_reread, default_engine, read_page

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Probe Ibà in the background, so an outage is noticed (and alerted after 10 minutes)
    even when nobody is using the quick check."""
    # Every number must get its second reading from a crop (CLAUDE.md rule 2). An OCR engine
    # that can't do that is refused here, before the server takes any requests.
    await asyncio.to_thread(check_number_reread, get_engine())
    task = None
    interval = float(os.environ.get("IBA_PROBE_S", "60"))
    if IbaClient.from_env() is not None and interval > 0:
        task = asyncio.create_task(_probe_iba(interval))
    yield
    if task:
        task.cancel()


async def _probe_iba(interval: float) -> None:
    while True:
        client = IbaClient.from_env()
        if client is not None:
            try:
                await client.health()
                iba_monitor.success()
            except IbaUnavailable as e:
                iba_monitor.failure(str(e))
        await asyncio.sleep(interval)


log = logging.getLogger("magana.api")

app = FastAPI(
    lifespan=lifespan,
    title="Magana API",
    version="0.2.0",
    description="Responses carry message codes, never sentences; see app/messages.py for the English reference.",
)
app.include_router(portal_api.router)
app.include_router(learner_api.router)
app.include_router(uploads_api.router)

WHATSAPP_WEBHOOK = "/whatsapp/webhook"


@app.middleware("http")
async def rate_limit(request, call_next):
    """Per-IP and per-device limits (app/ratelimit.py): the web app's key is public."""
    if request.method != "OPTIONS":
        ip = request.client.host if request.client else "unknown"
        wait = ratelimit.limiter.check(request.url.path, ip, request.headers.get("x-magana-device"),
                                       request.cookies.get(portal_api.COOKIE))
        if wait:
            return JSONResponse({"detail": {"code": "too_many_requests"}}, status_code=429,
                                headers={"Retry-After": str(max(1, round(wait)))})
    return await call_next(request)


@app.middleware("http")
async def require_api_key(request, call_next):
    """MAGANA_API_KEY (set on the server) must come with every request as X-Magana-Key.
    /health stays open for the load balancer and uptime checks; CORS preflights pass.
    Unset (local development): no key needed. The key ships inside the app, so it keeps
    out casual callers and bots, not a determined attacker."""
    key = os.environ.get("MAGANA_API_KEY", "")
    # The web app and portal (Cloudflare Pages, built by GitHub Actions) carry their own key,
    # MAGANA_WEB_API_KEY: it is public in their JavaScript anyway, so it can be rotated without
    # touching the APKs, and the APK key never goes to GitHub.
    keys = [k for k in (key, os.environ.get("MAGANA_WEB_API_KEY", "")) if k]
    # The WhatsApp webhook is called by Meta, which proves itself with a signature instead.
    if key and request.method != "OPTIONS" and request.url.path not in ("/health", WHATSAPP_WEBHOOK):
        sent = request.headers.get("x-magana-key", "").encode()
        if not any(hmac.compare_digest(sent, k.encode()) for k in keys):
            return JSONResponse({"detail": {"code": "bad_api_key"}}, status_code=401)
    return await call_next(request)


# Browsers (Flutter web, teacher portal) need CORS. Dev allows any localhost port;
# production sets MAGANA_CORS_ORIGIN_REGEX to its own domains. Added last, so it is the
# outermost layer: a 401 or 429 from the checks above still carries CORS headers, and
# the web app can read "too many requests" instead of seeing a network error.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.environ.get("MAGANA_CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST", "PUT", "DELETE"],  # PUT: the portal saves changes to a quiz
    allow_headers=["*"],
    # The portal's sign-in cookie (HttpOnly, api.magana.ng only) goes with its requests; only the
    # origins in the regex above may send it.
    allow_credentials=True,
)

# Letters and "read any paper" may hold doses or amounts, so they get the strict checks too.
SECOND_PASS_MODES = {"health", "money", "letter"}

MODE_FEATURE = {
    "school": policy.Feature.READ_SCHOOLWORK,
    "health": policy.Feature.EVERYDAY_HEALTH,
    "money": policy.Feature.EVERYDAY_MONEY,
    "letter": policy.Feature.EVERYDAY_LETTERS,
}


@lru_cache(maxsize=1)
def get_engine() -> OCREngine:
    """One engine per process: PP-StructureV3 takes seconds to load its models."""
    return default_engine()


def caller_tier(
    x_magana_tier: str = Header("standard"),
    x_magana_guardian_consent: str | None = Header(None),
    x_magana_teacher_session: str | None = Header(None),
    x_magana_learner: str | None = Header(None),
) -> policy.Tier:
    """The age tier the app says this user is in (headers on every request). A phone linked to
    a class carries its link (X-Magana-Learner): then consent is what the teacher recorded in
    the portal, whatever the app's header says."""
    try:
        tier = policy.Tier(x_magana_tier)
    except ValueError:
        raise HTTPException(400, {"code": "unknown_tier"})
    consent = x_magana_guardian_consent == "yes"
    if tier is policy.Tier.GUIDED and (portal := learner_api.consent_confirmed(x_magana_learner)) is not None:
        consent = portal
    try:
        return policy.check_request(tier, consent, x_magana_teacher_session == "yes")
    except CodedError as e:
        raise HTTPException(403, {"code": e.code})


def require(tier: policy.Tier, feature: policy.Feature) -> None:
    try:
        policy.require(tier, feature)
    except CodedError as e:
        raise HTTPException(403, {"code": e.code})


def health_caller(tier: policy.Tier = Depends(caller_tier)) -> policy.Tier:
    """Talking to a health worker and the Ibà check are for adults only."""
    require(tier, policy.Feature.HEALTH_CALLBACK)
    return tier


@app.get("/health")
def health() -> dict:
    iba = {"configured": bool(os.environ.get("IBA_API_URL", "").strip()), **iba_monitor.status()}
    return {"status": "ok", "iba": iba}


@app.post("/read")
async def read(file: UploadFile = File(...), mode: str = Form("school"),
               tier: policy.Tier = Depends(caller_tier), engine: OCREngine = Depends(get_engine)) -> dict:
    feature = MODE_FEATURE.get(mode)
    if feature is None:
        raise HTTPException(400, {"code": "unknown_mode"})
    require(tier, feature)
    try:
        image = Image.open(io.BytesIO(await file.read()))
        image.load()
    except Exception:
        raise HTTPException(400, {"code": "unreadable_image"})
    # Health and money papers get a second OCR pass so every number is read twice.
    result = read_page(image, engine, second_pass=mode in SECOND_PASS_MODES,
                       handwriting=handwriting_reader(mode, tier))
    # The uploaded photo is never stored: it only lives in memory for this request.
    return checked(result, mode)


@lru_cache(maxsize=1)
def _handwriting_engine():
    return handwriting.reader_from_env()


def handwriting_reader(mode: str, tier: policy.Tier):
    """The optional handwriting engine: schoolwork only, and Azure (images leave Magana)
    for adults only."""
    if mode != "school":
        return None
    reader = _handwriting_engine()
    if reader is not None and reader.name == "azure" and tier != policy.Tier.STANDARD:
        return None
    return reader


def checked(result: dict, mode: str = "school") -> dict:
    """A page's reading with its safety warnings: confidence, each number, line ends,
    table cells, and the second pass when there is one."""
    warnings = (safety.confidence_warnings(result["lines"]) + safety.number_warnings(result["lines"])
                + safety.line_end_warnings(result["lines"]) + safety.line_part_warnings(result["lines"]))
    if mode == "health":
        hand, tips = safety.handwritten_health(result)
        warnings += hand
        result = {**result, "tips": result.get("tips", []) + tips}
    cell_warnings = safety.table_warnings(result["tables"]) + safety.cell_number_warnings(result["tables"])
    if "second_pass" in result:
        line_mm, cell_mm = safety.number_mismatches(result, result.pop("second_pass"), scale=SECOND_PASS_SCALE)
        warnings += line_mm
        cell_warnings += cell_mm
    return {**result, "warnings": [w.__dict__ for w in warnings], "cell_warnings": [w.__dict__ for w in cell_warnings]}


@app.post("/read-pdf")
async def read_pdf(file: UploadFile = File(...), mode: str = Form("money"), password: str = Form(""),
                   tier: policy.Tier = Depends(caller_tier), engine: OCREngine = Depends(get_engine)) -> dict:
    """A shared or downloaded PDF, every page in one reading (pdfs.py). Held in memory only;
    the password opens the file for this request and is never stored or logged."""
    feature = MODE_FEATURE.get(mode)
    if feature is None:
        raise HTTPException(400, {"code": "unknown_mode"})
    require(tier, feature)
    data = await file.read(pdfs.MAX_BYTES + 1)
    try:
        return pdfs.read_pdf(data, password or None, engine, mode in SECOND_PASS_MODES,
                             lambda result: checked(result, mode))
    except pdfs.PdfError as e:
        status = {"pdf_password_needed": 401, "pdf_password_wrong": 401, "pdf_too_long": 413}.get(e.code, 400)
        raise HTTPException(status, {"code": e.code}) from None
    except Exception:  # an odd file: no traceback, nothing about the request in the logs
        raise HTTPException(400, {"code": "unreadable_pdf"}) from None
    finally:
        del data, password


class ExplainCheck(BaseModel):
    source_text: str
    explanation: str


@app.post("/explain/check")
def explain_check(body: ExplainCheck) -> dict:
    """Run a model explanation through the verbatim-number guard before it is spoken."""
    r = safety.guard_explanation(body.source_text, body.explanation)
    return {"ok": r.ok, "unsupported": r.unsupported, "message": r.message}


class ExplainRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_text: str  # the page (or part of it) the learner is asking about: data, never instructions
    question: str | None = None
    lang: Literal["en", "ha", "yo", "ig"] = "en"
    style: Literal["explain", "simpler", "example"] = "explain"
    # school: N-ATLaS, numbers as placeholders. health, money, letter: never a model,
    # only approved phrase templates (templates.py).
    mode: Literal["school", "health", "money", "letter"] = "school"


EXPLAIN_FEATURE = {
    "school": policy.Feature.EXPLAIN,
    "health": policy.Feature.EVERYDAY_HEALTH,
    "money": policy.Feature.EVERYDAY_MONEY,
    "letter": policy.Feature.EVERYDAY_LETTERS,
}


@lru_cache(maxsize=1)
def get_explain_engine() -> explain.Engine:
    """One engine per process, from EXPLAIN_ENGINE (docs/MODELS.md)."""
    return explain.default_engine()


@app.post("/explain")
def explain_page(body: ExplainRequest, tier: policy.Tier = Depends(caller_tier),
                 engine: explain.Engine = Depends(get_explain_engine)) -> dict:
    """An explanation of page text, always through the verbatim-number guard (CLAUDE.md
    rule 1). If the guard fails or the model is unavailable, the app reads the page instead.
    Guided learners (13-17) get a curriculum-only prompt."""
    require(tier, EXPLAIN_FEATURE[body.mode])
    if not body.source_text.strip() or len(body.source_text) > explain.MAX_SOURCE_CHARS:
        raise HTTPException(400, {"code": "explain_bad_source"})
    if not explain.allowed(engine):
        # Tester and production builds: Explain stays off (no page text leaves for an
        # unapproved host, and the templates are not yet approved either).
        return {"code": "explain_not_available", "explanation": None, "read_instead": body.source_text,
                "preview": False}
    if body.mode != "school":
        # Health and money papers: no model, ever. Approved templates or English as printed.
        t = templates.translate(body.source_text, body.lang, body.mode)
        return {"code": "paper_lines", "explanation": None, "read_instead": None, "preview": False,
                "lines": t["lines"], "fallback": t["fallback"]}
    r = explain.explain(explain.for_language(engine, body.lang), body.source_text, body.question, body.lang,
                        body.style, guided=tier is policy.Tier.GUIDED)
    body = {"code": r.code, "explanation": r.explanation, "read_instead": r.read_instead,
            "preview": r.preview}
    if r.followup:
        body["followup"] = r.followup  # numbers_left_out: "The exact numbers are on the page…"
    return body


@lru_cache(maxsize=1)
def get_asr_engine() -> asr.ASREngine:
    return asr.default_engine()


@app.get("/asr/available")
def asr_available(engine: asr.ASREngine = Depends(get_asr_engine)) -> dict:
    """Whether this server recognises speech, so the app can skip it without recording."""
    return {"available": not isinstance(engine, asr.DeviceOnly), "engine": engine.name}


@app.post("/asr")
async def transcribe(file: UploadFile = File(...), lang: Literal["en", "ha", "yo", "ig"] = Form("en"),
                     engine: asr.ASREngine = Depends(get_asr_engine)) -> dict:
    """A short spoken answer or command (at most 30 s). The audio is never stored. When the
    server has no ASR, the app uses the phone's own recogniser."""
    audio = await file.read()
    if len(audio) > 2_000_000:  # 30 s of 16 kHz 16-bit mono is about 1 MB
        raise HTTPException(413, {"code": "audio_too_long"})
    try:
        text = await asyncio.to_thread(engine.transcribe, audio, lang)
    except asr.ASRUnavailable:
        raise HTTPException(503, {"code": "asr_unavailable"})
    except Exception:
        log.exception("asr failed")
        raise HTTPException(400, {"code": "unreadable_audio"})
    if asr.looped(text):
        text = ""  # treated as heard nothing: the app asks again, then offers tapping
    return {"text": text.strip(), "engine": engine.name}


# ---------- quizzes: teacher-made, assigned to a class, read by learners at that level

@lru_cache(maxsize=1)
def get_quiz_store() -> quizzes.QuizStore:
    return quizzes.default_store()


def teacher(who: portal_api.Who = Depends(portal_api.staff)) -> portal_api.Who:
    """Quiz writes reach children: only a signed-in teacher of an approved school (portal_api)."""
    return who


def _mine(who: portal_api.Who, quiz: quizzes.Quiz) -> bool:
    """A teacher's own quizzes; a school admin sees the school's."""
    return quiz.owner == who.staff["id"] or (who.admin and quiz.school_id == who.school["id"])


def _with_problems(quiz: quizzes.Quiz) -> dict:
    return {"quiz": quiz.for_teacher(), "problems": [p.model_dump() for p in quizzes.check(quiz)]}


def _quiz(store: quizzes.QuizStore, quiz_id: str, who: portal_api.Who | None = None) -> quizzes.Quiz:
    try:
        quiz = store.get(quiz_id)
    except KeyError:
        raise HTTPException(404, {"code": "quiz_not_found"})
    if who is not None and not _mine(who, quiz):
        raise HTTPException(404, {"code": "quiz_not_found"})
    return quiz


class Assign(BaseModel):
    session: str = Field(..., min_length=1, max_length=120)


@app.get("/curriculum")
def get_curriculum() -> dict:
    """Class levels and subjects (the app and portal carry copies; a test compares them)."""
    return curriculum.as_json()


@app.get("/quizzes")
def list_quizzes(class_id: str | None = None, store: quizzes.QuizStore = Depends(get_quiz_store),
                 who: portal_api.Who = Depends(teacher)) -> list[dict]:
    return [_with_problems(q) for q in store.all() if class_id in (None, q.class_id) and _mine(who, q)]


@app.post("/quizzes", status_code=201)
def create_quiz(body: quizzes.QuizIn, store: quizzes.QuizStore = Depends(get_quiz_store),
                who: portal_api.Who = Depends(teacher)) -> dict:
    """Saved as a draft whatever its problems; only assigning needs it ready."""
    return _with_problems(store.create(body, owner=who.staff["id"], school_id=who.school["id"]))


@app.get("/quizzes/{quiz_id}")
def get_quiz(quiz_id: str, store: quizzes.QuizStore = Depends(get_quiz_store),
             who: portal_api.Who = Depends(teacher)) -> dict:
    return _with_problems(_quiz(store, quiz_id, who))


@app.put("/quizzes/{quiz_id}")
def update_quiz(quiz_id: str, body: quizzes.QuizIn, store: quizzes.QuizStore = Depends(get_quiz_store),
                who: portal_api.Who = Depends(teacher)) -> dict:
    _quiz(store, quiz_id, who)
    return _with_problems(store.update(quiz_id, body))


@app.post("/quizzes/{quiz_id}/rotate-session-code")
def rotate_session_code(quiz_id: str, store: quizzes.QuizStore = Depends(get_quiz_store),
                        who: portal_api.Who = Depends(teacher)) -> dict:
    """A new code for this quiz's class session; the old one stops working at once."""
    quiz = _quiz(store, quiz_id, who)
    if quiz.status != "assigned":
        raise HTTPException(409, {"code": "quiz_not_assigned"})
    store.rotate_session_code(quiz.class_id, quiz.session)
    return _with_problems(store.get(quiz_id))


@app.post("/quizzes/{quiz_id}/assign")
def assign_quiz(quiz_id: str, body: Assign, store: quizzes.QuizStore = Depends(get_quiz_store),
                who: portal_api.Who = Depends(teacher)) -> dict:
    """Refused while any blocking problem is left: no right answer, a picture without a
    description, too few or too many options."""
    quiz = _quiz(store, quiz_id, who)
    problems = quizzes.check(quiz)
    if any(p.blocking for p in problems):
        raise HTTPException(422, {"code": "quiz_not_ready", "problems": [p.model_dump() for p in problems]})
    return _with_problems(store.assign(quiz_id, body.session))


@app.get("/learner/quizzes")
def learner_quizzes(session_code: str, tier: policy.Tier = Depends(caller_tier),
                    x_magana_teacher_session: str | None = Header(None),
                    store: quizzes.QuizStore = Depends(get_quiz_store)) -> dict:
    """The quizzes assigned to one class session, for any age group, only inside a session
    the teacher opened on this phone with the session's code. Learners on their own get
    the app's sample packs only. The session's code (6 digits, matched by its keyed hash)
    keeps teacher A's quiz inside teacher A's session."""
    require(tier, policy.Feature.QUIZ)
    if x_magana_teacher_session != "yes":
        raise HTTPException(403, {"code": "teacher_session_required"})
    code = codes.normalise(session_code)
    if len(code) != codes.LENGTH:
        raise HTTPException(422, {"code": "session_code_invalid"})
    lookup = codes.lookup(code)
    return {"quizzes": [quizzes.for_learner(q) for q in store.all()
                        if q.status == "assigned" and q.session_lookup == lookup and quizzes.ready(q)]}


@app.post("/asr/choose")
async def choose_answer(file: UploadFile = File(...), lang: Literal["en", "ha", "yo", "ig"] = Form("en"),
                        kind: Literal["letters", "yes_no", "true_false"] = Form("letters"),
                        count: int = Form(4, ge=2, le=4),
                        engine: asr.ASREngine = Depends(get_asr_engine)) -> dict:
    """A quiz answer by closed set (closed_set.py): the audio is scored against each allowed
    answer (letters in the UI language and English, yes/no, true/false) instead of being
    transcribed. "answer" is null below the confidence cut-off: the app asks again. The app
    confirms every answer before it counts. The audio is never stored."""
    audio = await file.read()
    if len(audio) > 2_000_000:
        raise HTTPException(413, {"code": "audio_too_long"})
    try:
        result = await asyncio.to_thread(engine.choose, audio, lang, kind, count)
    except asr.ASRUnavailable:
        raise HTTPException(503, {"code": "asr_unavailable"})
    except Exception:
        log.exception("asr choose failed")
        raise HTTPException(400, {"code": "unreadable_audio"})
    return {**result, "engine": engine.name}


def get_iba() -> IbaClient | None:
    """The Ibà triage service, from IBA_API_URL / IBA_API_KEY; None when not configured."""
    return IbaClient.from_env()


@app.get("/triage/questions", dependencies=[Depends(health_caller)])
async def triage_questions(lang: str = "en", iba: IbaClient | None = Depends(get_iba)) -> dict:
    # Question wording comes from Ibà, where it is signed off clinically; the fallback set
    # carries message codes only (messages.ENGLISH "q_<id>").
    qs, source = await triage.questions(lang, iba)
    return {"source": source, "questions": qs}


@app.post("/triage/assess", dependencies=[Depends(health_caller)])
async def triage_assess(answers: dict, iba: IbaClient | None = Depends(get_iba)) -> dict:
    # Answers are health information: they are passed to Ibà and never logged or stored.
    r = await triage.assess(answers, iba)
    return {"priority": r.priority.value, "message": r.message, "rule_version": r.rule_version, "source": r.source}



class CallbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: Literal["medicine", "results", "other"]
    language: Literal["en", "ha", "yo", "ig"]
    priority: Literal["emergency", "urgent", "routine"] | None = None  # from the Ibà quick check


@app.post("/callback", dependencies=[Depends(health_caller)])
async def request_callback(body: CallbackRequest) -> dict:
    """Ask a nurse or pharmacist to call back.

    Forwarded to the nurse desk at MAGANA_CALLBACK_URL. Until one is connected this
    says so (callback_unavailable) instead of promising a call nobody will make.
    No personal details are logged.
    """
    url = os.environ.get("MAGANA_CALLBACK_URL", "").strip()
    if not url:
        raise HTTPException(503, {"code": "callback_unavailable"})
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            r = await client.post(url, json=body.model_dump())
            r.raise_for_status()
    except httpx.HTTPError as e:
        log.error("callback desk failed: %s", type(e).__name__)
        raise HTTPException(503, {"code": "callback_unavailable"})
    log.info("callback booked reason=%s priority=%s", body.reason, body.priority)
    return {"code": "callback_booked"}


# ---------- WhatsApp (docs/WHATSAPP_SETUP.md; the conversation is in app/wa_flow.py)

_seen_messages: dict[str, None] = {}


def _first_delivery(message_id: str) -> bool:
    """Meta may deliver a message more than once: handle each id once."""
    if not message_id or message_id in _seen_messages:
        return False
    _seen_messages[message_id] = None
    while len(_seen_messages) > 2000:
        _seen_messages.pop(next(iter(_seen_messages)))
    return True


@lru_cache(maxsize=1)
def get_whatsapp_flow() -> wa_flow.Flow | None:
    client = WhatsAppClient.from_env()
    return wa_flow.Flow(client, get_engine) if client else None


@app.get(WHATSAPP_WEBHOOK)
def whatsapp_verify(mode: str = Query("", alias="hub.mode"), token: str = Query("", alias="hub.verify_token"),
                    challenge: str = Query("", alias="hub.challenge")):
    """Meta's one-time check when the webhook is registered: echo the challenge."""
    expected = os.environ.get("WHATSAPP_VERIFY_TOKEN", "")
    if not expected or mode != "subscribe" or not hmac.compare_digest(token.encode(), expected.encode()):
        raise HTTPException(403, {"code": "verify_token_wrong"})
    return PlainTextResponse(challenge)


@app.post(WHATSAPP_WEBHOOK)
async def whatsapp_webhook(request: Request, background: BackgroundTasks,
                           flow: wa_flow.Flow | None = Depends(get_whatsapp_flow)) -> dict:
    """Messages from WhatsApp. Only requests signed with the app secret (X-Hub-Signature-256)
    are accepted. The reply is sent in the background, so Meta gets its 200 at once."""
    secret = os.environ.get("WHATSAPP_APP_SECRET", "")
    if not secret or flow is None:
        raise HTTPException(503, {"code": "whatsapp_not_configured"})
    body = await request.body()
    expected = "sha256=" + hmac.new(secret.encode(), body, "sha256").hexdigest()
    if not hmac.compare_digest(request.headers.get("x-hub-signature-256", "").encode(), expected.encode()):
        raise HTTPException(401, {"code": "bad_signature"})
    try:
        payload = json.loads(body)
        messages = [m for e in payload.get("entry", []) for c in e.get("changes", [])
                    for m in c.get("value", {}).get("messages", [])]
    except (ValueError, AttributeError, TypeError):
        return {"ok": True}  # signed but not a message delivery (e.g. a status update)
    fresh = [m for m in messages if _first_delivery(str(m.get("id", "")))]
    if fresh:
        background.add_task(wa_flow.process, flow, fresh)
    return {"ok": True}

