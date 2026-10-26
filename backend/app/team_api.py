"""The Magana team's own pages (/portal/team/..., and two /portal/admin/... views for Support):
team members (Owner only), a school's teachers and resending a school's email (any team role).
Never learners: team accounts can't open any learner, class, progress or consent endpoint
(portal_api.staff refuses them), and nothing here returns learner data."""
from __future__ import annotations

from datetime import timedelta
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from . import accounts as A
from . import mailer, places, team
from .accounts import db, iso, now, parse
from .portal_api import EmailIn, Who, _mail, fail, owner, portal_url, team_audit
from .portal_api import team as any_team

router = APIRouter(prefix="/portal")


def _member_out(m: dict) -> dict:
    expired = m["status"] == "invited" and parse(m["invite_expires"]) < now()
    return {"id": m["id"], "name": m["name"], "email": m["email"], "role": m["role"],
            "role_label": team.ROLE_LABEL[m["role"]], "can": team.ROLE_CAN[m["role"]],
            "status": "expired" if expired else m["status"],
            "last_sign_in": mailer.lagos_time(parse(m["last_sign_in"])) if m["last_sign_in"] else None,
            "invited_at": mailer.lagos_time(parse(m["invited_at"])) if m["invited_at"] else None}


@router.get("/team/members")
def members(who: Who = Depends(owner)) -> list[dict]:
    with db() as con:
        rows = con.execute("SELECT * FROM team_members WHERE status != 'removed' ORDER BY role = 'owner' DESC, created_at").fetchall()
        return [_member_out(dict(r)) for r in rows]


class MemberIn(EmailIn):
    name: str = Field(min_length=2, max_length=120)
    role: Literal["owner", "reviewer", "support"]


def _invite_mail(m: dict, who: Who) -> bool:
    return _mail(m["email"], mailer.team_invitation(m["name"], who.member["name"], team.ROLE_LABEL[m["role"]],
                                                    team.ROLE_CAN[m["role"]], m["email"], portal_url()))


@router.post("/team/members", status_code=201)
def add_member(body: MemberIn, who: Who = Depends(owner)) -> dict:
    with db() as con:
        if team.is_staff_email(con, body.email):
            fail(409, "email_is_teacher")  # one role per email
        if team.member_by_email(con, body.email):
            fail(409, "email_taken")
        mid = team.create(con, body.email, body.name, body.role, "invited", who.member["id"])
        team_audit(con, None, who, "team_member_invited", mid, role=body.role, email=body.email)
        m = team.member(con, mid)
    return {"code": "team_invite_sent", "id": mid, "emailed": _invite_mail(m, who)}


def _member_or_404(con, member_id: str) -> dict:
    m = team.member(con, member_id)
    if m is None or m["status"] == "removed":
        fail(404, "not_found")
    return m


def _keeps_an_owner(con, m: dict, new_role: str | None) -> None:
    """There's always at least one active owner."""
    if m["role"] == "owner" and m["status"] == "active" and new_role != "owner" and team.active_owners(con) <= 1:
        fail(409, "owners_minimum")


class RoleIn(BaseModel):
    role: Literal["owner", "reviewer", "support"]


@router.patch("/team/members/{member_id}")
def change_role(member_id: str, body: RoleIn, who: Who = Depends(owner)) -> dict:
    with db() as con:
        m = _member_or_404(con, member_id)
        _keeps_an_owner(con, m, body.role)
        con.execute("UPDATE team_members SET role = ? WHERE id = ?", (body.role, member_id))
        team_audit(con, None, who, "team_role_changed", member_id, email=m["email"], role=body.role, was=m["role"])
    return {"code": "team_role_changed"}


@router.post("/team/members/{member_id}/remove")
def remove_member(member_id: str, who: Who = Depends(owner)) -> dict:
    with db() as con:
        m = _member_or_404(con, member_id)
        _keeps_an_owner(con, m, None)
        con.execute("UPDATE team_members SET status = 'removed', removed_at = ? WHERE id = ?", (iso(now()), member_id))
        con.execute("DELETE FROM sessions WHERE who IN (?, ?)", (f"team:{member_id}", f"team2fa:{member_id}"))
        team_audit(con, None, who, "team_member_removed", member_id, email=m["email"])
    return {"code": "team_member_removed"}


@router.post("/team/members/{member_id}/resend")
def resend_member_invite(member_id: str, who: Who = Depends(owner)) -> dict:
    with db() as con:
        m = _member_or_404(con, member_id)
        if m["status"] != "invited":
            fail(409, "not_invited")
        t = now()
        con.execute("UPDATE team_members SET invited_at = ?, invite_expires = ? WHERE id = ?",
                    (iso(t), iso(t + timedelta(days=A.INVITE_DAYS)), member_id))
        team_audit(con, None, who, "team_invite_resent", member_id, email=m["email"])
        m = team.member(con, member_id)
    return {"code": "team_invite_sent", "emailed": _invite_mail(m, who)}


@router.post("/team/members/{member_id}/cancel")
def cancel_member_invite(member_id: str, who: Who = Depends(owner)) -> dict:
    with db() as con:
        m = _member_or_404(con, member_id)
        if m["status"] != "invited":
            fail(409, "not_invited")
        con.execute("UPDATE team_members SET status = 'removed', removed_at = ? WHERE id = ?", (iso(now()), member_id))
        team_audit(con, None, who, "team_invite_cancelled", member_id, email=m["email"])
    return {"code": "team_invite_cancelled"}


class ResetIn(BaseModel):
    code: str = Field("", max_length=12)
    backup_code: str = Field("", max_length=12)


@router.post("/team/me/authenticator/reset")
def reset_my_authenticator(body: ResetIn, who: Who = Depends(any_team)) -> dict:
    """Reset your own authenticator (a key seen by someone else, a new phone). Proves it's you with
    a current authenticator code or a backup code first. Signs you out everywhere."""
    from . import codes
    key = f"totp:{who.member['id']}"
    if (wait := codes.attempts.locked_for(key)) > 0:
        fail(429, "code_locked", retry_after=int(wait) + 1)
    with db() as con:
        m = team.member(con, who.member["id"])
        ok = team.use_backup_code(con, m, body.backup_code) if body.backup_code else team.check_totp(con, m, body.code)
        if ok:
            team.reset_authenticator(con, m["id"])
            team_audit(con, None, who, "team_authenticator_reset", m["id"], by="self",
                    proof="backup code" if body.backup_code else "authenticator code")
    if not ok:
        wait = codes.attempts.failed(key)
        fail(429 if wait else 400, "code_locked" if wait else "totp_wrong", **({"retry_after": int(wait)} if wait else {}))
    codes.attempts.succeeded(key)
    return {"code": "authenticator_reset"}


@router.post("/team/members/{member_id}/reset-authenticator")
def reset_member_authenticator(member_id: str, who: Who = Depends(owner)) -> dict:
    """An owner resets another member's authenticator: they're signed out and set it up again."""
    with db() as con:
        m = _member_or_404(con, member_id)
        if m["id"] == who.member["id"]:
            fail(409, "use_reset_my_authenticator")
        team.reset_authenticator(con, m["id"])
        team_audit(con, None, who, "team_authenticator_reset", m["id"], by="owner", email=m["email"])
    return {"code": "authenticator_reset"}


# ---------- what Support can do: see a school's teachers, resend its email

@router.get("/admin/schools/{school_id}/teachers")
def school_teachers(school_id: str, who: Who = Depends(any_team)) -> list[dict]:
    """A school's staff (name, email, role, status). No classes' learners, ever."""
    with db() as con:
        if not con.execute("SELECT 1 FROM schools WHERE id = ?", (school_id,)).fetchone():
            fail(404, "not_found")
        rows = con.execute("SELECT name, email, role, title, status FROM staff WHERE school_id = ? AND status != 'removed'"
                           " ORDER BY role, name", (school_id,)).fetchall()
        team_audit(con, school_id, who, "team_viewed_teachers", school_id)
    return [dict(r) for r in rows]


@router.post("/admin/schools/{school_id}/resend")
def resend_school_email(school_id: str, who: Who = Depends(any_team)) -> dict:
    """Send the principal the school's latest email again: received, approved or not confirmed."""
    with db() as con:
        s = A.row(con.execute("SELECT * FROM schools WHERE id = ?", (school_id,)).fetchone())
        if s is None:
            fail(404, "not_found")
        team_audit(con, school_id, who, "school_email_resent", school_id, status=s["status"])
    place = f"{places.lga_name(s['lga'])}, {places.state_name(s['state'])}"
    if s["status"] == "approved":
        email = mailer.school_approved(s["contact_name"], s["name"], portal_url())
    elif s["status"] == "rejected":
        email = mailer.school_not_approved(s["contact_name"], s["name"], s["contact_phone"] or "", place,
                                           s["reason"] or "unreachable", mailer.ref(s["ref"]))
    else:
        email = mailer.registration_received(s["contact_name"], s["name"], place, s["contact_role"] or "",
                                             s["contact_phone"] or "", mailer.ref(s["ref"]), parse(s["created_at"]))
    return {"code": "school_email_resent", "emailed": _mail(s["contact_email"], email)}
