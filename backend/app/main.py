"""Magana API (hackathon MVP)."""
from __future__ import annotations

import io

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from PIL import Image
from pydantic import BaseModel

from . import policy, safety, triage
from .reader import read_page

app = FastAPI(title="Magana API", version="0.1.0")

MODE_FEATURE = {
    "school": policy.Feature.READ_SCHOOLWORK,
    "health": policy.Feature.EVERYDAY_HEALTH,
    "money": policy.Feature.EVERYDAY_MONEY,
}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/read")
async def read(file: UploadFile = File(...), tier: policy.Tier = Form(policy.Tier.STANDARD), mode: str = Form("school")) -> dict:
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
    result = read_page(image)
    # The uploaded photo is never stored: it only lives in memory for this request.
    warnings = safety.confidence_warnings(result["lines"])
    return {**result, "warnings": [w.__dict__ for w in warnings]}


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
