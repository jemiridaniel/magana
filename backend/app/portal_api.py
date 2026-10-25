"""The teacher portal's API (/portal/...): sign-in, schools, staff, classes, learners.

Sign-in: email, then a 6-digit code (10 minutes) by email. Only invited emails (or the Magana
team's, MAGANA_TEAM_EMAILS) get one. The session is an HttpOnly, Secure, SameSite=Lax cookie on
api.magana.ng, ended after 30 minutes without activity (12 hours at most).

Roles: a school admin invites, edits and removes teachers, reassigns classes and sees every
class; a teacher sees only their own classes. Every school keeps at least 2 admins once it
has them, and never loses its last one. Invitations expire after 7 days. Removing a teacher
needs their classes moved first, and ends their sessions at once. Every such change goes in
the audit log.

Responses carry message codes (messages.PORTAL); the portal words them.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import time
from dataclasses import dataclass
from datetime import timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator

from . import accounts as A
from . import codes, curriculum, mailer, places
from .accounts import db, iso, now, parse

router = APIRouter(prefix="/portal")
COOKIE = "magana_portal"
CODE_GAP_S = 45          # "Send a new code (in 45 s)"
CODES_PER_HOUR = 5
IP_REQUESTS_PER_HOUR = 30
REGISTRATIONS_PER_HOUR = 5


def _limit(name: str, default: int) -> int:
    """Development servers (the portal's end-to-end tests) may raise a per-IP limit."""
    if os.environ.get("MAGANA_ENV") == "development" and os.environ.get(name) is not None:
        return int(os.environ[name])
    return default
EMAIL = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,190}\.[A-Za-z]{2,}$")


def fail(status: int, code: str, **extra):
    raise HTTPException(status, {"code": code, **extra})


def portal_url() -> str:
    return os.environ.get("MAGANA_PORTAL_URL", "https://teachers.magana.ng")


def team_emails() -> set[str]:
    return {e.strip().lower() for e in os.environ.get("MAGANA_TEAM_EMAILS", "").split(",") if e.strip()}


def _token_lookup(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# ---------- who is asking

@dataclass
class Who:
    kind: str                # "staff" | "team"
    staff: dict | None
    school: dict | None
    email: str

    @property
    def id(self) -> str:
        return self.staff["id"] if self.staff else f"team:{self.email}"

    @property
    def admin(self) -> bool:
        return bool(self.staff and self.staff["role"] == "admin")


def _who(request: Request) -> Who:
    token = request.cookies.get(COOKIE, "")
    if not token:
        fail(401, "not_signed_in")
    with db() as con:
        s = con.execute("SELECT * FROM sessions WHERE token_lookup = ?", (_token_lookup(token),)).fetchone()
        if s is None:
            fail(401, "not_signed_in")
        t = now()
        if (t - parse(s["last_seen"]) > timedelta(minutes=A.IDLE_MINUTES)
                or t - parse(s["created_at"]) > timedelta(hours=A.SESSION_MAX_HOURS)):
            con.execute("DELETE FROM sessions WHERE token_lookup = ?", (s["token_lookup"],))
            fail(401, "session_expired")
        con.execute("UPDATE sessions SET last_seen = ? WHERE token_lookup = ?", (iso(t), s["token_lookup"]))
        if s["who"].startswith("team:"):
            return Who("team", None, None, s["who"][5:])
        staff = A.row(con.execute("SELECT * FROM staff WHERE id = ?", (s["who"],)).fetchone())
        if staff is None or staff["status"] != "active":
            con.execute("DELETE FROM sessions WHERE token_lookup = ?", (s["token_lookup"],))
            fail(401, "not_signed_in")
        school = A.row(con.execute("SELECT * FROM schools WHERE id = ?", (staff["school_id"],)).fetchone())
        return Who("staff", staff, school, staff["email"])


def signed_in(request: Request) -> Who:
    return _who(request)


def staff(who: Who = Depends(signed_in)) -> Who:
    """A teacher or admin of an approved school."""
    if who.kind != "staff":
        fail(403, "not_for_team")
    if who.school["status"] != "approved":
        fail(403, "school_pending")
    return who


def admin(who: Who = Depends(staff)) -> Who:
    if not who.admin:
        fail(403, "not_admin")
    return who


def team(who: Who = Depends(signed_in)) -> Who:
    if who.kind != "team":
        fail(403, "not_team")
    return who


# ---------- sign-in

class _Rate:
    def __init__(self):
        self.hits: dict[str, list[float]] = {}

    def allow(self, key: str, limit: int, window: float = 3600) -> bool:
        t = time.monotonic()
        hits = [h for h in self.hits.get(key, []) if t - h < window]
        if len(hits) >= limit:
            self.hits[key] = hits
            return False
        self.hits[key] = hits + [t]
        return True


ip_rate = _Rate()


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


class EmailIn(BaseModel):
    email: str = Field(max_length=254)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if not EMAIL.match(v):
            raise ValueError("not an email address")
        return v


def _can_sign_in(con, email: str) -> bool:
    if email in team_emails():
        return True
    s = con.execute("SELECT * FROM staff WHERE email = ? AND status != 'removed'", (email,)).fetchone()
    if s is None:
        return False
    if s["status"] == "invited" and parse(s["invite_expires"]) < now():
        return False
    school = con.execute("SELECT status FROM schools WHERE id = ?", (s["school_id"],)).fetchone()
    return school is not None and school["status"] != "rejected"


@router.post("/auth/request-code")
def request_code(body: EmailIn, request: Request) -> dict:
    """Always answers the same way, so it never tells whether an email has an account."""
    if not ip_rate.allow(f"ip:{_client_ip(request)}", _limit("MAGANA_DEV_SIGNIN_LIMIT", IP_REQUESTS_PER_HOUR)):
        fail(429, "too_many_requests", retry_after=600)
    t = now()
    with db() as con:
        old = A.row(con.execute("SELECT * FROM login_codes WHERE email = ?", (body.email,)).fetchone())
        gap = _limit("MAGANA_DEV_CODE_GAP", CODE_GAP_S)
        if old and (t - parse(old["sent_at"])).total_seconds() < gap:
            wait = gap - int((t - parse(old["sent_at"])).total_seconds())
            fail(429, "code_sent_recently", retry_after=max(1, wait))
        count, since = (old["sent_count"], parse(old["count_since"])) if old else (0, t)
        if t - since > timedelta(hours=1):
            count, since = 0, t
        if count >= _limit("MAGANA_DEV_CODES_PER_HOUR", CODES_PER_HOUR):
            fail(429, "too_many_codes", retry_after=3600 - int((t - since).total_seconds()))
        allowed = _can_sign_in(con, body.email)
        code = codes.new_code() if allowed else None
        con.execute("INSERT OR REPLACE INTO login_codes(email, code_lookup, expires, wrong, sent_at, sent_count, count_since)"
                    " VALUES (?,?,?,?,?,?,?)",
                    (body.email, codes.lookup(code) if code else "none", iso(t + timedelta(minutes=A.LOGIN_CODE_MINUTES)),
                     0, iso(t), count + 1, iso(since)))
    if code:
        try:
            mailer.sign_in_code(body.email, code)
        except mailer.MailError:
            fail(503, "mail_unavailable")
    return {"code": "sign_in_code_sent", "retry_after": CODE_GAP_S, "minutes": A.LOGIN_CODE_MINUTES}


class VerifyIn(EmailIn):
    code: str = Field(max_length=12)


@router.post("/auth/verify")
def verify(body: VerifyIn, request: Request, response: Response) -> dict:
    key = f"signin:{body.email}"
    if (wait := codes.attempts.locked_for(key)) > 0:
        fail(429, "code_locked", retry_after=int(wait) + 1)
    t = now()
    with db() as con:
        lc = A.row(con.execute("SELECT * FROM login_codes WHERE email = ?", (body.email,)).fetchone())
        good = (lc is not None and parse(lc["expires"]) > t and lc["code_lookup"] != "none"
                and secrets.compare_digest(lc["code_lookup"], codes.lookup(body.code)))
        if not good:
            if lc and parse(lc["expires"]) <= t:
                fail(400, "sign_in_code_expired")
            wait = codes.attempts.failed(key)
            fail(429 if wait else 400, "code_locked" if wait else "sign_in_code_wrong",
                 **({"retry_after": int(wait)} if wait else {}))
        con.execute("DELETE FROM login_codes WHERE email = ?", (body.email,))
        if body.email in team_emails():
            who = f"team:{body.email}"
        else:
            s = con.execute("SELECT * FROM staff WHERE email = ? AND status != 'removed'", (body.email,)).fetchone()
            if s is None:
                fail(400, "sign_in_code_wrong")
            if s["status"] == "invited":
                con.execute("UPDATE staff SET status = 'active' WHERE id = ?", (s["id"],))
                A.audit(con, s["school_id"], s["id"], "invite_accepted", s["id"])
            who = s["id"]
        token = secrets.token_urlsafe(32)
        con.execute("INSERT INTO sessions(token_lookup, who, created_at, last_seen) VALUES (?,?,?,?)",
                    (_token_lookup(token), who, iso(t), iso(t)))
    codes.attempts.succeeded(key)
    secure = os.environ.get("MAGANA_ENV", "production") != "development"
    response.set_cookie(COOKIE, token, httponly=True, secure=secure, samesite="lax", path="/")
    return {"code": "signed_in", "me": me(_who_from(token))}


def _who_from(token: str) -> Who:
    class R:  # the request's cookies, for the response to the sign-in itself
        cookies = {COOKIE: token}
    return _who(R())  # type: ignore[arg-type]


@router.post("/auth/sign-out")
def sign_out(request: Request, response: Response) -> dict:
    token = request.cookies.get(COOKIE, "")
    if token:
        with db() as con:
            con.execute("DELETE FROM sessions WHERE token_lookup = ?", (_token_lookup(token),))
    response.delete_cookie(COOKIE, path="/")
    return {"code": "signed_out"}


@router.get("/me")
def me(who: Who = Depends(signed_in)) -> dict:
    if who.kind == "team":
        return {"kind": "team", "email": who.email, "name": "Magana team"}
    school = who.school
    return {"kind": "staff", "id": who.staff["id"], "name": who.staff["name"], "email": who.email,
            "role": who.staff["role"], "title": who.staff["title"],
            "school": {"id": school["id"], "name": school["name"], "status": school["status"],
                       "state": school["state"], "lga": school["lga"]}}


# ---------- registering a school (public), approving it (Magana team)

class RegisterIn(EmailIn):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=2, max_length=120)
    role: Literal["Principal", "Head teacher", "Vice principal", "Proprietor", "Other"]
    phone: str = Field(max_length=20)
    school: str = Field(min_length=2, max_length=160)
    state: str
    lga: str
    agree: bool

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        d = re.sub(r"[\s\-().]", "", v)
        if re.fullmatch(r"0[789][01]\d{8}", d):
            return "+234" + d[1:]
        if re.fullmatch(r"\+?234[789][01]\d{8}", d):
            return "+" + d.lstrip("+")
        raise ValueError("not a Nigerian mobile number")


@router.post("/schools/register", status_code=201)
def register_school(body: RegisterIn, request: Request) -> dict:
    if not ip_rate.allow(f"register:{_client_ip(request)}", _limit("MAGANA_DEV_REGISTER_LIMIT", REGISTRATIONS_PER_HOUR)):
        fail(429, "too_many_requests", retry_after=3600)
    if not body.agree:
        fail(400, "agree_required")
    if not places.valid(body.state, body.lga):
        fail(400, "place_unknown")
    t = now()
    with db() as con:
        if con.execute("SELECT 1 FROM staff WHERE email = ? AND status != 'removed'", (body.email,)).fetchone():
            fail(409, "email_taken")
        sid, aid = A.new_id("sch"), A.new_id("stf")
        con.execute("INSERT INTO schools(id, name, state, lga, status, contact_name, contact_role, contact_email,"
                    " contact_phone, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (sid, body.school.strip(), body.state, body.lga, "pending", body.name.strip(), body.role,
                     body.email, body.phone, iso(t)))
        _, lk, sealed = A.fresh_code(con, "staff")
        con.execute("INSERT INTO staff(id, school_id, name, email, role, title, status, created_at, code_lookup, code_sealed)"
                    " VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (aid, sid, body.name.strip(), body.email, "admin", body.role, "active", iso(t), lk, sealed))
        A.audit(con, sid, aid, "school_registered", sid)
    return {"code": "school_registered", "school_id": sid}


@router.get("/admin/schools")
def list_schools(status: str = "pending", who: Who = Depends(team)) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT * FROM schools WHERE status = ? ORDER BY created_at", (status,)).fetchall()
        return [{**dict(r), "state_name": places.state_name(r["state"]), "lga_name": places.lga_name(r["lga"])}
                for r in rows]


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]


@router.post("/admin/schools/{school_id}")
def decide_school(school_id: str, body: DecisionIn, who: Who = Depends(team)) -> dict:
    with db() as con:
        s = con.execute("SELECT * FROM schools WHERE id = ?", (school_id,)).fetchone()
        if s is None:
            fail(404, "not_found")
        status = "approved" if body.decision == "approve" else "rejected"
        con.execute("UPDATE schools SET status = ?, decided_at = ?, decided_by = ? WHERE id = ?",
                    (status, iso(now()), who.email, school_id))
        A.audit(con, school_id, who.id, f"school_{status}", school_id)
    return {"code": f"school_{status}"}


# ---------- staff (school admins)

def _staff_out(con, s: dict) -> dict:
    classes = con.execute("SELECT id, name FROM classes WHERE teacher_id = ? ORDER BY name", (s["id"],)).fetchall()
    expired = s["status"] == "invited" and parse(s["invite_expires"]) < now()
    return {"id": s["id"], "name": s["name"], "email": s["email"], "role": s["role"], "title": s["title"],
            "status": "expired" if expired else s["status"], "invited_at": s["invited_at"],
            "removed_at": s["removed_at"], "classes": [dict(c) for c in classes]}


@router.get("/staff")
def list_staff(who: Who = Depends(admin)) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT * FROM staff WHERE school_id = ? ORDER BY status = 'removed', role, name",
                           (who.school["id"],)).fetchall()
        return [_staff_out(con, dict(r)) for r in rows]


class InviteIn(EmailIn):
    name: str = Field(min_length=2, max_length=120)
    role: Literal["admin", "teacher"] = "teacher"
    title: str = Field("", max_length=60)
    class_ids: list[str] = Field(default_factory=list, max_length=20)


def _admins(con, school_id: str) -> int:
    return con.execute("SELECT COUNT(*) FROM staff WHERE school_id = ? AND role = 'admin' AND status = 'active'",
                       (school_id,)).fetchone()[0]


@router.post("/staff", status_code=201)
def invite(body: InviteIn, who: Who = Depends(admin)) -> dict:
    t = now()
    with db() as con:
        if con.execute("SELECT 1 FROM staff WHERE email = ? AND status != 'removed'", (body.email,)).fetchone():
            fail(409, "email_taken")
        sid = A.new_id("stf")
        _, lk, sealed = A.fresh_code(con, "staff")
        con.execute("INSERT INTO staff(id, school_id, name, email, role, title, status, invited_by, invited_at,"
                    " invite_expires, created_at, code_lookup, code_sealed) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (sid, who.school["id"], body.name.strip(), body.email, body.role, body.title.strip(), "invited",
                     who.id, iso(t), iso(t + timedelta(days=A.INVITE_DAYS)), iso(t), lk, sealed))
        for cid in body.class_ids:
            _class_for_admin(con, who, cid)
            con.execute("UPDATE classes SET teacher_id = ? WHERE id = ?", (sid, cid))
        A.audit(con, who.school["id"], who.id, "staff_invited", sid, role=body.role, classes=body.class_ids)
    _send_invite(body.email, who)
    return {"code": "invite_sent", "id": sid}


def _send_invite(email: str, who: Who) -> None:
    try:
        mailer.invitation(email, who.school["name"], who.staff["name"], portal_url())
    except mailer.MailError:
        fail(503, "mail_unavailable")


def _staff_in_school(con, who: Who, staff_id: str) -> dict:
    s = A.row(con.execute("SELECT * FROM staff WHERE id = ? AND school_id = ?", (staff_id, who.school["id"])).fetchone())
    if s is None:
        fail(404, "not_found")
    return s


@router.post("/staff/{staff_id}/resend")
def resend_invite(staff_id: str, who: Who = Depends(admin)) -> dict:
    t = now()
    with db() as con:
        s = _staff_in_school(con, who, staff_id)
        if s["status"] != "invited":
            fail(409, "not_invited")
        con.execute("UPDATE staff SET invited_at = ?, invite_expires = ? WHERE id = ?",
                    (iso(t), iso(t + timedelta(days=A.INVITE_DAYS)), staff_id))
        A.audit(con, who.school["id"], who.id, "invite_resent", staff_id)
    _send_invite(s["email"], who)
    return {"code": "invite_sent"}


@router.post("/staff/{staff_id}/cancel")
def cancel_invite(staff_id: str, who: Who = Depends(admin)) -> dict:
    with db() as con:
        s = _staff_in_school(con, who, staff_id)
        if s["status"] != "invited":
            fail(409, "not_invited")
        con.execute("UPDATE classes SET teacher_id = NULL WHERE teacher_id = ?", (staff_id,))
        con.execute("UPDATE staff SET status = 'removed', removed_at = ? WHERE id = ?", (iso(now()), staff_id))
        A.audit(con, who.school["id"], who.id, "invite_cancelled", staff_id)
    return {"code": "invite_cancelled"}


class StaffEdit(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(None, min_length=2, max_length=120)
    role: Literal["admin", "teacher"] | None = None
    title: str | None = Field(None, max_length=60)
    class_ids: list[str] | None = Field(None, max_length=20)


@router.patch("/staff/{staff_id}")
def edit_staff(staff_id: str, body: StaffEdit, who: Who = Depends(admin)) -> dict:
    with db() as con:
        s = _staff_in_school(con, who, staff_id)
        if s["status"] == "removed":
            fail(409, "staff_removed_already")
        if body.role == "teacher" and s["role"] == "admin" and s["status"] == "active":
            _check_admins_left(con, who.school["id"])
        changes = {k: v for k, v in body.model_dump(exclude={"class_ids"}).items() if v is not None}
        for k, v in changes.items():
            con.execute(f"UPDATE staff SET {k} = ? WHERE id = ?", (v.strip() if isinstance(v, str) else v, staff_id))
        if body.class_ids is not None:
            for cid in body.class_ids:
                _class_for_admin(con, who, cid)
                con.execute("UPDATE classes SET teacher_id = ? WHERE id = ?", (staff_id, cid))
        A.audit(con, who.school["id"], who.id, "staff_changed", staff_id,
                **changes, **({"classes": body.class_ids} if body.class_ids is not None else {}))
        return _staff_out(con, A.row(con.execute("SELECT * FROM staff WHERE id = ?", (staff_id,)).fetchone()))


def _check_admins_left(con, school_id: str) -> None:
    """An admin leaving (removed or made a teacher): never the last one, and never fewer than 2
    once the school has them."""
    n = _admins(con, school_id)
    if n <= 1:
        fail(409, "last_admin")
    if n <= 2:
        fail(409, "admins_minimum")


class RemoveStaffIn(BaseModel):
    # Each of their classes and its new teacher; all of them must be moved first.
    reassign: dict[str, str] = Field(default_factory=dict)


@router.post("/staff/{staff_id}/remove")
def remove_staff(staff_id: str, body: RemoveStaffIn, who: Who = Depends(admin)) -> dict:
    with db() as con:
        s = _staff_in_school(con, who, staff_id)
        if s["status"] == "removed":
            fail(409, "staff_removed_already")
        if s["role"] == "admin" and s["status"] == "active":
            _check_admins_left(con, who.school["id"])
        theirs = [r["id"] for r in con.execute("SELECT id FROM classes WHERE teacher_id = ?", (staff_id,))]
        missing = [c for c in theirs if c not in body.reassign]
        if missing:
            fail(409, "classes_need_new_teacher", classes=missing)
        for cid, new_teacher in body.reassign.items():
            if cid not in theirs:
                continue
            nt = _staff_in_school(con, who, new_teacher)
            if nt["status"] == "removed" or nt["id"] == staff_id:
                fail(400, "new_teacher_invalid")
            con.execute("UPDATE classes SET teacher_id = ? WHERE id = ?", (new_teacher, cid))
        con.execute("UPDATE staff SET status = 'removed', removed_at = ? WHERE id = ?", (iso(now()), staff_id))
        ended = con.execute("DELETE FROM sessions WHERE who = ?", (staff_id,)).rowcount
        A.audit(con, who.school["id"], who.id, "staff_removed", staff_id, reassigned=body.reassign, sessions_ended=ended)
    return {"code": "staff_removed"}


# ---------- classes

MODES = ("guided", "classroom", "standard")


def _visible_classes(con, who: Who) -> list[dict]:
    if who.admin:
        q = con.execute("SELECT * FROM classes WHERE school_id = ? ORDER BY name", (who.school["id"],))
    else:
        q = con.execute("SELECT * FROM classes WHERE teacher_id = ? ORDER BY name", (who.staff["id"],))
    return [dict(r) for r in q]


def _class(con, who: Who, class_id: str) -> dict:
    c = A.row(con.execute("SELECT * FROM classes WHERE id = ? AND school_id = ?", (class_id, who.school["id"])).fetchone())
    if c is None or (not who.admin and c["teacher_id"] != who.staff["id"]):
        fail(404, "not_found")
    return c


def _class_for_admin(con, who: Who, class_id: str) -> dict:
    c = A.row(con.execute("SELECT * FROM classes WHERE id = ? AND school_id = ?", (class_id, who.school["id"])).fetchone())
    if c is None:
        fail(404, "not_found")
    return c


def _class_out(con, c: dict) -> dict:
    learners = con.execute("SELECT consent, status FROM learners WHERE class_id = ? AND status = 'active'",
                           (c["id"],)).fetchall()
    teacher = con.execute("SELECT name FROM staff WHERE id = ?", (c["teacher_id"],)).fetchone()
    att = con.execute("SELECT SUM(mark != 'absent'), COUNT(*) FROM attendance WHERE class_id = ?", (c["id"],)).fetchone()
    return {"id": c["id"], "name": c["name"], "level": c["level"], "mode": c["mode"],
            "teacher_id": c["teacher_id"], "teacher": teacher["name"] if teacher else None,
            "code": codes.unseal(c["code_sealed"]),
            "learners": len(learners), "consents_needed": sum(1 for r in learners if r["consent"] != "not_needed"),
            "consents_received": sum(1 for r in learners if r["consent"] == "received"),
            "attendance": round(100 * att[0] / att[1]) if att[1] else None}


@router.get("/classes")
def list_classes(who: Who = Depends(staff)) -> list[dict]:
    with db() as con:
        return [_class_out(con, c) for c in _visible_classes(con, who)]


class ClassIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=80)
    level: str
    mode: Literal["guided", "classroom", "standard"]
    teacher_id: str | None = None

    @field_validator("level")
    @classmethod
    def _level(cls, v: str) -> str:
        if not curriculum.is_level(v):
            raise ValueError("unknown class level")
        return v


@router.post("/classes", status_code=201)
def create_class(body: ClassIn, who: Who = Depends(staff)) -> dict:
    with db() as con:
        teacher = who.staff["id"]
        if body.teacher_id and body.teacher_id != teacher:
            if not who.admin:
                fail(403, "not_admin")
            teacher = _staff_in_school(con, who, body.teacher_id)["id"]
        cid = A.new_id("cls")
        _, lk, sealed = A.fresh_code(con, "classes")
        con.execute("INSERT INTO classes(id, school_id, teacher_id, name, level, mode, code_lookup, code_sealed, created_at)"
                    " VALUES (?,?,?,?,?,?,?,?,?)",
                    (cid, who.school["id"], teacher, body.name.strip(), body.level, body.mode, lk, sealed, iso(now())))
        A.audit(con, who.school["id"], who.id, "class_created", cid, name=body.name.strip(), teacher=teacher)
        return _class_out(con, A.row(con.execute("SELECT * FROM classes WHERE id = ?", (cid,)).fetchone()))


class ClassEdit(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(None, min_length=1, max_length=80)
    teacher_id: str | None = None


@router.patch("/classes/{class_id}")
def edit_class(class_id: str, body: ClassEdit, who: Who = Depends(staff)) -> dict:
    with db() as con:
        c = _class(con, who, class_id)
        if body.name:
            con.execute("UPDATE classes SET name = ? WHERE id = ?", (body.name.strip(), class_id))
        if body.teacher_id and body.teacher_id != c["teacher_id"]:
            if not who.admin:
                fail(403, "not_admin")
            nt = _staff_in_school(con, who, body.teacher_id)
            if nt["status"] == "removed":
                fail(400, "new_teacher_invalid")
            con.execute("UPDATE classes SET teacher_id = ? WHERE id = ?", (nt["id"], class_id))
            A.audit(con, who.school["id"], who.id, "class_reassigned", class_id, frm=c["teacher_id"], to=nt["id"])
        return _class_out(con, A.row(con.execute("SELECT * FROM classes WHERE id = ?", (class_id,)).fetchone()))


@router.post("/classes/{class_id}/rotate-code")
def rotate_class_code(class_id: str, who: Who = Depends(staff)) -> dict:
    with db() as con:
        _class(con, who, class_id)
        code, lk, sealed = A.fresh_code(con, "classes")
        con.execute("UPDATE classes SET code_lookup = ?, code_sealed = ? WHERE id = ?", (lk, sealed, class_id))
        A.audit(con, who.school["id"], who.id, "class_code_rotated", class_id)
    return {"code": "class_code_rotated", "class_code": code}


@router.get("/me/teacher-code")
def teacher_code(who: Who = Depends(staff)) -> dict:
    return {"teacher_code": codes.unseal(who.staff["code_sealed"])}


@router.post("/me/teacher-code/rotate")
def rotate_teacher_code(who: Who = Depends(staff)) -> dict:
    with db() as con:
        code, lk, sealed = A.fresh_code(con, "staff")
        con.execute("UPDATE staff SET code_lookup = ?, code_sealed = ? WHERE id = ?", (lk, sealed, who.staff["id"]))
        A.audit(con, who.school["id"], who.id, "teacher_code_rotated", who.staff["id"])
    return {"code": "teacher_code_rotated", "teacher_code": code}


# ---------- learners

def _learner_out(con, l: dict, detail: bool = False) -> dict:
    out = {"id": l["id"], "name": l["name"], "class_id": l["class_id"], "formats": [f for f in l["formats"].split(",") if f],
           "language": l["language"], "under_18": bool(l["under_18"]), "consent": l["consent"],
           "consent_at": l["consent_at"], "phone_linked": l["token_lookup"] is not None, "status": l["status"],
           "removed_at": l["removed_at"], "removed_reason": l["removed_reason"], "joined_at": l["created_at"],
           "reminder_at": l["reminder_at"]}
    if detail:
        att = con.execute("SELECT SUM(mark != 'absent'), COUNT(*) FROM attendance WHERE learner_id = ?", (l["id"],)).fetchone()
        st = con.execute("SELECT SUM(pages), SUM(unaided), AVG(quiz_avg) FROM learner_stats WHERE learner_id = ?",
                         (l["id"],)).fetchone()
        out["term"] = {"sessions_attended": att[0] or 0, "sessions": att[1],
                       "attendance": round(100 * (att[0] or 0) / att[1]) if att[1] else None,
                       "pages": st[0], "unaided": round(100 * st[1] / st[0]) if st[0] else None,
                       "quiz_average": round(st[2]) if st[2] is not None else None}
        pending = con.execute("SELECT id, status, due FROM deletions WHERE learner_id = ? AND status = 'pending'",
                              (l["id"],)).fetchone()
        out["deletion"] = dict(pending) if pending else None
    return out


@router.get("/classes/{class_id}/learners")
def class_learners(class_id: str, who: Who = Depends(staff)) -> list[dict]:
    with db() as con:
        _class(con, who, class_id)
        rows = con.execute("SELECT * FROM learners WHERE class_id = ? ORDER BY status, name", (class_id,)).fetchall()
        return [_learner_out(con, dict(r)) for r in rows]


def _learner(con, who: Who, learner_id: str) -> dict:
    l = A.row(con.execute("SELECT * FROM learners WHERE id = ? AND school_id = ?", (learner_id, who.school["id"])).fetchone())
    if l is None:
        fail(404, "not_found")
    if not who.admin:
        c = con.execute("SELECT teacher_id FROM classes WHERE id = ?", (l["class_id"],)).fetchone()
        if c is None or c["teacher_id"] != who.staff["id"]:
            fail(404, "not_found")
    return l


@router.get("/learners/{learner_id}")
def learner(learner_id: str, who: Who = Depends(staff)) -> dict:
    with db() as con:
        l = _learner(con, who, learner_id)
        out = _learner_out(con, l, detail=True)
        c = con.execute("SELECT id, name, mode FROM classes WHERE id = ?", (l["class_id"],)).fetchone()
        out["class"] = dict(c) if c else None
        return out


class LearnerEdit(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(None, min_length=1, max_length=80)
    formats: list[Literal["audio", "braille", "large_print"]] | None = None
    language: Literal["en", "ha", "yo", "ig"] | None = None


@router.patch("/learners/{learner_id}")
def edit_learner(learner_id: str, body: LearnerEdit, who: Who = Depends(staff)) -> dict:
    with db() as con:
        _learner(con, who, learner_id)
        if body.name is not None:
            con.execute("UPDATE learners SET name = ? WHERE id = ?", (body.name.strip(), learner_id))
        if body.formats is not None:
            con.execute("UPDATE learners SET formats = ? WHERE id = ?", (",".join(body.formats), learner_id))
        if body.language is not None:
            con.execute("UPDATE learners SET language = ? WHERE id = ?", (body.language, learner_id))
        return _learner_out(con, _learner(con, who, learner_id))


class ConsentIn(BaseModel):
    # How the guardian agreed (signed form, in person...): no guardian personal details.
    how: Literal["signed_form", "in_person", "phone_call"]


@router.post("/learners/{learner_id}/consent")
def record_consent(learner_id: str, body: ConsentIn, who: Who = Depends(staff)) -> dict:
    with db() as con:
        l = _learner(con, who, learner_id)
        if not l["under_18"]:
            fail(409, "consent_not_needed")
        con.execute("UPDATE learners SET consent = 'received', consent_at = ?, consent_note = ? WHERE id = ?",
                    (iso(now()), body.how, learner_id))
        A.audit(con, who.school["id"], who.id, "consent_recorded", learner_id, how=body.how)
    return {"code": "consent_recorded"}


@router.post("/learners/{learner_id}/remind")
def consent_reminder(learner_id: str, who: Who = Depends(staff)) -> dict:
    """Magana holds no guardian contact: the portal gives the teacher a message to send."""
    with db() as con:
        l = _learner(con, who, learner_id)
        if l["consent"] != "pending":
            fail(409, "consent_not_pending")
        con.execute("UPDATE learners SET reminder_at = ? WHERE id = ?", (iso(now()), learner_id))
        c = con.execute("SELECT name FROM classes WHERE id = ?", (l["class_id"],)).fetchone()
    return {"code": "reminder_ready", "class_name": c["name"] if c else "", "school": who.school["name"]}


class MoveIn(BaseModel):
    class_id: str


@router.post("/learners/{learner_id}/move")
def move_learner(learner_id: str, body: MoveIn, who: Who = Depends(staff)) -> dict:
    with db() as con:
        l = _learner(con, who, learner_id)
        if l["status"] != "active":
            fail(409, "learner_removed_cannot_move")
        target = A.row(con.execute("SELECT * FROM classes WHERE id = ? AND school_id = ?",
                                   (body.class_id, who.school["id"])).fetchone())
        if target is None:
            fail(404, "not_found")  # only within the same school
        if target["mode"] == "classroom":
            fail(409, "class_has_no_accounts")
        con.execute("UPDATE learners SET class_id = ? WHERE id = ?", (target["id"], learner_id))
        A.audit(con, who.school["id"], who.id, "learner_moved", learner_id, frm=l["class_id"], to=target["id"])
    return {"code": "learner_moved"}


class RemoveLearnerIn(BaseModel):
    reason: Literal["left", "mistake", "deletion"] | None = None


@router.post("/learners/{learner_id}/remove")
def remove_learner(learner_id: str, body: RemoveLearnerIn, who: Who = Depends(staff)) -> dict:
    if body.reason is None:
        fail(400, "reason_required")
    t = now()
    with db() as con:
        l = _learner(con, who, learner_id)
        # The phone is unlinked at once; the term's records stay with the school.
        con.execute("UPDATE learners SET token_lookup = NULL, status = 'removed', removed_at = ?, removed_reason = ?"
                    " WHERE id = ?", (iso(t), body.reason, learner_id))
        A.audit(con, who.school["id"], who.id, "learner_removed", learner_id, reason=body.reason)
        deletion = None
        if body.reason == "deletion":
            deletion = A.new_id("del")
            con.execute("INSERT INTO deletions(id, school_id, learner_id, requested_by, requested_at, due, status)"
                        " VALUES (?,?,?,?,?,?,?)", (deletion, who.school["id"], learner_id, who.id, iso(t),
                                                     iso(t + timedelta(days=A.DELETE_WITHIN_DAYS)), "pending"))
            A.audit(con, who.school["id"], who.id, "deletion_requested", deletion)
    return {"code": "learner_removed", "deletion_id": deletion}


@router.get("/deletions")
def list_deletions(who: Who = Depends(admin)) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT d.*, l.name AS learner_name FROM deletions d LEFT JOIN learners l ON l.id = d.learner_id"
                           " WHERE d.school_id = ? AND d.status = 'pending' ORDER BY d.due", (who.school["id"],)).fetchall()
        return [dict(r) for r in rows]


def delete_learner_data(con, learner_id: str) -> None:
    """Everything about one learner, gone: their row, attendance, figures and audit mentions."""
    con.execute("DELETE FROM attendance WHERE learner_id = ?", (learner_id,))
    con.execute("DELETE FROM learner_stats WHERE learner_id = ?", (learner_id,))
    con.execute("DELETE FROM learners WHERE id = ?", (learner_id,))
    con.execute("UPDATE audit SET target = 'deleted-learner', detail = '{}' WHERE target = ?", (learner_id,))
    con.execute("UPDATE audit SET actor = 'deleted-learner', detail = '{}' WHERE actor = ?", (f"learner:{learner_id}",))
    con.execute("UPDATE deletions SET learner_id = 'deleted-learner' WHERE learner_id = ?", (learner_id,))


@router.post("/deletions/{deletion_id}/confirm")
def confirm_deletion(deletion_id: str, who: Who = Depends(admin)) -> dict:
    with db() as con:
        d = A.row(con.execute("SELECT * FROM deletions WHERE id = ? AND school_id = ?",
                              (deletion_id, who.school["id"])).fetchone())
        if d is None or d["status"] != "pending":
            fail(404, "not_found")
        delete_learner_data(con, d["learner_id"])
        con.execute("UPDATE deletions SET status = 'done', confirmed_by = ?, done_at = ? WHERE id = ?",
                    (who.id, iso(now()), deletion_id))
        A.audit(con, who.school["id"], who.id, "learner_data_deleted", "deleted-learner", request=deletion_id)
    return {"code": "learner_data_deleted"}


# ---------- attendance

class Mark(BaseModel):
    learner_id: str
    mark: Literal["present", "absent", "late"]


class RegisterMarks(BaseModel):
    day: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    marks: list[Mark] = Field(max_length=200)


@router.put("/classes/{class_id}/attendance")
def save_attendance(class_id: str, body: RegisterMarks, who: Who = Depends(staff)) -> dict:
    with db() as con:
        _class(con, who, class_id)
        ids = {r["id"] for r in con.execute("SELECT id FROM learners WHERE class_id = ? AND status = 'active'", (class_id,))}
        for m in body.marks:
            if m.learner_id not in ids:
                fail(400, "learner_not_in_class")
            con.execute("INSERT OR REPLACE INTO attendance(class_id, learner_id, day, mark) VALUES (?,?,?,?)",
                        (class_id, m.learner_id, body.day, m.mark))
    return {"code": "register_saved"}


@router.get("/classes/{class_id}/attendance")
def get_attendance(class_id: str, day: str, who: Who = Depends(staff)) -> dict:
    with db() as con:
        _class(con, who, class_id)
        rows = con.execute("SELECT learner_id, mark FROM attendance WHERE class_id = ? AND day = ?", (class_id, day))
        return {"day": day, "marks": {r["learner_id"]: r["mark"] for r in rows}}


# ---------- Home

LOW_ATTENDANCE = 60


@router.get("/home")
def home(who: Who = Depends(staff)) -> dict:
    with db() as con:
        classes = _visible_classes(con, who)
        ids = [c["id"] for c in classes]
        marks = ",".join("?" * len(ids)) or "''"
        learners = [dict(r) for r in con.execute(
            f"SELECT * FROM learners WHERE class_id IN ({marks}) AND status = 'active'", ids)] if ids else []
        by_class = {c["id"]: c["name"] for c in classes}
        attention = []
        pending = [l for l in learners if l["consent"] == "pending"]
        if pending:
            attention.append({"kind": "consent", "count": len(pending),
                              "learners": [{"id": l["id"], "name": l["name"], "class": by_class.get(l["class_id"])}
                                           for l in pending[:5]]})
        uploads = [dict(r) for r in con.execute(
            "SELECT id, title, status, note FROM uploads WHERE school_id = ? AND (teacher_id = ? OR ?) AND status IN ('check','ready')"
            " ORDER BY created_at DESC", (who.school["id"], who.staff["id"], int(who.admin)))]
        for u in uploads:
            attention.append({"kind": "upload_check" if u["status"] == "check" else "upload_ready",
                              "upload": {"id": u["id"], "title": u["title"], "note": u["note"]}})
        for l in learners:
            att = con.execute("SELECT SUM(mark != 'absent'), COUNT(*) FROM attendance WHERE learner_id = ?", (l["id"],)).fetchone()
            if att[1] >= 3 and 100 * (att[0] or 0) / att[1] < LOW_ATTENDANCE:
                attention.append({"kind": "low_attendance", "learner": {"id": l["id"], "name": l["name"],
                                  "class": by_class.get(l["class_id"])}, "attended": att[0] or 0, "sessions": att[1],
                                  "attendance": round(100 * (att[0] or 0) / att[1])})
        if who.admin and _admins(con, who.school["id"]) < 2:
            attention.append({"kind": "second_admin"})
        if who.admin:
            for d in con.execute("SELECT id, due FROM deletions WHERE school_id = ? AND status = 'pending'", (who.school["id"],)):
                attention.append({"kind": "deletion", "deletion": dict(d)})
        week = (now() - timedelta(days=now().weekday())).strftime("%G-W%V")
        lids = [l["id"] for l in learners]
        lmarks = ",".join("?" * len(lids))
        figures = None
        if lids:
            st = con.execute(f"SELECT SUM(pages), SUM(unaided), AVG(quiz_avg) FROM learner_stats WHERE week = ?"
                             f" AND learner_id IN ({lmarks})", [week, *lids]).fetchone()
            if st[0]:
                figures = {"pages": st[0], "unaided": round(100 * st[1] / st[0]),
                           "quiz_average": round(st[2]) if st[2] is not None else None}
        return {"me": me(who), "classes": [_class_out(con, c) for c in classes], "attention": attention,
                "week": figures}


# ---------- audit log (admins)

@router.get("/audit")
def audit_log(who: Who = Depends(admin), limit: int = 100) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT * FROM audit WHERE school_id = ? ORDER BY id DESC LIMIT ?",
                           (who.school["id"], min(limit, 500))).fetchall()
        names = {r["id"]: r["name"] for r in con.execute("SELECT id, name FROM staff WHERE school_id = ?", (who.school["id"],))}
        return [{**dict(r), "detail": json.loads(r["detail"]), "actor_name": names.get(r["actor"], r["actor"]),
                 "target_name": names.get(r["target"])} for r in rows]


# ---------- places (any form that asks for a location)

@router.get("/places")
def all_places() -> dict:
    return places.data()
