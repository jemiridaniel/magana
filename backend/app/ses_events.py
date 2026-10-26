"""Bounces and complaints from AWS SES (docs/DEPLOY_AWS.md, "Bounces and complaints").

SES publishes every Bounce, Complaint and Delivery of mail sent through the configuration set
"magana-default" to the SNS topic "magana-ses-events", which POSTs it to /internal/ses-events.

- Every message is checked before anything is done: the SNS signature (with Amazon's own
  certificate, fetched only from sns.<region>.amazonaws.com), the topic (ours, in our account)
  and its age. Anything else is refused.
- SubscriptionConfirmation: confirmed by visiting its SubscribeURL (an SNS address only).
- A hard bounce (Permanent) or a complaint marks the address undeliverable: mailer.send never
  sends to it again, and the portal shows "We couldn't deliver to this address".
- Logged: the kind of event and a masked address. Never the email's subject (a sign-in code's
  subject holds the code), headers or body: the "mail" part of the event is never read.
"""
from __future__ import annotations

import base64
import json
import logging
import os
import re
import threading
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

import httpx
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding

from .accounts import audit, db, iso, now

log = logging.getLogger("magana.mail")

TOPIC_NAME = "magana-ses-events"
CONFIGURATION_SET = "magana-default"
MAX_AGE = timedelta(hours=1)  # SNS delivers within seconds; an old message is a replay
SNS_HOST = re.compile(r"^sns\.[a-z0-9-]+\.amazonaws\.com$")

SCHEMA = """
CREATE TABLE IF NOT EXISTS undeliverable(
  email TEXT PRIMARY KEY, reason TEXT NOT NULL CHECK(reason IN ('bounce','complaint')),
  detail TEXT NOT NULL DEFAULT '', at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS job_runs(name TEXT PRIMARY KEY, at TEXT NOT NULL);
"""

# The fields SNS signs, in order (docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html).
SIGNED = {
    "Notification": ("Message", "MessageId", "Subject", "Timestamp", "TopicArn", "Type"),
    "SubscriptionConfirmation": ("Message", "MessageId", "SubscribeURL", "Timestamp", "Token", "TopicArn", "Type"),
    "UnsubscribeConfirmation": ("Message", "MessageId", "SubscribeURL", "Timestamp", "Token", "TopicArn", "Type"),
}


class Refused(Exception):
    """Not a genuine message from our topic: answered 403 and otherwise ignored."""


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
    return {r[0] for r in con.execute(f"SELECT email FROM undeliverable WHERE email IN ({marks})", emails)}


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
    the SES account suppression list): python -m app.ses_events --clear someone@example.com"""
    with db() as con:
        return con.execute("DELETE FROM undeliverable WHERE email = ?", (email.strip().lower(),)).rowcount > 0


# ---------- checking a message really came from our SNS topic

_certs: dict[str, x509.Certificate] = {}
_certs_lock = threading.Lock()


def _fetch_cert(url: str) -> bytes:
    r = httpx.get(url, timeout=5)
    r.raise_for_status()
    return r.content


fetch_cert = _fetch_cert  # tests replace it


def _sns_url(url: str) -> bool:
    u = urlparse(url or "")
    return u.scheme == "https" and bool(SNS_HOST.match(u.hostname or "")) and u.port in (None, 443)


def _cert(url: str) -> x509.Certificate:
    u = urlparse(url or "")
    if not _sns_url(url) or not u.path.endswith(".pem"):
        raise Refused("certificate not from SNS")
    with _certs_lock:
        if url in _certs:
            return _certs[url]
    cert = x509.load_pem_x509_certificate(fetch_cert(url))
    with _certs_lock:
        _certs[url] = cert
    return cert


def _account_id() -> str:
    import boto3

    return boto3.client("sts", region_name=region()).get_caller_identity()["Account"]


account_id = _account_id  # tests replace it
_expected: list[str] = []


def region() -> str:
    return os.environ.get("SES_REGION", "eu-west-2")


def expected_topic() -> str:
    """SES_EVENTS_TOPIC_ARN, or our topic in this server's own AWS account (asked once, through the
    instance role: sts:GetCallerIdentity needs no permission)."""
    if arn := os.environ.get("SES_EVENTS_TOPIC_ARN", "").strip():
        return arn
    if not _expected:
        _expected.append(f"arn:aws:sns:{region()}:{account_id()}:{TOPIC_NAME}")
    return _expected[0]


def verify(msg: dict) -> None:
    kind = msg.get("Type")
    if kind not in SIGNED:
        raise Refused("unknown type")
    if msg.get("TopicArn") != expected_topic():
        raise Refused("not our topic")
    try:
        sent = datetime.fromisoformat(str(msg.get("Timestamp", "")).replace("Z", "+00:00"))
    except ValueError:
        raise Refused("no timestamp") from None
    if abs(datetime.now(timezone.utc) - sent) > MAX_AGE:
        raise Refused("too old")
    text = "".join(f"{k}\n{msg[k]}\n" for k in SIGNED[kind] if k in msg)
    algo = {"1": hashes.SHA1(), "2": hashes.SHA256()}.get(str(msg.get("SignatureVersion")))
    if algo is None:
        raise Refused("unknown signature version")
    try:
        _cert(msg.get("SigningCertURL", "")).public_key().verify(
            base64.b64decode(msg.get("Signature", "")), text.encode(), padding.PKCS1v15(), algo)
    except (InvalidSignature, ValueError, TypeError) as e:
        raise Refused("bad signature") from e


# ---------- handling it

def _confirm(url: str) -> None:
    httpx.get(url, timeout=5).raise_for_status()


confirm = _confirm  # tests replace it


def handle(msg: dict) -> str:
    """Checks one SNS message and acts on it. Returns what was done (for tests and the log)."""
    verify(msg)
    kind = msg["Type"]
    if kind == "SubscriptionConfirmation":
        if not _sns_url(msg.get("SubscribeURL", "")):
            raise Refused("subscribe URL not from SNS")
        confirm(msg["SubscribeURL"])
        log.info("ses events: subscription confirmed")
        return "confirmed"
    if kind == "UnsubscribeConfirmation":
        log.warning("ses events: the topic unsubscribed this endpoint")
        return "unsubscribed"
    try:
        event = json.loads(msg["Message"])
    except (KeyError, ValueError):
        return "ignored"
    # Configuration set events say eventType; identity notifications say notificationType.
    what = event.get("eventType") or event.get("notificationType")
    if what == "Bounce":
        b = event.get("bounce") or {}
        people = [r.get("emailAddress", "") for r in b.get("bouncedRecipients") or []]
        if b.get("bounceType") != "Permanent":
            log.info("ses events: soft bounce (%s), %d recipient(s), still sending", b.get("bounceType"), len(people))
            return "soft_bounce"
        for p in people:
            if p:
                mark(p, "bounce", f"{b.get('bounceType')}/{b.get('bounceSubType', '')}")
        return "bounce"
    if what == "Complaint":
        c = event.get("complaint") or {}
        for p in [r.get("emailAddress", "") for r in c.get("complainedRecipients") or []]:
            if p:
                mark(p, "complaint", c.get("complaintFeedbackType", "") or "")
        return "complaint"
    if what == "Delivery":
        log.info("ses events: delivered")
        return "delivery"
    return "ignored"


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="Stop or restart sending to an address (also update the SES suppression list).")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--clear", metavar="EMAIL", help="send to it again (the person says their mailbox works)")
    g.add_argument("--mark", metavar="EMAIL", help="stop sending to it (the person says it's wrong or not theirs)")
    a = ap.parse_args()
    if a.mark:
        mark(a.mark, "bounce", "marked by hand")
        print("marked: nothing more is sent to it")
    else:
        print("cleared" if clear(a.clear) else "that address wasn't on the list")
