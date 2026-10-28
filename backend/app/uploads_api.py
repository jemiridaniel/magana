"""Teachers' uploads (/portal/uploads): a photo or PDF of a worksheet, notes or a test is
read like any page, and only its text is kept (never the file). An upload with handwriting
or anything Magana was unsure of stays at "check" until the teacher corrects its lines and
approves it; learners only ever get approved text (CLAUDE.md rule 2; docs/review/
handwriting_signoff.md, rule 7).
"""
from __future__ import annotations

import io
import json

from fastapi import APIRouter, Depends, File, Form, UploadFile
from PIL import Image
from pydantic import BaseModel, Field

from . import accounts as A
from . import pdfs, policy
from .accounts import db, iso, now
from .portal_api import Who, _class, fail, staff

router = APIRouter(prefix="/portal/uploads")
MAX_BYTES = 15 * 1024 * 1024


def _lines(body: dict) -> list[dict]:
    """The reading as plain lines for the Check screen: each with why it needs a look."""
    flags: dict[int, set[str]] = {}
    for w in body.get("warnings", []):
        flags.setdefault(w["block_index"], set()).add(w["code"])
    out = []
    items = [(l["top"], "line", i, l) for i, l in enumerate(body.get("lines", []))]
    items += [(t["top"], "table", i, t) for i, t in enumerate(body.get("tables", []))]
    cell_flags = {(w["table_index"], w["row"]) for w in body.get("cell_warnings", [])}
    for _, kind, i, item in sorted(items, key=lambda x: (x[0], x[1])):
        if kind == "line":
            codes = sorted(flags.get(i, set()))
            out.append({"text": item["text"], "handwritten": item.get("script") == "handwritten",
                        "flags": codes, "page": item.get("page")})
        else:
            rows = item["rows"]
            names = [c["text"] for c in rows[0]] if item.get("header") and rows else []
            for r, row in enumerate(rows[1:] if names else rows, start=1 if names else 0):
                text = " · ".join(f"{names[c['col']]}: {c['text']}" if c["col"] < len(names) and names[c["col"]] else c["text"]
                                  for c in row if c["text"])
                out.append({"text": text, "handwritten": False, "page": item.get("page"),
                            "flags": ["low_confidence"] if (i, r) in cell_flags else []})
    return out


def _out(u: dict, lines: bool = False) -> dict:
    d = {k: u[k] for k in ("id", "title", "status", "note", "class_id", "created_at", "approved_at")}
    d["script"] = u["handwriting"] or "printed"
    if lines:
        d["lines"] = json.loads(u["text"] or "[]")
    return d


def _mine(con, who: Who, upload_id: str) -> dict:
    u = A.row(con.execute("SELECT * FROM uploads WHERE id = ? AND school_id = ?", (upload_id, who.school["id"])).fetchone())
    if u is None or (not who.admin and u["teacher_id"] != who.staff["id"]):
        fail(404, "not_found")
    return u


@router.post("", status_code=201)
async def upload(file: UploadFile = File(...), class_id: str = Form(""), title: str = Form(""),
                 who: Who = Depends(staff)) -> dict:
    from .main import checked, get_engine, handwriting_reader  # main includes this router
    from .reader import read_page

    tier = policy.Tier.STANDARD
    with db() as con:
        if class_id:
            c = _class(con, who, class_id)
            tier = policy.Tier.STANDARD if c["mode"] == "standard" else policy.Tier.GUIDED
    data = await file.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        fail(413, "upload_too_big")
    engine = get_engine()
    try:
        if data[:5] == b"%PDF-":
            body = pdfs.read_pdf(data, None, engine, False, lambda r: checked(r, "school"))
            script = "printed"
        else:
            image = Image.open(io.BytesIO(data))
            image.load()
            body = checked(read_page(image, engine, handwriting=handwriting_reader("school", tier)), "school")
            script = body.get("script", "printed")
    except pdfs.PdfError as e:
        fail(400, "upload_locked" if e.code.startswith("pdf_password") else "upload_unreadable")
    except Exception:
        fail(400, "upload_unreadable")
    finally:
        del data  # the file itself is never kept
    lines = _lines(body)
    if not lines:
        fail(400, "upload_no_text")
    if any(l["handwritten"] for l in lines):
        script = "mixed" if not all(l["handwritten"] for l in lines) else "handwritten"
    unsure = any(l["flags"] for l in lines) or body.get("faint_regions")
    status = "check" if script != "printed" or unsure else "ready"
    note = "handwriting" if script != "printed" else "unsure" if unsure else ""
    name = (title or file.filename or "Upload").strip()[:120]
    with db() as con:
        uid = A.new_id("up")
        con.execute("INSERT INTO uploads(id, school_id, class_id, teacher_id, title, status, note, handwriting, text,"
                    " created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (uid, who.school["id"], class_id or None, who.staff["id"], name, status, note, script,
                     json.dumps(lines), iso(now())))
        A.audit(con, who.school["id"], who.id, "upload_added", uid, status=status)
        return {"code": "upload_saved", "upload": _out(dict(con.execute("SELECT * FROM uploads WHERE id = ?", (uid,)).fetchone()))}


@router.get("")
def list_uploads(who: Who = Depends(staff)) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT * FROM uploads WHERE school_id = ? AND (teacher_id = ? OR ? = 1) ORDER BY created_at DESC",
                           (who.school["id"], who.staff["id"], int(who.admin))).fetchall()
        return [_out(dict(r)) for r in rows]


@router.get("/{upload_id}")
def get_upload(upload_id: str, who: Who = Depends(staff)) -> dict:
    with db() as con:
        return _out(_mine(con, who, upload_id), lines=True)


class CheckIn(BaseModel):
    lines: list[str] = Field(max_length=2000)
    approve: bool = False


@router.put("/{upload_id}")
def check_upload(upload_id: str, body: CheckIn, who: Who = Depends(staff)) -> dict:
    """The teacher's corrections, line by line; with approve, the text is ready for learners."""
    with db() as con:
        u = _mine(con, who, upload_id)
        lines = json.loads(u["text"] or "[]")
        if len(body.lines) != len(lines):
            fail(400, "upload_lines_changed")
        changed = 0
        for l, text in zip(lines, body.lines):
            text = text.strip()[:2000]
            if text != l["text"]:
                l["text"], l["corrected"] = text, True
                changed += 1
        status = "ready" if body.approve else u["status"]
        con.execute("UPDATE uploads SET text = ?, status = ?, approved_by = ?, approved_at = ? WHERE id = ?",
                    (json.dumps(lines), status, who.staff["id"] if body.approve else u["approved_by"],
                     iso(now()) if body.approve else u["approved_at"], upload_id))
        A.audit(con, who.school["id"], who.id, "upload_approved" if body.approve else "upload_corrected", upload_id,
                changed=changed)
        return {"code": "upload_approved" if body.approve else "upload_corrections_saved",
                "upload": _out(dict(con.execute("SELECT * FROM uploads WHERE id = ?", (upload_id,)).fetchone()), lines=True)}
