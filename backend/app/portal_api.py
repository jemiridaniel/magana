"""The teacher portal's API (/portal/...): sign-in, schools, staff, classes, learners.

Sign-in: email, then a 6-digit code (10 minutes) by email. Only invited emails (or the Magana
team's accounts, team.py) get one; team members then give an authenticator code too. The session is an HttpOnly, Secure, SameSite=Lax cookie on
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
from . import codes, curriculum, mailer, places, proofs, ses_events, totp
from . import team as tm  # the Magana team's accounts (team.py); `team` below is the dependency
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


def _token_lookup(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# ---------- who is asking

@dataclass
class Who:
    kind: str                # "staff" | "team"
    staff: dict | None
    school: dict | None
    email: str
    member: dict | None = None  # a Magana team member (team.py)
    origin: dict | None = None  # the session's browser and rough place, for the activity log

    @property
    def role(self) -> str | None:
        return self.member["role"] if self.member else None

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
        if s["who"].startswith("team2fa:"):
            fail(401, "totp_required")  # the email code is done, the authenticator step isn't
        idle = tm.IDLE_MINUTES if s["who"].startswith("team:") else A.IDLE_MINUTES
        if (t - parse(s["last_seen"]) > timedelta(minutes=idle)
                or t - parse(s["created_at"]) > timedelta(hours=A.SESSION_MAX_HOURS)):
            con.execute("DELETE FROM sessions WHERE token_lookup = ?", (s["token_lookup"],))
            fail(401, "session_expired")
        con.execute("UPDATE sessions SET last_seen = ? WHERE token_lookup = ?", (iso(t), s["token_lookup"]))
        if s["who"].startswith("team:"):
            m = tm.member(con, s["who"][5:])
            if m is None or m["status"] != "active":
                con.execute("DELETE FROM sessions WHERE token_lookup = ?", (s["token_lookup"],))
                fail(401, "not_signed_in")
            origin = {k: s[k] for k in ("browser", "place") if s[k]}
            return Who("team", None, None, m["email"], m, origin or None)
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
    """Any Magana team member: Magana admin, School reviewer or Support (view only)."""
    if who.kind != "team":
        fail(403, "not_team")
    return who


def reviewer(who: Who = Depends(team)) -> Who:
    """Magana admins and School reviewers: approve or reject schools, proof documents, the activity log."""
    if who.role not in ("owner", "reviewer"):
        fail(403, "team_role_needed")
    return who


def team_audit(con, school_id: str | None, who: Who, action: str, target: str | None = None, **detail) -> None:
    """A Magana team action in the activity log, with where the session signed in from."""
    if who.origin:
        detail["from"] = who.origin
    A.audit(con, school_id, who.id, action, target, **detail)


def owner(who: Who = Depends(team)) -> Who:
    if who.role != "owner":
        fail(403, "team_role_needed")
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
    m = tm.member_by_email(con, email)
    if m is not None:
        return tm.can_sign_in(m)
    s = con.execute("SELECT * FROM staff WHERE email = ? AND status != 'removed'", (email,)).fetchone()
    if s is None:
        return False
    if s["status"] == "invited" and parse(s["invite_expires"]) < now():
        return False
    school = con.execute("SELECT status FROM schools WHERE id = ?", (s["school_id"],)).fetchone()
    return school is not None and school["status"] != "rejected"


def _name_for(email: str) -> str | None:
    with db() as con:
        m = tm.member_by_email(con, email)
        if m:
            return m["name"]
        r = con.execute("SELECT name FROM staff WHERE email = ? AND status != 'removed'", (email,)).fetchone()
    return r["name"] if r else None


@router.post("/auth/request-code")
def request_code(body: EmailIn, request: Request) -> dict:
    """Always answers the same way, so it never tells whether an email has an account."""
    if not ip_rate.allow(f"ip:{_client_ip(request)}", _limit("MAGANA_DEV_SIGNIN_LIMIT", IP_REQUESTS_PER_HOUR)):
        fail(429, "too_many_requests", retry_after=600)
    t = now()
    with db() as con:
        old = A.row(con.execute("SELECT * FROM login_codes WHERE email = ?", (body.email,)).fetchone())
        gap = _limit("MAGANA_DEV_CODE_GAP", CODE_GAP_S)
        # The 45 s gap is between unused codes: signing out and in again doesn't wait.
        if old and old["code_lookup"] != "used" and (t - parse(old["sent_at"])).total_seconds() < gap:
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
            mailer.send(body.email, mailer.sign_in_code(
                code, _name_for(body.email), t, request.headers.get("user-agent", ""),
                request.headers.get("x-magana-timezone", "")))
        except mailer.Undeliverable:
            pass  # answered like any other request: the answer never tells what is on the list
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
        good = (lc is not None and parse(lc["expires"]) > t and lc["code_lookup"] not in ("none", "used")
                and secrets.compare_digest(lc["code_lookup"], codes.lookup(body.code)))
        if not good:
            if lc and parse(lc["expires"]) <= t:
                fail(400, "sign_in_code_expired")
            wait = codes.attempts.failed(key)
            fail(429 if wait else 400, "code_locked" if wait else "sign_in_code_wrong",
                 **({"retry_after": int(wait)} if wait else {}))
        # Used up, but the row stays: the hourly count (CODES_PER_HOUR) still holds after a sign-in.
        con.execute("UPDATE login_codes SET code_lookup = 'used' WHERE email = ?", (body.email,))
        token = secrets.token_urlsafe(32)
        m = tm.member_by_email(con, body.email)
        if m is not None:
            # For the Magana team the email code is only the first step: the authenticator is next.
            who, out = f"team2fa:{m['id']}", {"code": "totp_required"}
            if not m["totp_confirmed_at"]:
                secret = totp.new_secret()
                con.execute("UPDATE team_members SET totp_sealed = ? WHERE id = ?", (tm.seal(secret), m["id"]))
                link = totp.uri(secret, m["email"])
                out = {"code": "totp_setup", "key": totp.grouped(secret), "uri": link, "account": m["email"],
                       "qr": totp.qr_data_uri(link)}
        else:
            s = con.execute("SELECT * FROM staff WHERE email = ? AND status != 'removed'", (body.email,)).fetchone()
            if s is None:
                fail(400, "sign_in_code_wrong")
            if s["status"] == "invited":
                con.execute("UPDATE staff SET status = 'active' WHERE id = ?", (s["id"],))
                A.audit(con, s["school_id"], s["id"], "invite_accepted", s["id"])
            who, out = s["id"], None
        con.execute("INSERT INTO sessions(token_lookup, who, created_at, last_seen) VALUES (?,?,?,?)",
                    (_token_lookup(token), who, iso(t), iso(t)))
    codes.attempts.succeeded(key)
    secure = os.environ.get("MAGANA_ENV", "production") != "development"
    response.set_cookie(COOKIE, token, httponly=True, secure=secure, samesite="lax", path="/")
    response.headers["Cache-Control"] = "no-store"  # the setup key and QR never sit in a cache
    return out or {"code": "signed_in", "me": me(_who_from(token))}


def _who_from(token: str) -> Who:
    class R:  # the request's cookies, for the response to the sign-in itself
        cookies = {COOKIE: token}
    return _who(R())  # type: ignore[arg-type]


TOTP_STEP_MINUTES = 10


class TotpIn(BaseModel):
    code: str = Field("", max_length=12)
    backup_code: str = Field("", max_length=12)


@router.post("/auth/totp")
def verify_totp(body: TotpIn, request: Request, response: Response) -> dict:
    """The authenticator step for the Magana team. First time: the code confirms the new key and
    the 8 backup codes are returned, once. After that: an authenticator code or a backup code.
    3 wrong tries lock it for 5 minutes."""
    token = request.cookies.get(COOKIE, "")
    t = now()
    with db() as con:
        s = con.execute("SELECT * FROM sessions WHERE token_lookup = ?", (_token_lookup(token or "-"),)).fetchone()
        if s is None or not s["who"].startswith("team2fa:"):
            fail(401, "not_signed_in")
        if t - parse(s["created_at"]) > timedelta(minutes=TOTP_STEP_MINUTES):
            con.execute("DELETE FROM sessions WHERE token_lookup = ?", (s["token_lookup"],))
            fail(401, "session_expired")
        m = tm.member(con, s["who"][8:])
        if m is None or not tm.can_sign_in(m):
            fail(401, "not_signed_in")
    key = f"totp:{m['id']}"
    if (wait := codes.attempts.locked_for(key)) > 0:
        fail(429, "code_locked", retry_after=int(wait) + 1)
    backup = None
    with db() as con:
        m = tm.member(con, m["id"])
        first = not m["totp_confirmed_at"]
        ok = (tm.use_backup_code(con, m, body.backup_code) if body.backup_code and not first
              else tm.check_totp(con, m, body.code))
        if ok:
            if first:
                backup, stored = tm.new_backup_codes()
                con.execute("UPDATE team_members SET totp_confirmed_at = ?, backup_codes = ? WHERE id = ?",
                            (iso(t), stored, m["id"]))
            con.execute("UPDATE team_members SET status = 'active', last_sign_in = ? WHERE id = ?", (iso(t), m["id"]))
            origin = {"browser": mailer.device(request.headers.get("user-agent", "")),
                      "place": mailer.rough_place(request.headers.get("x-magana-timezone", ""))}
            con.execute("UPDATE sessions SET who = ?, created_at = ?, last_seen = ?, browser = ?, place = ? WHERE token_lookup = ?",
                        (f"team:{m['id']}", iso(t), iso(t), origin["browser"], origin["place"], s["token_lookup"]))
            A.audit(con, None, f"team:{m['email']}",
                    "team_authenticator_set_up" if first else ("team_backup_code_used" if body.backup_code else "team_signed_in"),
                    m["id"], **{"from": {k: v for k, v in origin.items() if v}})
            if m["status"] == "invited":
                A.audit(con, None, f"team:{m['email']}", "team_invite_accepted", m["id"])
    if not ok:
        wait = codes.attempts.failed(key)
        fail(429 if wait else 400, "code_locked" if wait else "totp_wrong", **({"retry_after": int(wait)} if wait else {}))
    codes.attempts.succeeded(key)
    response.headers["Cache-Control"] = "no-store"  # backup codes are shown once, never cached
    return {"code": "signed_in", "me": me(_who_from(token)), **({"backup_codes": backup} if backup else {})}


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
        return {"kind": "team", "email": who.email, "name": who.member["name"], "role": who.role,
                "role_label": tm.ROLE_LABEL[who.role]}
    school = who.school
    return {"kind": "staff", "id": who.staff["id"], "name": who.staff["name"], "email": who.email,
            "role": who.staff["role"], "title": who.staff["title"],
            "school": {"id": school["id"], "name": school["name"], "status": school["status"],
                       "state": school["state"], "lga": school["lga"], **_pending_details(school)}}


def _pending_details(school: dict) -> dict:
    """What the "School waiting for confirmation" page shows."""
    if school["status"] == "approved":
        return {}
    registered = parse(school["created_at"])
    return {"reference": mailer.ref(school["ref"]) if school.get("ref") else None,
            "registered": mailer.lagos_time(registered), "call_by": mailer.day(mailer.call_by(registered)),
            "phone_masked": mailer.masked_phone(school["contact_phone"] or ""),
            "reason": school.get("reason")}


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
    ministry_no: str = Field("", max_length=60)
    proof: str | None = Field(None, max_length=8_000_000)  # a data URL or base64: a photo or PDF, 5 MB at most

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
    proof = None
    if body.proof:
        try:
            proof = proofs.decode(body.proof)
            proofs.kind_of(proof)
        except proofs.ProofError as e:
            fail(400, e.code)
    t = now()
    _purge_not_confirmed()
    with db() as con:
        if con.execute("SELECT 1 FROM staff WHERE email = ? AND status != 'removed'", (body.email,)).fetchone():
            fail(409, "email_taken")
        if tm.is_team_email(con, body.email):
            fail(409, "email_is_team")  # one role per email
        sid, aid = A.new_id("sch"), A.new_id("stf")
        n = con.execute("SELECT COALESCE(MAX(ref), 1046) + 1 FROM schools").fetchone()[0]
        con.execute("INSERT INTO schools(id, name, state, lga, status, contact_name, contact_role, contact_email,"
                    " contact_phone, created_at, ref, ministry_no) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                    (sid, body.school.strip(), body.state, body.lga, "pending", body.name.strip(), body.role,
                     body.email, body.phone, iso(t), n, body.ministry_no.strip()))
        if proof:
            con.execute("UPDATE schools SET proof_type = ? WHERE id = ?", (proofs.save(sid, proof), sid))
        _, lk, sealed = A.fresh_code(con, "staff")
        con.execute("INSERT INTO staff(id, school_id, name, email, role, title, status, created_at, code_lookup, code_sealed)"
                    " VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (aid, sid, body.name.strip(), body.email, "admin", body.role, "active", iso(t), lk, sealed))
    place = f"{places.lga_name(body.lga)}, {places.state_name(body.state)}"
    first = mailer.registration_received(body.name.strip(), body.school.strip(), place, body.role, body.phone, mailer.ref(n), t)
    emails = [{"subject": first.subject, "to": "principal", "sent": _mail(body.email, first)}]
    with db() as con:
        alerts = tm.alert_emails(con)
    for team_email in alerts:
        alert = mailer.new_school_request(body.school.strip(), place, body.name.strip(), body.role, body.email, body.phone,
                                          mailer.ref(n), t, portal_url(), bool(proof), body.ministry_no.strip())
        emails.append({"subject": alert.subject, "to": "Magana team", "sent": _mail(team_email, alert)})
    with db() as con:
        A.audit(con, sid, aid, "school_registered", sid, proof=bool(proof), emails=emails)
    return {"code": "school_registered", "school_id": sid, "reference": mailer.ref(n)}


def _mail(to: str, email: "mailer.Email") -> bool:
    """Send, and carry on if email is down: the registration or decision still stands."""
    try:
        mailer.send(to, email)
        return True
    except mailer.MailError:
        return False


NOT_CONFIRMED_DAYS = 30


APPLICANT, APPLICANT_ROLE = "School applicant", "Details removed 30 days after the decision"


def _purge_not_confirmed() -> None:
    """Schools not confirmed 30 days ago are deleted, as their email says."""
    cutoff = iso(now() - timedelta(days=NOT_CONFIRMED_DAYS))
    with db() as con:
        for (sid,) in con.execute("SELECT id FROM schools WHERE status = 'rejected' AND decided_at < ?", (cutoff,)).fetchall():
            ids = [r[0] for r in con.execute("SELECT id FROM staff WHERE school_id = ?", (sid,))]
            if con.execute("SELECT 1 FROM classes WHERE school_id = ?", (sid,)).fetchone():
                continue  # never for a school that has classes (it can't: a rejected school can't create any)
            for i in ids:
                con.execute("DELETE FROM sessions WHERE who = ?", (i,))
            con.execute("DELETE FROM staff WHERE school_id = ?", (sid,))
            if ids:  # their details go too, as the email said; the entries stay
                con.execute("UPDATE audit SET actor = NULL, actor_name = ?, actor_email = '', actor_role = ? WHERE actor IN (%s)"
                            % ",".join("?" * len(ids)), [APPLICANT, APPLICANT_ROLE, *ids])
            con.execute("DELETE FROM schools WHERE id = ?", (sid,))
            proofs.delete(sid)
            A.audit(con, None, "system", "school_details_deleted", None, after_days=NOT_CONFIRMED_DAYS)


CHECKS = ("person_confirmed", "school_exists", "details_correct")


def _school_out(r, bad: set[str] = frozenset()) -> dict:
    d = dict(r)
    registered = parse(d["created_at"])
    by = mailer.call_by(registered)
    return {"id": d["id"], "name": d["name"], "status": d["status"], "reference": mailer.ref(d["ref"]),
            "state_name": places.state_name(d["state"]), "lga_name": places.lga_name(d["lga"]),
            "contact_name": d["contact_name"], "contact_role": d["contact_role"], "contact_email": d["contact_email"],
            "contact_phone": mailer.local_phone(d["contact_phone"] or ""), "phone_tel": d["contact_phone"],
            "registered": mailer.lagos_time(registered), "call_by": mailer.day(by),
            "days_left": max(0, (by.date() - now().astimezone(mailer.LAGOS).date()).days),
            "ministry_no": d.get("ministry_no") or "", "proof": d.get("proof_type"),
            "call_notes": d.get("call_notes") or "", "checks": [c for c in (d.get("checks") or "").split(",") if c],
            "reason": d.get("reason"), "reason_label": mailer.REASONS.get(d.get("reason") or "", None),
            "decided_at": mailer.lagos_time(parse(d["decided_at"])) if d.get("decided_at") else None,
            "decided_by": d.get("decided_by"),
            # Bounced or marked as spam (ses_events.py): "We couldn't deliver to this address".
            "contact_undeliverable": (d["contact_email"] or "").lower() in bad}


@router.get("/admin/schools")
def list_schools(status: str = "pending", who: Who = Depends(team)) -> list[dict]:
    _purge_not_confirmed()
    order = "created_at" if status == "pending" else "decided_at DESC"
    with db() as con:
        rows = con.execute(f"SELECT * FROM schools WHERE status = ? ORDER BY {order}", (status,)).fetchall()
        bad = ses_events.undeliverable_set(con, [r["contact_email"] for r in rows])
        return [_school_out(r, bad) for r in rows]


def _pending_school(con, school_id: str) -> dict:
    s = A.row(con.execute("SELECT * FROM schools WHERE id = ?", (school_id,)).fetchone())
    if s is None:
        fail(404, "not_found")
    if s["status"] != "pending":
        fail(409, "school_decided")
    return s


class NotesIn(BaseModel):
    call_notes: str = Field("", max_length=2000)
    checks: list[Literal["person_confirmed", "school_exists", "details_correct"]] = Field(default_factory=list)


@router.put("/admin/schools/{school_id}/notes")
def save_notes(school_id: str, body: NotesIn, who: Who = Depends(reviewer)) -> dict:
    with db() as con:
        s = _pending_school(con, school_id)
        con.execute("UPDATE schools SET call_notes = ?, checks = ? WHERE id = ?",
                    (body.call_notes.strip(), ",".join(sorted(set(body.checks))), school_id))
        team_audit(con, school_id, who, "school_call_noted", school_id,
                   changes=[{"field": "Call notes", "before": s["call_notes"] or "", "after": body.call_notes.strip()},
                            {"field": "Checks", "before": f"{len([c for c in (s['checks'] or '').split(',') if c])} of 3 ticked",
                             "after": f"{len(set(body.checks))} of 3 ticked"}])
    return {"code": "notes_saved"}


@router.get("/admin/reasons")
def reasons(school_id: str, who: Who = Depends(reviewer)) -> list[dict]:
    """Each reason with the email the applicant would get: the preview before sending."""
    with db() as con:
        s = A.row(con.execute("SELECT * FROM schools WHERE id = ?", (school_id,)).fetchone())
    if s is None:
        fail(404, "not_found")
    place = f"{places.lga_name(s['lga'])}, {places.state_name(s['state'])}"
    out = []
    for key, label in mailer.REASONS.items():
        what, can = mailer.reason_text(key, s["name"], s["contact_phone"] or "", place)
        out.append({"reason": key, "label": label, "preview": f"{what} {can[0]}"})
    return out


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]
    checks: list[Literal["person_confirmed", "school_exists", "details_correct"]] = Field(default_factory=list)
    call_notes: str = Field("", max_length=2000)
    reason: Literal["unreachable", "role_unconfirmed", "not_found", "duplicate"] | None = None


@router.post("/admin/schools/{school_id}")
def decide_school(school_id: str, body: DecisionIn, who: Who = Depends(reviewer)) -> dict:
    """Approve only with all three checks ticked; not approving needs a reason, which the
    applicant reads. Either way the proof file is deleted and the decision is in the log."""
    if body.decision == "approve" and set(body.checks) != set(CHECKS):
        fail(400, "checks_required")
    if body.decision == "reject" and not body.reason:
        fail(400, "reason_required")
    with db() as con:
        s = _pending_school(con, school_id)
        status = "approved" if body.decision == "approve" else "rejected"
        con.execute("UPDATE schools SET status = ?, decided_at = ?, decided_by = ?, call_notes = ?, checks = ?,"
                    " reason = ?, proof_type = NULL WHERE id = ?",
                    (status, iso(now()), who.email, body.call_notes.strip() or s["call_notes"] or "",
                     ",".join(sorted(set(body.checks))), body.reason if status == "rejected" else None, school_id))
    had_proof = proofs.delete(school_id)
    place = f"{places.lga_name(s['lga'])}, {places.state_name(s['state'])}"
    if status == "approved":
        email = mailer.school_approved(s["contact_name"], s["name"], portal_url())
    else:
        email = mailer.school_not_approved(s["contact_name"], s["name"], s["contact_phone"] or "", place, body.reason,
                                           mailer.ref(s["ref"]))
    sent = _mail(s["contact_email"], email)
    with db() as con:
        changes = [{"field": "Status", "before": "Waiting", "after": "Approved" if status == "approved" else "Not approved"},
                   {"field": "Checks", "before": "", "after": f"{len(set(body.checks))} of 3 ticked"}]
        if body.reason and status == "rejected":
            changes.append({"field": "Reason", "before": "", "after": mailer.REASONS[body.reason]})
        if had_proof:
            changes.append({"field": "Proof file", "before": "Stored", "after": "Deleted automatically"})
        team_audit(con, school_id, who, f"school_{status}", school_id, changes=changes,
                   call_notes=body.call_notes.strip() or s["call_notes"] or "",
                   emails=[{"subject": email.subject, "to": "principal", "sent": sent}],
                   **({"reason": body.reason} if body.reason and status == "rejected" else {}))
    return {"code": f"school_{status}", "emailed": sent}


@router.get("/admin/schools/{school_id}/proof")
def school_proof(school_id: str, who: Who = Depends(reviewer)) -> Response:
    """The proof file, for the team only; never cached."""
    with db() as con:
        s = A.row(con.execute("SELECT proof_type FROM schools WHERE id = ?", (school_id,)).fetchone())
    data = proofs.load(school_id) if s and s["proof_type"] else None
    if data is None:
        fail(404, "not_found")
    with db() as con:
        team_audit(con, school_id, who, "school_proof_viewed", school_id, file=s["proof_type"])
    return Response(data, media_type=s["proof_type"], headers={
        "Cache-Control": "no-store", "Content-Disposition": "inline", "X-Content-Type-Options": "nosniff"})


# What each action is called in the log (the Action tag), as the board names them.
ACTION_LABELS = {
    "school_registered": "School registered", "school_call_noted": "Call notes", "school_approved": "Approved school",
    "school_rejected": "Not approved", "school_proof_viewed": "Viewed proof", "school_details_deleted": "Details deleted",
    "school_email_resent": "Email resent", "team_viewed_teachers": "Viewed teachers", "team_signed_in": "Sign-in",
    "team_authenticator_set_up": "Authenticator set up", "team_backup_code_used": "Backup code used",
    "team_authenticator_reset": "Authenticator reset", "team_invite_accepted": "Joined the team",
    "team_member_invited": "Invited member", "team_role_changed": "Role changed", "team_member_removed": "Removed member",
    "team_invite_resent": "Invite resent", "team_invite_cancelled": "Invite cancelled", "team_owner_created": "First Magana admin made",
    "team_member_created": "Member made", "team_email_undeliverable": "Email undeliverable",
}
LOG_YEARS = 2


def _purge_old_log(con) -> None:
    """Activity entries are kept 2 years, then deleted."""
    con.execute("DELETE FROM audit WHERE at < ?", (iso(now() - timedelta(days=365 * LOG_YEARS)),))


def _log_rows(con, where: str = "", args: tuple = ()) -> list[dict]:
    return [dict(r) for r in con.execute(
        "SELECT a.*, s.name AS school_name, s.ref AS ref FROM audit a LEFT JOIN schools s ON s.id = a.school_id"
        " WHERE (a.action LIKE 'school_%' OR a.action LIKE 'team_%')" + where + " ORDER BY a.id DESC", args)]


def _people(con) -> dict[str, dict]:
    """Who an actor or target id is: name, email and role."""
    people = {f"team:{r['email']}": {"name": r["name"], "email": r["email"], "role": tm.ROLE_LABEL[r["role"]]}
              for r in con.execute("SELECT * FROM team_members")}
    people.update({r["id"]: {"name": r["name"], "email": r["email"], "role": tm.ROLE_LABEL[r["role"]]}
                   for r in con.execute("SELECT * FROM team_members")})
    people.update({r["id"]: {"name": r["name"], "email": r["email"], "role": "School admin" if r["role"] == "admin" else "Teacher"}
                   for r in con.execute("SELECT id, name, email, role FROM staff")})
    for key, name in (("server", "Magana server"), ("system", "Magana")):
        people[key] = {"name": name, "email": "", "role": ""}
    return people


def _actor_of(r: dict, removed: set[str]) -> dict:
    """Who did it, from the entry's own snapshot; "(removed)" if their team account is gone now."""
    name = r.get("actor_name") or "Unknown"
    return {"name": f"{name} (removed)" if r.get("actor") in removed else name,
            "email": r.get("actor_email") or "", "role": r.get("actor_role") or ""}


def _removed_team(con) -> set[str]:
    return {f"team:{e}" for (e,) in con.execute(
        "SELECT email FROM team_members GROUP BY email HAVING SUM(status != 'removed') = 0")}


def _about(r: dict, people: dict) -> str:
    d = json.loads(r["detail"] or "{}")
    ref = f" · {mailer.ref(r['ref'])}" if r.get("ref") else ""
    target = people.get(r["target"] or "", {})
    if r["action"].startswith("school_") or r["action"] == "team_viewed_teachers":
        if r["action"] == "school_proof_viewed":
            return f"{'PDF' if d.get('file') == 'application/pdf' else 'Photo'} of proof{ref}"
        return f"{r['school_name'] or 'A school'}{ref}"
    if r["action"] in ("team_signed_in", "team_backup_code_used"):
        return "Email code + " + ("backup code" if r["action"] == "team_backup_code_used" else "authenticator")
    if r["action"] == "team_member_invited":
        return f"Invited {d.get('email') or target.get('email', '')} as {tm.ROLE_LABEL.get(d.get('role', ''), '')}"
    if r["action"] == "team_role_changed":
        return f"{target.get('name') or d.get('email', '')} → {tm.ROLE_LABEL.get(d.get('role', ''), '')}"
    if r["action"] == "team_authenticator_reset":
        return f"{target.get('name', '')}’s authenticator ({d.get('by', '')})"
    if r["action"] == "team_email_undeliverable":
        return f"{d.get('email', '')} · {'Marked as spam' if d.get('reason') == 'complaint' else 'Hard bounce'}"
    return target.get("name") or d.get("email") or ""


def _entry(r: dict, people: dict, removed: set[str]) -> dict:
    at = parse(r["at"]).astimezone(mailer.LAGOS)
    who = _actor_of(r, removed)
    return {"id": r["id"], "date": f"{at.day} {at:%b %Y}", "time": f"{at:%H:%M}", "action": r["action"],
            "label": ACTION_LABELS.get(r["action"], r["action"]), "who": who["name"], "who_email": who["email"],
            "about": _about(r, people)}


@router.get("/admin/activity")
def activity(who: Who = Depends(reviewer), q: str = "", action: str = "", page: int = 1, size: int = 25) -> dict:
    """The activity log, newest first: search (name, email, school or reference), an action filter
    and pages. Read only: there is no way to edit or delete an entry."""
    size = size if size in (10, 25, 50, 100) else 25
    with db() as con:
        _purge_old_log(con)
        people, removed = _people(con), _removed_team(con)
        rows = _log_rows(con, " AND a.action = ?" if action else "", (action,) if action else ())
    entries = [_entry(r, people, removed) for r in rows]
    if q.strip():
        needle = q.strip().lower()
        entries = [e for e in entries if needle in " ".join([e["who"], e["who_email"], e["about"], e["label"]]).lower()]
    total = len(entries)
    pages = max(1, -(-total // size))
    page = min(max(1, page), pages)
    return {"items": entries[(page - 1) * size: page * size], "total": total, "page": page, "pages": pages, "size": size,
            "actions": [{"action": k, "label": v} for k, v in ACTION_LABELS.items()]}


@router.get("/admin/activity/{entry_id}")
def activity_entry(entry_id: int, who: Who = Depends(reviewer)) -> dict:
    """One entry's details: when, who and role, what it was about, where the session signed in
    from, what changed (before and after), call notes and emails sent."""
    with db() as con:
        rows = _log_rows(con, " AND a.id = ?", (entry_id,))
        people, removed = _people(con), _removed_team(con)
    if not rows:
        fail(404, "not_found")
    r = rows[0]
    d = json.loads(r["detail"] or "{}")
    at = parse(r["at"]).astimezone(mailer.LAGOS)
    actor = _actor_of(r, removed)
    changes = d.get("changes") or ([{"field": "Role", "before": tm.ROLE_LABEL.get(d["was"], d["was"]),
                                     "after": tm.ROLE_LABEL.get(d["role"], d["role"])}] if "was" in d else [])
    target = people.get(r["target"] or "")
    return {**_entry(r, people, removed), "when": f"{at:%a} {at.day} {at:%b %Y}, {at:%H:%M:%S}",
            "who_role": actor["role"], "school": r["school_name"], "reference": mailer.ref(r["ref"]) if r["ref"] else None,
            "target": ({"name": target["name"], "email": target["email"], "role": target["role"]} if target else None),
            "signed_in_from": d.get("from") or None, "changes": changes, "call_notes": d.get("call_notes") or None,
            "emails": d.get("emails") or [], "kept_for": f"{LOG_YEARS} years"}


# ---------- staff (school admins)

def _staff_out(con, s: dict) -> dict:
    classes = con.execute("SELECT id, name FROM classes WHERE teacher_id = ? ORDER BY name", (s["id"],)).fetchall()
    expired = s["status"] == "invited" and parse(s["invite_expires"]) < now()
    return {"id": s["id"], "name": s["name"], "email": s["email"], "role": s["role"], "title": s["title"],
            "status": "expired" if expired else s["status"], "invited_at": s["invited_at"],
            "removed_at": s["removed_at"], "classes": [dict(c) for c in classes],
            "undeliverable": bool(ses_events.undeliverable_set(con, [s["email"]]))}


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
        if tm.is_team_email(con, body.email):
            fail(409, "email_is_team")  # one role per email
        if ses_events.undeliverable_set(con, [body.email]):
            fail(409, "mail_undeliverable")
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
    _send_invite(sid, who)
    return {"code": "invite_sent", "id": sid}


def _send_invite(staff_id: str, who: Who) -> None:
    with db() as con:
        s = con.execute("SELECT * FROM staff WHERE id = ?", (staff_id,)).fetchone()
        classes = [r["name"] for r in con.execute("SELECT name FROM classes WHERE teacher_id = ? ORDER BY name", (staff_id,))]
    role = "School admin" if s["role"] == "admin" else "Teacher"
    try:
        mailer.send(s["email"], mailer.teacher_invitation(s["name"], who.school["name"], who.staff["name"],
                                                         role + (f" · {s['title']}" if s["title"] else ""), classes,
                                                         s["email"], portal_url()))
    except mailer.Undeliverable:
        fail(409, "mail_undeliverable")
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
        if ses_events.undeliverable_set(con, [s["email"]]):
            fail(409, "mail_undeliverable")
        con.execute("UPDATE staff SET invited_at = ?, invite_expires = ? WHERE id = ?",
                    (iso(t), iso(t + timedelta(days=A.INVITE_DAYS)), staff_id))
        A.audit(con, who.school["id"], who.id, "invite_resent", staff_id)
    _send_invite(staff_id, who)
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

def _unaided(unaided: int | None, answered: int | None) -> int | None:
    """"Done without sighted help": the share of answered "Did you need help?" questions
    answered "Yes, on my own" (board 8). None when nobody has answered: "No answers yet"."""
    return round(100 * (unaided or 0) / answered) if answered else None


def _learner_out(con, l: dict, detail: bool = False) -> dict:
    out = {"id": l["id"], "name": l["name"], "class_id": l["class_id"], "formats": [f for f in l["formats"].split(",") if f],
           "language": l["language"], "under_18": bool(l["under_18"]), "consent": l["consent"],
           "consent_at": l["consent_at"], "phone_linked": l["token_lookup"] is not None, "status": l["status"],
           "removed_at": l["removed_at"], "removed_reason": l["removed_reason"], "joined_at": l["created_at"],
           "reminder_at": l["reminder_at"]}
    if detail:
        att = con.execute("SELECT SUM(mark != 'absent'), COUNT(*) FROM attendance WHERE learner_id = ?", (l["id"],)).fetchone()
        st = con.execute("SELECT SUM(pages), SUM(unaided), AVG(quiz_avg), SUM(answered) FROM learner_stats"
                         " WHERE learner_id = ?", (l["id"],)).fetchone()
        out["term"] = {"sessions_attended": att[0] or 0, "sessions": att[1],
                       "attendance": round(100 * (att[0] or 0) / att[1]) if att[1] else None,
                       "pages": st[0], "unaided": _unaided(st[1], st[3]), "answered": st[3] or 0,
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
    con.execute("DELETE FROM learner_days WHERE learner_id = ?", (learner_id,))
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
            st = con.execute(f"SELECT SUM(pages), SUM(unaided), AVG(quiz_avg), SUM(answered) FROM learner_stats"
                             f" WHERE week = ? AND learner_id IN ({lmarks})", [week, *lids]).fetchone()
            if st[0] or st[3]:
                figures = {"pages": st[0] or 0, "unaided": _unaided(st[1], st[3]), "answered": st[3] or 0,
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
