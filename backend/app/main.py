"""Magana API (hackathon MVP)."""
from __future__ import annotations

import asyncio
import io
from contextlib import asynccontextmanager
from functools import lru_cache
import os

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import logging
from typing import Literal

import httpx
from pydantic import BaseModel, ConfigDict

from . import policy, safety, triage
from .iba_client import IbaClient, IbaUnavailable
from .iba_monitor import monitor as iba_monitor
from .messages import CodedError
from .reader import SECOND_PASS_SCALE, OCREngine, default_engine, read_page

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Probe Ibà in the background, so an outage is noticed (and alerted after 10 minutes)
    even when nobody is using the quick check."""
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
# Browsers (Flutter web, teacher portal) need CORS. Dev allows any localhost port;
# production sets MAGANA_CORS_ORIGIN_REGEX to its own domains.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.environ.get("MAGANA_CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

SECOND_PASS_MODES = {"health", "money"}

MODE_FEATURE = {
    "school": policy.Feature.READ_SCHOOLWORK,
    "health": policy.Feature.EVERYDAY_HEALTH,
    "money": policy.Feature.EVERYDAY_MONEY,
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
