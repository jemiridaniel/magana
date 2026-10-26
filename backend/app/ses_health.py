"""Weekly check of the SES sending reputation (docs/DEPLOY_AWS.md, "Bounces and complaints").

Once a week the server reads CloudWatch's account-wide SES metrics Reputation.BounceRate and
Reputation.ComplaintRate (the highest value in the last 7 days) through the instance role. If
bounces pass 2% or complaints pass 0.05%, it emails SES_ALERT_EMAIL (daniel@magana.ng), logs a
CRITICAL line and posts to MAGANA_ALERT_WEBHOOK_URL if set. AWS reviews an account at 5% bounces
or 0.1% complaints, so these limits leave time to act. No address or email content is read.
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
EVERY = timedelta(days=7)
JOB = "ses_reputation"
DEFAULT_ALERT_EMAIL = "daniel@magana.ng"
METRICS = {"bounce": "Reputation.BounceRate", "complaint": "Reputation.ComplaintRate"}


def _cloudwatch_max(metric: str) -> float | None:
    import boto3

    cw = boto3.client("cloudwatch", region_name=os.environ.get("SES_REGION", "eu-west-2"))
    t = now()
    points = cw.get_metric_statistics(Namespace="AWS/SES", MetricName=metric, StartTime=t - EVERY, EndTime=t,
                                      Period=3600, Statistics=["Maximum"])["Datapoints"]
    return max((p["Maximum"] for p in points), default=None)


read_metric = _cloudwatch_max  # tests replace it


def check() -> dict:
    """Reads both rates and alerts if either is over its limit. Returns what it found."""
    rates = {k: read_metric(m) for k, m in METRICS.items()}
    over = [k for k, limit in (("bounce", BOUNCE_LIMIT), ("complaint", COMPLAINT_LIMIT))
            if rates[k] is not None and rates[k] > limit]
    if over:
        from .iba_monitor import _post_webhook

        text = (f"ALERT: SES reputation over the limit: bounces {_pct(rates['bounce'])} (limit 2%), "
                f"complaints {_pct(rates['complaint'])} (limit 0.05%), highest in the last 7 days.")
        log.critical(text)
        _post_webhook(text)
        try:
            mailer.send(os.environ.get("SES_ALERT_EMAIL", DEFAULT_ALERT_EMAIL),
                        mailer.ses_reputation_alert(rates["bounce"], rates["complaint"]))
        except mailer.MailError as e:
            log.error("SES reputation alert email not sent: %s", type(e).__name__)
    else:
        log.info("SES reputation fine: bounces %s, complaints %s", _pct(rates["bounce"]), _pct(rates["complaint"]))
    return {"rates": rates, "over": over}


def _pct(rate: float | None) -> str:
    return "no data" if rate is None else f"{rate * 100:.2f}%"


def due() -> bool:
    with db() as con:
        r = con.execute("SELECT at FROM job_runs WHERE name = ?", (JOB,)).fetchone()
    return r is None or now() - parse(r["at"]) >= EVERY


def run_if_due() -> dict | None:
    if not due():
        return None
    try:
        found = check()
    except Exception as e:  # CloudWatch unreachable or no permission: try again next time
        log.error("SES reputation check failed: %s", type(e).__name__)
        return None
    with db() as con:
        con.execute("INSERT OR REPLACE INTO job_runs(name, at) VALUES (?,?)", (JOB, iso(now())))
    return found


def enabled() -> bool:
    return (os.environ.get("MAGANA_MAIL", "ses") == "ses" and os.environ.get("MAGANA_ENV", "production") == "production"
            and os.environ.get("SES_HEALTH_CHECK", "on") != "off")


async def loop(poll_s: float = 6 * 3600) -> None:
    """Looks every 6 hours whether a week has passed, so a restart never skips or repeats a week."""
    while True:
        await asyncio.to_thread(run_if_due)
        await asyncio.sleep(poll_s)
