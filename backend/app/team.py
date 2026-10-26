"""Magana team accounts (board "Magana team admin · Team members"): the people who run Magana,
separate from schools. One role each:
  owner     everything, including adding, changing and removing team members (keep to 2)
  reviewer  School reviewer: approve or reject schools, view proof documents, see the activity log
  support   view only: see schools and their teachers, resend emails; can't approve or change anything
There is always at least one active owner. The first one is made on the server with
`python -m app.team_setup` (never through the web). A team email can't also be a teacher or
school admin, and team accounts never see learners (portal_api.staff refuses them).
Sign-in: an email code, then an authenticator code (TOTP), set up on first sign-in with 8
backup codes shown once. Signed out after 15 minutes without activity."""
from __future__ import annotations

import hashlib
import hmac
import json
import secrets

from . import accounts as A
from . import codes, totp

ROLES = ("owner", "reviewer", "support")
ROLE_LABEL = {"owner": "Owner", "reviewer": "School reviewer", "support": "Support (view only)"}
ROLE_CAN = {"owner": "All, including team members",
            "reviewer": "Approve or reject schools, view proof documents, see the activity log",
            "support": "See schools and teachers, resend emails"}
IDLE_MINUTES = 15
BACKUP_CODES = 8

SCHEMA = """
CREATE TABLE IF NOT EXISTS team_members(
  id TEXT PRIMARY KEY, email TEXT NOT NULL, name TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('owner','reviewer','support')),
  status TEXT NOT NULL CHECK(status IN ('invited','active','removed')),
  invited_by TEXT, invited_at TEXT, invite_expires TEXT,
  totp_sealed TEXT, totp_confirmed_at TEXT, totp_last_counter INTEGER, backup_codes TEXT NOT NULL DEFAULT '[]',
  last_sign_in TEXT, created_at TEXT NOT NULL, removed_at TEXT);
CREATE UNIQUE INDEX IF NOT EXISTS team_email_live ON team_members(email) WHERE status != 'removed';
"""


def member_by_email(con, email: str) -> dict | None:
    return A.row(con.execute("SELECT * FROM team_members WHERE email = ? AND status != 'removed'",
                             (email.strip().lower(),)).fetchone())


def member(con, member_id: str) -> dict | None:
    return A.row(con.execute("SELECT * FROM team_members WHERE id = ?", (member_id,)).fetchone())


def can_sign_in(m: dict | None) -> bool:
    if m is None or m["status"] == "removed":
        return False
    return m["status"] == "active" or A.parse(m["invite_expires"]) > A.now()


def active_owners(con) -> int:
    return con.execute("SELECT COUNT(*) FROM team_members WHERE role = 'owner' AND status = 'active'").fetchone()[0]


def alert_emails(con) -> list[str]:
    """Who gets the new-school alert: every active Owner and School reviewer."""
    return [r[0] for r in con.execute("SELECT email FROM team_members WHERE status = 'active' AND role IN "
                                      "('owner','reviewer') ORDER BY email")]


def is_team_email(con, email: str) -> bool:
    return member_by_email(con, email) is not None


def is_staff_email(con, email: str) -> bool:
    return con.execute("SELECT 1 FROM staff WHERE email = ? AND status != 'removed'", (email.strip().lower(),)).fetchone() is not None


# ---------- the authenticator

def seal(secret: str) -> str:
    return codes.seal_with("totp", secret)


def unseal(sealed: str) -> str:
    return codes.unseal_with("totp", sealed)


def _backup_lookup(code: str) -> str:
    return hmac.new(codes._derived("backup"), "".join(ch for ch in code if ch.isdigit()).encode(), hashlib.sha256).hexdigest()


def new_backup_codes() -> tuple[list[str], str]:
    """8 one-time codes like "4821-9037" (shown once) and what's stored (their keyed hashes)."""
    shown = [f"{secrets.randbelow(10**4):04d}-{secrets.randbelow(10**4):04d}" for _ in range(BACKUP_CODES)]
    return shown, json.dumps([_backup_lookup(c) for c in shown])


def use_backup_code(con, m: dict, code: str) -> bool:
    stored = json.loads(m["backup_codes"] or "[]")
    lk = _backup_lookup(code)
    if lk not in stored:
        return False
    stored.remove(lk)
    con.execute("UPDATE team_members SET backup_codes = ? WHERE id = ?", (json.dumps(stored), m["id"]))
    return True


def check_totp(con, m: dict, code: str) -> bool:
    if not m["totp_sealed"]:
        return False
    c = totp.check(unseal(m["totp_sealed"]), code, m["totp_last_counter"])
    if c is None:
        return False
    con.execute("UPDATE team_members SET totp_last_counter = ? WHERE id = ?", (c, m["id"]))
    return True


def create(con, email: str, name: str, role: str, status: str, invited_by: str | None) -> str:
    t = A.now()
    mid = A.new_id("tm")
    con.execute("INSERT INTO team_members(id, email, name, role, status, invited_by, invited_at, invite_expires, created_at)"
                " VALUES (?,?,?,?,?,?,?,?,?)",
                (mid, email.strip().lower(), name.strip(), role, status, invited_by, A.iso(t),
                 A.iso(t + A.timedelta(days=A.INVITE_DAYS)), A.iso(t)))
    return mid


def reset_authenticator(con, member_id: str) -> None:
    """Forget the authenticator key and backup codes and end every session: the old key stops
    working at once, and the next sign-in sets up a new one (a leaked key, a lost phone)."""
    con.execute("UPDATE team_members SET totp_sealed = NULL, totp_confirmed_at = NULL, totp_last_counter = NULL,"
                " backup_codes = '[]' WHERE id = ?", (member_id,))
    con.execute("DELETE FROM sessions WHERE who IN (?, ?)", (f"team:{member_id}", f"team2fa:{member_id}"))
