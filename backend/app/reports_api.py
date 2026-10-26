"""Report a problem (board 9): from the app (POST /reports) to the Magana team's "Reports" list
(/portal/admin/reports, every team role, Support included), with one email to support@ for each.

What a report holds (docs/PRIVACY.md, "Problem reports"):
- what went wrong: read something wrong, hard to use, too slow, something else;
- the app version, phone model, app language and screen it came from;
- for adults (18+) only, a voice note of up to 60 s, if they recorded one. Under-18s have no
  recording option in the app, and a voice note from one is refused here too;
- the page's text, only if the person switched "Include this page's text" on (off by default).
  Never in a Classroom session (nothing from one is kept). Never a photo.
Kept 180 days, then deleted. The email to support says what went wrong and where, never the
page text or the voice note: those are opened in the portal, which logs who played a voice note.
"""
from __future__ import annotations

import base64
import binascii
import logging
import os
from datetime import timedelta
from typing import Literal

from fastapi import APIRouter, Depends, Header, Request, Response
from pydantic import BaseModel, ConfigDict, Field

from . import accounts as A
from . import mailer
from .accounts import db, iso, now, parse
from .portal_api import Who, _client_ip, _limit, _mail, fail, ip_rate, portal_url, team, team_audit

log = logging.getLogger("magana.reports")
router = APIRouter()

KINDS = {"read_wrong": "It read something wrong", "hard_to_use": "It was hard to use", "too_slow": "It was too slow",
         "other": "Something else"}
VOICE_MAX_SECONDS = 60
VOICE_MAX_BYTES = 1_000_000  # 60 s of 32 kbit/s AAC is about 240 kB; WAV from a browser is bigger
VOICE_TYPES = {"audio/mp4", "audio/aac", "audio/webm", "audio/ogg", "audio/wav"}
KEEP_DAYS = 180
REPORTS_PER_HOUR = 10

SCHEMA = """
CREATE TABLE IF NOT EXISTS reports(
  id TEXT PRIMARY KEY, kind TEXT NOT NULL, screen TEXT NOT NULL, app_version TEXT NOT NULL, phone_model TEXT NOT NULL,
  language TEXT NOT NULL, tier TEXT NOT NULL, page_text TEXT, voice BLOB, voice_type TEXT, voice_seconds INTEGER,
  created_at TEXT NOT NULL);
"""


class ReportIn(BaseModel):
    model_config = ConfigDict(extra="forbid")  # nothing else is taken: no photo, no name, no phone number
    kind: Literal["read_wrong", "hard_to_use", "too_slow", "other"]
    screen: str = Field(max_length=40, pattern=r"^[a-z_]+$")
    app_version: str = Field(max_length=40)
    phone_model: str = Field(max_length=80)
    language: Literal["en", "ha", "yo", "ig"]
    page_text: str | None = Field(None, max_length=12_000)
    voice_note: str | None = Field(None, max_length=1_400_000)  # base64
    voice_type: str | None = Field(None, max_length=40)
    voice_seconds: int | None = Field(None, ge=1, le=VOICE_MAX_SECONDS)


def _purge(con) -> None:
    con.execute("DELETE FROM reports WHERE created_at < ?", (iso(now() - timedelta(days=KEEP_DAYS)),))


@router.post("/reports", status_code=201)
def send_report(body: ReportIn, request: Request, x_magana_tier: str = Header("classroom"),
                x_magana_device: str | None = Header(None)) -> dict:
    who = x_magana_device or _client_ip(request)
    if not ip_rate.allow(f"report:{who}", _limit("MAGANA_DEV_REPORT_LIMIT", REPORTS_PER_HOUR)):
        fail(429, "too_many_requests", retry_after=3600)
    tier = x_magana_tier if x_magana_tier in ("standard", "guided", "classroom") else "classroom"
    voice = None
    if body.voice_note is not None:
        if tier != "standard":
            fail(403, "voice_note_adults_only")  # under 18: a choice from the list only
        if body.voice_type not in VOICE_TYPES or body.voice_seconds is None:
            fail(400, "voice_note_unreadable")
        try:
            voice = base64.b64decode(body.voice_note, validate=True)
        except (binascii.Error, ValueError):
            fail(400, "voice_note_unreadable")
        if not voice or len(voice) > VOICE_MAX_BYTES:
            fail(413, "voice_note_too_long")
    page_text = (body.page_text or "").strip() or None
    if page_text and tier == "classroom":
        fail(403, "teacher_session_required")  # nothing from a Classroom session is kept
    rid = A.new_id("rep")
    with db() as con:
        _purge(con)
        con.execute("INSERT INTO reports(id, kind, screen, app_version, phone_model, language, tier, page_text, voice,"
                    " voice_type, voice_seconds, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                    (rid, body.kind, body.screen, body.app_version.strip(), body.phone_model.strip(), body.language,
                     tier, page_text, voice, body.voice_type if voice else None,
                     body.voice_seconds if voice else None, iso(now())))
    _mail(os.environ.get("MAGANA_REPORTS_EMAIL", mailer.reply_to()), mailer.problem_report(
        KINDS[body.kind], body.screen, body.app_version, body.phone_model, body.language, tier,
        voice_seconds=body.voice_seconds if voice else None, page_text=bool(page_text), when=now(),
        link=f"{portal_url()}/admin/reports/"))
    log.info("problem report: %s from %s", body.kind, body.screen)  # never the text or the voice note
    return {"code": "report_sent", "id": rid}


def _out(r: dict) -> dict:
    return {"id": r["id"], "kind": r["kind"], "kind_label": KINDS[r["kind"]], "screen": r["screen"],
            "app_version": r["app_version"], "phone_model": r["phone_model"], "language": r["language"],
            "age_group": {"standard": "18+", "guided": "13–17", "classroom": "Classroom"}[r["tier"]],
            "page_text": r["page_text"], "voice_seconds": r["voice_seconds"],
            "when": mailer.lagos_time(parse(r["created_at"]))}


@router.get("/portal/admin/reports")
def reports(who: Who = Depends(team)) -> list[dict]:
    """Newest first. Every team role, Support included (view only)."""
    with db() as con:
        _purge(con)
        rows = con.execute("SELECT id, kind, screen, app_version, phone_model, language, tier, page_text, voice_seconds,"
                           " created_at FROM reports ORDER BY created_at DESC, id DESC LIMIT 500").fetchall()
        return [_out(dict(r)) for r in rows]


@router.get("/portal/admin/reports/{report_id}/voice")
def report_voice(report_id: str, who: Who = Depends(team)) -> Response:
    with db() as con:
        r = A.row(con.execute("SELECT voice, voice_type FROM reports WHERE id = ?", (report_id,)).fetchone())
        if r is None or r["voice"] is None:
            fail(404, "not_found")
        team_audit(con, None, who, "team_report_voice_played", report_id)
    return Response(r["voice"], media_type=r["voice_type"], headers={
        "Cache-Control": "no-store", "Content-Disposition": "inline", "X-Content-Type-Options": "nosniff"})
