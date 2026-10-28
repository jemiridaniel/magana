"""Bounces and complaints from Resend (docs/INFRA.md, "Email").

Resend posts each event about mail we sent to /internal/mail-events, signed the Svix way: the
headers svix-id, svix-timestamp and svix-signature, an HMAC-SHA256 of "id.timestamp.body" with
the webhook's signing secret (RESEND_WEBHOOK_SECRET, "whsec_…", a Space secret).

- Every event is checked before anything is done: the signature and its age (5 minutes either
  way). Anything else is refused (403).
- email.bounced (Resend: the recipient's server permanently rejected it) or email.complained
  (marked as spam) marks the address undeliverable: mailer.send never sends to it again, and the
  portal shows "We couldn't deliver to this address". email.delivery_delayed and the rest
  change nothing.
- Logged: the kind of event and a masked address. Never the email's subject (a sign-in code's
  subject holds the code), headers or body.
- mail_counts keeps how many emails were sent, bounced and complained each day, for the weekly
  check (mail_health.py). Only numbers.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import os
import time

from .accounts import audit, db, iso, now

log = logging.getLogger("magana.mail")

MAX_AGE_S = 5 * 60

SCHEMA = """
CREATE TABLE IF NOT EXISTS undeliverable(
  email TEXT PRIMARY KEY, reason TEXT NOT NULL CHECK(reason IN ('bounce','complaint')),
  detail TEXT NOT NULL DEFAULT '', at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS job_runs(name TEXT PRIMARY KEY, at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS mail_counts(
  day TEXT PRIMARY KEY, sent INTEGER NOT NULL DEFAULT 0, bounced INTEGER NOT NULL DEFAULT 0,
  complained INTEGER NOT NULL DEFAULT 0);
"""


class Refused(Exception):
    """Not a genuine event from our Resend webhook: answered 403 and otherwise ignored."""


def masked(email: str) -> str:
    """dan.example@gmail.com → "d***@gmail.com": enough to find it in the portal, no more."""
    user, _, domain = (email or "").partition("@")
    return f"{user[:1]}***@{domain}" if domain else "***"


# ---------- the list of addresses we never send to

def is_undeliverable(email: str) -> bool:
    with db() as con:
        return con.execute("SELECT 1 FROM undeliverable WHERE email = ?", (email.strip().lower(),)).fetchone() is not None


def undeliverable_set(con, emails) -> set[str]:
    """Which of these addresses can't be delivered to (for the portal's lists)."""
    emails = [e.strip().lower() for e in emails if e]
    if not emails:
        return set()
    marks = ",".join("?" * len(emails))
    return {r[0] for r in con.execute(f"SELECT email FROM undeliverable WHERE email IN ({marks})", emails).fetchall()}


def count(column: str) -> None:
    """One more email sent, bounced or complained about today."""
    assert column in ("sent", "bounced", "complained")
    day = now().date().isoformat()
    with db() as con:
        if con.execute("SELECT 1 FROM mail_counts WHERE day = ?", (day,)).fetchone() is None:
            con.execute("INSERT INTO mail_counts(day) VALUES (?)", (day,))
        con.execute(f"UPDATE mail_counts SET {column} = {column} + 1 WHERE day = ?", (day,))


def mark(email: str, reason: str, detail: str = "") -> None:
    email = email.strip().lower()
    with db() as con:
        con.execute("INSERT OR REPLACE INTO undeliverable(email, reason, detail, at) VALUES (?,?,?,?)",
                    (email, reason, detail[:80], iso(now())))
        # In the team's Activity log, with the address masked.
        audit(con, None, "system", "team_email_undeliverable", None, email=masked(email), reason=reason)
    log.warning("email undeliverable: %s, %s %s", masked(email), reason, detail)


def clear(email: str) -> bool:
    """For the team, by hand, once the person says their mailbox works again (also remove it from
    Resend's suppression list): python -m app.mail_events --clear someone@example.com"""
    with db() as con:
        return con.execute("DELETE FROM undeliverable WHERE email = ?", (email.strip().lower(),)).rowcount > 0


# ---------- checking an event really came from our webhook

def secret() -> bytes:
    raw = os.environ.get("RESEND_WEBHOOK_SECRET", "").strip()
    if not raw:
        raise Refused("no webhook secret set")
    return base64.b64decode(raw.removeprefix("whsec_"))


def verify(headers, body: bytes, at: float | None = None) -> None:
    msg_id, stamp, given = (headers.get("svix-id", ""), headers.get("svix-timestamp", ""),
                            headers.get("svix-signature", ""))
    if not (msg_id and stamp and given):
        raise Refused("unsigned")
    try:
        sent = int(stamp)
    except ValueError:
        raise Refused("no timestamp") from None
    if abs((time.time() if at is None else at) - sent) > MAX_AGE_S:
        raise Refused("too old")
    expected = base64.b64encode(hmac.new(secret(), f"{msg_id}.{stamp}.".encode() + body, hashlib.sha256).digest())
    # "v1,<sig> v1,<sig>": any one of them (a rotated secret signs twice).
    for part in given.split():
        version, _, sig = part.partition(",")
        if version == "v1" and hmac.compare_digest(sig.encode(), expected):
            return
    raise Refused("bad signature")


# ---------- handling it

def handle(headers, body: bytes) -> str:
    """Checks one event and acts on it. Returns what was done (for tests and the log)."""
    verify(headers, body)
    try:
        event = json.loads(body)
    except ValueError:
        return "ignored"
    if not isinstance(event, dict):
        return "ignored"
    kind = event.get("type")
    data = event.get("data") if isinstance(event.get("data"), dict) else {}
    to = data.get("to") or []
    people = [to] if isinstance(to, str) else [p for p in to if isinstance(p, str)]
    if kind == "email.bounced":
        b = data.get("bounce") or {}
        for p in people:
            mark(p, "bounce", f"{b.get('type', 'Permanent')}/{b.get('subType', '')}")
        count("bounced")
        return "bounce"
    if kind == "email.complained":
        for p in people:
            mark(p, "complaint", "spam")
        count("complained")
        return "complaint"
    if kind in ("email.delivered", "email.delivery_delayed", "email.sent"):
        log.info("mail events: %s", kind.removeprefix("email."))
        return kind.removeprefix("email.")
    return "ignored"


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="Stop or restart sending to an address (also update Resend's suppression list).")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--clear", metavar="EMAIL", help="send to it again (the person says their mailbox works)")
    g.add_argument("--mark", metavar="EMAIL", help="stop sending to it (the person says it's wrong or not theirs)")
    a = ap.parse_args()
    if a.mark:
        mark(a.mark, "bounce", "marked by hand")
        print("marked: nothing more is sent to it")
    else:
        print("cleared" if clear(a.clear) else "that address wasn't on the list")
