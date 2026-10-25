"""The learner app's class link (/learner/...): join with a class code, check the link, and
change class (with the teacher's own code for under-18s).

The phone is linked by a random token the app keeps (X-Magana-Learner); the server stores
only its hash. No phone number, no name from the phone: the teacher names the learner in the
portal. Under-18s wait for a guardian's consent, which the teacher records in the portal;
until then the link is "waiting" and the learner may only read schoolwork pages.

Wrong codes: 3 tries per phone, then 5 minutes (codes.Attempts).
"""
from __future__ import annotations

import hashlib
import secrets

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

from . import accounts as A
from . import codes
from .accounts import db, iso, now

router = APIRouter(prefix="/learner")


def fail(status: int, code: str, **extra):
    raise HTTPException(status, {"code": code, **extra})


def token_lookup(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def linked(con, token: str | None) -> dict | None:
    if not token:
        return None
    return A.row(con.execute("SELECT * FROM learners WHERE token_lookup = ?", (token_lookup(token),)).fetchone())


def _attempt_key(request: Request, device: str | None, kind: str) -> str:
    who = device or (request.client.host if request.client else "unknown")
    return f"{kind}:{who}"


def _check_lock(key: str) -> None:
    if (wait := codes.attempts.locked_for(key)) > 0:
        fail(429, "code_locked", retry_after=int(wait) + 1)


def _wrong(key: str, code: str) -> None:
    wait = codes.attempts.failed(key)
    if wait:
        fail(429, "code_locked", retry_after=int(wait))
    fail(400, code)


def _status(l: dict) -> str:
    if l["status"] == "removed":
        return "removed"
    return "waiting_consent" if l["consent"] == "pending" else "active"


def _class_info(con, class_id: str) -> dict | None:
    c = con.execute("SELECT c.name, c.level, c.mode, s.name AS school, t.name AS teacher FROM classes c"
                    " JOIN schools s ON s.id = c.school_id LEFT JOIN staff t ON t.id = c.teacher_id WHERE c.id = ?",
                    (class_id,)).fetchone()
    return dict(c) if c else None


class JoinIn(BaseModel):
    class_code: str = Field(max_length=12)


@router.post("/join")
def join(body: JoinIn, request: Request, x_magana_tier: str = Header("standard"),
         x_magana_device: str | None = Header(None), x_magana_learner: str | None = Header(None)) -> dict:
    """Join a class with its code. An under-18 already in a class needs their teacher's code to
    move (POST /learner/change-class); an adult may simply join another."""
    if x_magana_tier == "classroom":
        fail(403, "teacher_session_required")  # under 13: teacher-run sessions only
    key = _attempt_key(request, x_magana_device, "join")
    _check_lock(key)
    under_18 = x_magana_tier == "guided"
    t = now()
    with db() as con:
        c = A.row(con.execute("SELECT c.*, s.status AS school_status FROM classes c JOIN schools s ON s.id = c.school_id"
                              " WHERE c.code_lookup = ?", (codes.lookup(body.class_code),)).fetchone())
        if c is None or c["school_status"] != "approved":
            _wrong(key, "class_code_wrong")
        codes.attempts.succeeded(key)
        if c["mode"] == "classroom":
            fail(409, "class_has_no_accounts")
        current = linked(con, x_magana_learner)
        if current and current["status"] == "active":
            if current["under_18"]:
                fail(409, "teacher_code_needed")
            con.execute("UPDATE learners SET class_id = ?, school_id = ? WHERE id = ?",
                        (c["id"], c["school_id"], current["id"]))
            A.audit(con, c["school_id"], f"learner:{current['id']}", "learner_changed_class", current["id"], to=c["id"])
            return {"code": "class_joined", "token": x_magana_learner, "status": _status(current),
                    "class": _class_info(con, c["id"])}
        token = secrets.token_urlsafe(32)
        lid = A.new_id("lrn")
        con.execute("INSERT INTO learners(id, school_id, class_id, name, under_18, consent, token_lookup, linked_at, status,"
                    " created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (lid, c["school_id"], c["id"], "New learner", int(under_18), "pending" if under_18 else "not_needed",
                     token_lookup(token), iso(t), "active", iso(t)))
        A.audit(con, c["school_id"], f"learner:{lid}", "learner_joined", lid, cls=c["id"])
        l = A.row(con.execute("SELECT * FROM learners WHERE id = ?", (lid,)).fetchone())
        return {"code": "class_joined", "token": token, "status": _status(l), "class": _class_info(con, c["id"])}


@router.get("/me")
def me(x_magana_learner: str | None = Header(None)) -> dict:
    with db() as con:
        l = linked(con, x_magana_learner)
        if l is None:
            # Unknown or unlinked (a teacher removed this phone): the app forgets the class.
            return {"status": "not_linked"}
        return {"status": _status(l), "under_18": bool(l["under_18"]), "consent": l["consent"],
                "class": _class_info(con, l["class_id"])}


class ChangeIn(BaseModel):
    teacher_code: str = Field(max_length=12)
    class_code: str = Field(max_length=12)


@router.post("/change-class")
def change_class(body: ChangeIn, request: Request, x_magana_device: str | None = Header(None),
                 x_magana_learner: str | None = Header(None)) -> dict:
    """An under-18 changes class only with a teacher's own code, checked here."""
    key = _attempt_key(request, x_magana_device, "teacher")
    _check_lock(key)
    with db() as con:
        l = linked(con, x_magana_learner)
        if l is None or l["status"] != "active":
            fail(409, "not_linked")
        c = A.row(con.execute("SELECT c.*, s.status AS school_status FROM classes c JOIN schools s ON s.id = c.school_id"
                              " WHERE c.code_lookup = ?", (codes.lookup(body.class_code),)).fetchone())
        teacher = A.row(con.execute("SELECT * FROM staff WHERE code_lookup = ? AND status = 'active'",
                                    (codes.lookup(body.teacher_code),)).fetchone())
        # The teacher must belong to the new class's school (and so would see the learner there).
        if teacher is None or c is None or teacher["school_id"] != c["school_id"]:
            _wrong(key, "teacher_code_wrong")
        codes.attempts.succeeded(key)
        if c["school_status"] != "approved" or c["mode"] == "classroom":
            fail(409, "class_has_no_accounts")
        same_school = c["school_id"] == l["school_id"]
        consent = l["consent"] if same_school else ("pending" if l["under_18"] else "not_needed")
        con.execute("UPDATE learners SET class_id = ?, school_id = ?, consent = ? WHERE id = ?",
                    (c["id"], c["school_id"], consent, l["id"]))
        A.audit(con, c["school_id"], teacher["id"], "learner_moved_by_teacher_code", l["id"], frm=l["class_id"], to=c["id"])
        l = A.row(con.execute("SELECT * FROM learners WHERE id = ?", (l["id"],)).fetchone())
        return {"code": "class_changed", "status": _status(l), "class": _class_info(con, c["id"])}


def consent_confirmed(token: str | None) -> bool | None:
    """For the policy check: None without a link; else whether this under-18's guardian agreed
    in the portal (adults: True)."""
    if not token:
        return None
    with db() as con:
        l = linked(con, token)
    if l is None or l["status"] != "active":
        return None
    return (not l["under_18"]) or l["consent"] == "received"
