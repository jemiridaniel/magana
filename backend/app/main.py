"""Magana API (hackathon MVP)."""
from __future__ import annotations

import io
from functools import lru_cache
import os

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from pydantic import BaseModel

from . import policy, safety, triage
from .messages import CodedError
from .reader import SECOND_PASS_SCALE, OCREngine, default_engine, read_page

app = FastAPI(
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


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/read")
async def read(file: UploadFile = File(...), tier: policy.Tier = Form(policy.Tier.STANDARD), mode: str = Form("school"),
               engine: OCREngine = Depends(get_engine)) -> dict:
    feature = MODE_FEATURE.get(mode)
    if feature is None:
        raise HTTPException(400, {"code": "unknown_mode"})
    try:
        policy.require(tier, feature)
    except CodedError as e:
        raise HTTPException(403, {"code": e.code})
    try:
        image = Image.open(io.BytesIO(await file.read()))
        image.load()
    except Exception:
        raise HTTPException(400, {"code": "unreadable_image"})
    # Health and money papers get a second OCR pass so every number is read twice.
    result = read_page(image, engine, second_pass=mode in SECOND_PASS_MODES)
    # The uploaded photo is never stored: it only lives in memory for this request.
    warnings = safety.confidence_warnings(result["lines"]) + safety.number_warnings(result["lines"])
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


@app.get("/triage/questions")
def triage_questions() -> list[dict]:
    return triage.QUESTIONS


@app.post("/triage/assess")
def triage_assess(answers: dict) -> dict:
    r = triage.assess(answers)
    return {"priority": r.priority.value, "message": r.message}
