"""Magana API (hackathon MVP)."""
from __future__ import annotations

import asyncio
import hmac
import io
from contextlib import asynccontextmanager
from functools import lru_cache
import os

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
import logging
from typing import Literal

import httpx
from pydantic import BaseModel, ConfigDict, Field

from . import asr, curriculum, explain, policy, quizzes, ratelimit, safety, templates, triage
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
@app.middleware("http")
async def rate_limit(request, call_next):
    """Per-IP and per-device limits (app/ratelimit.py): the web app's key is public."""
    if request.method != "OPTIONS":
        ip = request.client.host if request.client else "unknown"
        wait = ratelimit.limiter.check(request.url.path, ip, request.headers.get("x-magana-device"))
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
    if key and request.method != "OPTIONS" and request.url.path != "/health":
        sent = request.headers.get("x-magana-key", "")
        if not hmac.compare_digest(sent.encode(), key.encode()):
            return JSONResponse({"detail": {"code": "bad_api_key"}}, status_code=401)
    return await call_next(request)


# Browsers (Flutter web, teacher portal) need CORS. Dev allows any localhost port;
# production sets MAGANA_CORS_ORIGIN_REGEX to its own domains. Added last, so it is the
# outermost layer: a 401 or 429 from the checks above still carries CORS headers, and
# the web app can read "too many requests" instead of seeing a network error.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.environ.get("MAGANA_CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST", "PUT"],  # PUT: the portal saves changes to a quiz
    allow_headers=["*"],
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
) -> policy.Tier:
    """The age tier the app says this user is in (headers on every request)."""
    try:
        tier = policy.Tier(x_magana_tier)
    except ValueError:
        raise HTTPException(400, {"code": "unknown_tier"})
    try:
        return policy.check_request(tier, x_magana_guardian_consent == "yes", x_magana_teacher_session == "yes")
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
    result = read_page(image, engine, second_pass=mode in SECOND_PASS_MODES)
    # The uploaded photo is never stored: it only lives in memory for this request.
    warnings = (safety.confidence_warnings(result["lines"]) + safety.number_warnings(result["lines"])
                + safety.line_end_warnings(result["lines"]))
    cell_warnings = safety.table_warnings(result["tables"]) + safety.cell_number_warnings(result["tables"])
    if "second_pass" in result:
        line_mm, cell_mm = safety.number_mismatches(result, result.pop("second_pass"), scale=SECOND_PASS_SCALE)
        warnings += line_mm
        cell_warnings += cell_mm
    return {**result, "warnings": [w.__dict__ for w in warnings], "cell_warnings": [w.__dict__ for w in cell_warnings]}


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
    r = explain.explain(engine, body.source_text, body.question, body.lang, body.style,
                        guided=tier is policy.Tier.GUIDED)
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


def teacher(x_magana_teacher_key: str = Header("")) -> None:
    """Quiz writes reach children, and the app's API key is public, so the portal also sends
    MAGANA_TEACHER_KEY (until teachers sign in). Unset: only development servers accept writes."""
    key = os.environ.get("MAGANA_TEACHER_KEY", "")
    if not key:
        if explain.deployment() != "development":
            raise HTTPException(503, {"code": "teacher_portal_off"})
        return
    if not hmac.compare_digest(x_magana_teacher_key.encode(), key.encode()):
        raise HTTPException(401, {"code": "teacher_key_required"})


def _with_problems(quiz: quizzes.Quiz) -> dict:
    return {"quiz": quiz.model_dump(), "problems": [p.model_dump() for p in quizzes.check(quiz)]}


def _quiz(store: quizzes.QuizStore, quiz_id: str) -> quizzes.Quiz:
    try:
        return store.get(quiz_id)
    except KeyError:
        raise HTTPException(404, {"code": "quiz_not_found"})


class Assign(BaseModel):
    session: str = Field(..., min_length=1, max_length=120)


@app.get("/curriculum")
def get_curriculum() -> dict:
    """Class levels and subjects (the app and portal carry copies; a test compares them)."""
    return curriculum.as_json()


@app.get("/quizzes", dependencies=[Depends(teacher)])
def list_quizzes(class_id: str | None = None, store: quizzes.QuizStore = Depends(get_quiz_store)) -> list[dict]:
    return [_with_problems(q) for q in store.all() if class_id in (None, q.class_id)]


@app.post("/quizzes", dependencies=[Depends(teacher)], status_code=201)
def create_quiz(body: quizzes.QuizIn, store: quizzes.QuizStore = Depends(get_quiz_store)) -> dict:
    """Saved as a draft whatever its problems; only assigning needs it ready."""
    return _with_problems(store.create(body))


@app.get("/quizzes/{quiz_id}", dependencies=[Depends(teacher)])
def get_quiz(quiz_id: str, store: quizzes.QuizStore = Depends(get_quiz_store)) -> dict:
    return _with_problems(_quiz(store, quiz_id))


@app.put("/quizzes/{quiz_id}", dependencies=[Depends(teacher)])
def update_quiz(quiz_id: str, body: quizzes.QuizIn, store: quizzes.QuizStore = Depends(get_quiz_store)) -> dict:
    _quiz(store, quiz_id)
    return _with_problems(store.update(quiz_id, body))


@app.post("/quizzes/{quiz_id}/assign", dependencies=[Depends(teacher)])
def assign_quiz(quiz_id: str, body: Assign, store: quizzes.QuizStore = Depends(get_quiz_store)) -> dict:
    """Refused while any blocking problem is left: no right answer, a picture without a
    description, too few or too many options."""
    quiz = _quiz(store, quiz_id)
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
    the app's sample packs only. Until class codes and teacher accounts exist, the code is
    what keeps teacher A's quiz inside teacher A's session."""
    require(tier, policy.Feature.QUIZ)
    if x_magana_teacher_session != "yes":
        raise HTTPException(403, {"code": "teacher_session_required"})
    code = session_code.strip().upper()
    if not quizzes.CODE_RE.match(code):
        raise HTTPException(422, {"code": "session_code_invalid"})
    return {"quizzes": [quizzes.for_learner(q) for q in store.all()
                        if q.status == "assigned" and q.session_code == code and quizzes.ready(q)]}


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
