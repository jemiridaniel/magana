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
from .reader import OCREngine, default_engine, read_page

app = FastAPI(title="Magana API", version="0.1.0")
# Browsers (Flutter web, teacher portal) need CORS. Dev allows any localhost port;
# production sets MAGANA_CORS_ORIGIN_REGEX to its own domains.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=os.environ.get("MAGANA_CORS_ORIGIN_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?"),
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

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
        raise HTTPException(400, "mode must be school, health or money")
    try:
        policy.require(tier, feature)
    except PermissionError as e:
        raise HTTPException(403, str(e))
    try:
        image = Image.open(io.BytesIO(await file.read()))
    except Exception:
        raise HTTPException(400, "Could not open that image.")
    result = read_page(image, engine)
    # The uploaded photo is never stored: it only lives in memory for this request.
    warnings = safety.confidence_warnings(result["lines"])
    cell_warnings = safety.table_warnings(result["tables"])
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
    return {"priority": r.priority.value, "spoken": r.spoken}
