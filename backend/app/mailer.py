"""Email from no-reply@magana.ng: sign-in codes and teacher invitations.

MAGANA_MAIL selects how (docs/DEPLOY_AWS.md, "Email: AWS SES"):
- ses     AWS SES in eu-west-2, through the instance's IAM role (no password stored).
          MAIL_FROM defaults to "Magana for Teachers <no-reply@magana.ng>".
- outbox  development and tests only: each email is written to MAGANA_DATA_DIR/outbox/ as
          JSON. Refused when MAGANA_ENV is production.
Nothing here logs an email address or a code.
"""
from __future__ import annotations

import json
import logging
import os
import secrets
from pathlib import Path

log = logging.getLogger("magana.mail")

DEFAULT_FROM = "Magana for Teachers <no-reply@magana.ng>"


class MailError(Exception):
    pass


def _outbox(to: str, subject: str, text: str) -> None:
    if os.environ.get("MAGANA_ENV", "production") == "production":
        raise MailError("outbox mail is for development only: set MAGANA_MAIL=ses")
    d = Path(os.environ.get("MAGANA_DATA_DIR", "data")) / "outbox"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{secrets.token_hex(6)}.json").write_text(json.dumps({"to": to, "subject": subject, "text": text}))


def _ses(to: str, subject: str, text: str) -> None:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError

    try:
        boto3.client("sesv2", region_name=os.environ.get("SES_REGION", "eu-west-2")).send_email(
            FromEmailAddress=os.environ.get("MAIL_FROM", DEFAULT_FROM),
            Destination={"ToAddresses": [to]},
            Content={"Simple": {"Subject": {"Data": subject, "Charset": "UTF-8"},
                                "Body": {"Text": {"Data": text, "Charset": "UTF-8"}}}},
        )
    except (BotoCoreError, ClientError) as e:
        raise MailError(type(e).__name__) from e


def send(to: str, subject: str, text: str) -> None:
    how = os.environ.get("MAGANA_MAIL", "outbox" if os.environ.get("MAGANA_ENV") == "development" else "ses")
    (_ses if how == "ses" else _outbox)(to, subject, text)
    log.info("mail sent kind=%s", subject.split(":")[0][:40])


def sign_in_code(to: str, code: str) -> None:
    send(to, "Your Magana sign-in code",
         f"Your Magana for Teachers sign-in code is {code[:3]} {code[3:]}.\n\n"
         f"It works for 10 minutes. If you didn't ask for it, you can ignore this email.\n\n"
         f"Magana never asks for a password.")


def invitation(to: str, school: str, inviter: str, portal_url: str) -> None:
    send(to, f"Invitation: {school} on Magana for Teachers",
         f"{inviter} invited you to {school} on Magana for Teachers.\n\n"
         f"Sign in at {portal_url}/sign-in/ with this email address. We'll send you a 6-digit code: "
         f"no password needed.\n\nThis invitation expires in 7 days.")
