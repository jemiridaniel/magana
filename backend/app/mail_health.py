"""Weekly check of the email sending reputation (docs/INFRA.md, "Email").

Once a week the server adds up its own counts for the last 7 days (mail_events.mail_counts: sent,
bounced, complained). If bounces pass 2% or complaints pass 0.05% of what was sent, it emails
MAIL_ALERT_EMAIL (daniel@magana.ng), logs a CRITICAL line and posts to MAGANA_ALERT_WEBHOOK_URL if
set. Resend may pause sending at about 4% bounces or 0.08% complaints, so these limits leave time
to act. Under 20 emails in the week is too few to judge. No address or email content is read.
"""
from __future__ import annotations

import asyncio
import logging
import os
from datetime import timedelta

from . import mailer
from .accounts import db, iso, now, parse

log = logging.getLogger("magana.mail")

BOUNCE_LIMIT = 0.02
COMPLAINT_LIMIT = 0.0005
MIN_SENT = 20
EVERY = timedelta(days=7)
JOB = "mail_reputation"
DEFAULT_ALERT_EMAIL = "daniel@magana.ng"


def rates() -> tuple[int, float | None, float | None]:
    """(sent, bounce rate, complaint rate) over the last 7 days; rates are None under MIN_SENT."""
    since = (now() - EVERY).date().isoformat()
    with db() as con:
        r = con.execute("SELECT COALESCE(SUM(sent), 0), COALESCE(SUM(bounced), 0), COALESCE(SUM(complained), 0)"
                        " FROM mail_counts WHERE day >= ?", (since,)).fetchone()
    sent, bounced, complained = int(r[0]), int(r[1]), int(r[2])
    if sent < MIN_SENT:
        return sent, None, None
    return sent, bounced / sent, complained / sent


def check() -> dict:
    """Reads both rates and alerts if either is over its limit. Returns what it found."""
    sent, bounce, complaint = rates()
    found = {"bounce": bounce, "complaint": complaint}
    over = [k for k, limit in (("bounce", BOUNCE_LIMIT), ("complaint", COMPLAINT_LIMIT))
            if found[k] is not None and found[k] > limit]
    if over:
        from .iba_monitor import _post_webhook

        text = (f"ALERT: email reputation over the limit: bounces {_pct(bounce)} (limit 2%), "
                f"complaints {_pct(complaint)} (limit 0.05%), {sent} sent in the last 7 days.")
        log.critical(text)
        _post_webhook(text)
        try:
            mailer.send(os.environ.get("MAIL_ALERT_EMAIL", DEFAULT_ALERT_EMAIL),
                        mailer.reputation_alert(bounce, complaint, sent))
        except mailer.MailError as e:
            log.error("email reputation alert not sent: %s", type(e).__name__)
    else:
        log.info("email reputation fine: %s sent, bounces %s, complaints %s", sent, _pct(bounce), _pct(complaint))
    return {"rates": found, "sent": sent, "over": over}


def _pct(rate: float | None) -> str:
    return "too few to judge" if rate is None else f"{rate * 100:.2f}%"


def due() -> bool:
    with db() as con:
        r = con.execute("SELECT at FROM job_runs WHERE name = ?", (JOB,)).fetchone()
    return r is None or now() - parse(r["at"]) >= EVERY


def run_if_due() -> dict | None:
    if not due():
        return None
    try:
        found = check()
    except Exception as e:  # the database unreachable: try again next time
        log.error("email reputation check failed: %s", type(e).__name__)
        return None
    with db() as con:
        con.execute("INSERT OR REPLACE INTO job_runs(name, at) VALUES (?,?)", (JOB, iso(now())))
    return found


def enabled() -> bool:
    return (os.environ.get("MAGANA_MAIL", "resend") == "resend" and os.environ.get("MAGANA_ENV", "production") == "production"
            and os.environ.get("MAIL_HEALTH_CHECK", "on") != "off")


async def loop(poll_s: float = 6 * 3600) -> None:
    """Looks every 6 hours whether a week has passed, so a restart never skips or repeats a week."""
    while True:
        await asyncio.to_thread(run_if_due)
        await asyncio.sleep(poll_s)
