"""Email from no-reply@magana.ng (boards "Emails & school approval"): six kinds, each as HTML
and plain text, replies going to support@magana.ng.

  sign_in_code            the code in the subject ("642 126 is your Magana sign-in code"),
                          when and from roughly where it was asked for
  registration_received   to the principal who registered a school
  new_school_request      to every active Owner and School reviewer (team.py)
  school_approved         to the principal
  school_not_approved     to the principal, with the reason the team chose
  teacher_invitation      to an invited teacher

The HTML is plain, accessible markup: 18 px text, a dark header with the name in text (no image
carries information: email apps block images and strip SVG), phone numbers partly hidden, and
the same footer. Never logged: only "email sent: <kind>, <time>".

MAGANA_MAIL selects how (docs/DEPLOY_AWS.md, "Email: AWS SES"):
- ses     AWS SES in eu-west-2, through the instance's IAM role (no password stored).
- outbox  development and tests only: each email is written to MAGANA_DATA_DIR/outbox/ as
          JSON. Refused when MAGANA_ENV is production.
"""
from __future__ import annotations

import json
import logging
import os
import re
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from html import escape
from pathlib import Path
from zoneinfo import ZoneInfo

log = logging.getLogger("magana.mail")

DEFAULT_FROM = "Magana for Teachers <no-reply@magana.ng>"
DEFAULT_REPLY_TO = "support@magana.ng"
LAGOS = ZoneInfo("Africa/Lagos")
KINDS = ("sign_in_code", "registration_received", "new_school_request", "school_approved", "school_not_approved",
         "teacher_invitation", "team_invitation")


class MailError(Exception):
    pass


@dataclass(frozen=True)
class Email:
    kind: str
    subject: str
    preheader: str  # the line inbox lists show after the subject
    html: str
    text: str


# ---------- small helpers

def reply_to() -> str:
    return os.environ.get("MAIL_REPLY_TO", DEFAULT_REPLY_TO)


def masked_phone(phone: str) -> str:
    """+2348030000000 → "0803 *** **00": enough to recognise, not enough to copy."""
    d = re.sub(r"\D", "", phone or "")
    if d.startswith("234"):
        d = "0" + d[3:]
    if len(d) < 6:
        return "***"
    return f"{d[:4]} *** **{d[-2:]}"


def local_phone(phone: str) -> str:
    """+2348030000000 → "0803 000 0000" (the team calls it)."""
    d = re.sub(r"\D", "", phone or "")
    if d.startswith("234"):
        d = "0" + d[3:]
    return f"{d[:4]} {d[4:7]} {d[7:]}" if len(d) == 11 else phone


def lagos_time(t: datetime) -> str:
    """"Mon 26 Oct, 09:36" in Nigerian time."""
    t = t.astimezone(LAGOS)
    return f"{t:%a} {t.day} {t:%b}, {t:%H:%M}"


def call_by(registered: datetime, working_days: int = 2) -> datetime:
    """The day the team promises to have called: registration plus 2 working days."""
    d = registered.astimezone(LAGOS)
    left = working_days
    while left:
        d += timedelta(days=1)
        if d.weekday() < 5:
            left -= 1
    return d


def day(t: datetime) -> str:
    t = t.astimezone(LAGOS)
    return f"{t:%a} {t.day} {t:%b}"


def device(user_agent: str) -> str:
    """"Chrome on a Mac", from the browser's User-Agent; "a browser" when unclear."""
    ua = user_agent or ""
    browser = next((name for key, name in [("Edg/", "Edge"), ("OPR/", "Opera"), ("Firefox/", "Firefox"),
                                           ("Chrome/", "Chrome"), ("Safari/", "Safari")] if key in ua), "a browser")
    system = next((name for key, name in [("Android", "an Android phone"), ("iPhone", "an iPhone"),
                                          ("iPad", "an iPad"), ("Mac OS X", "a Mac"), ("Windows", "Windows"),
                                          ("Linux", "Linux")] if key in ua), "")
    return f"{browser} on {system}" if system else browser


# A device's time zone, as the portal reports it: the only "place" Magana has (no IP lookup).
_ZONE_PLACES = {"Africa/Lagos": "Nigeria", "Africa/Abuja": "Nigeria", "Europe/London": "the UK",
                "Africa/Accra": "Ghana"}


def rough_place(tz: str) -> str | None:
    tz = (tz or "").strip()
    if not re.fullmatch(r"[A-Za-z_]+(/[A-Za-z_+-]+){1,2}", tz):
        return None
    return _ZONE_PLACES.get(tz, tz.split("/")[-1].replace("_", " "))


def ref(n: int) -> str:
    return f"SCH-{n}"


# ---------- the layout every email shares

INK, MUTED, GREEN, AMBER, GROUND = "#14171A", "#3D434A", "#0A6B4B", "#FFC94A", "#FBFAF6"
FONT = "'Atkinson Hyperlegible', Arial, Helvetica, sans-serif"


def _button(label: str, href: str) -> str:
    return (f'<a href="{escape(href)}" style="display:inline-block;padding:16px 28px;border-radius:30px;'
            f'background:{GREEN};color:#FFFFFF;font-weight:700;font-size:18px;text-decoration:none">{escape(label)}</a>')


def _rows(pairs: list[tuple[str, str]]) -> str:
    cells = "".join(
        f'<tr><td style="padding:10px 0;border-top:1px solid #E2DED4;color:{MUTED}">{escape(k)}</td>'
        f'<td style="padding:10px 0;border-top:1px solid #E2DED4;text-align:right;font-weight:700">{escape(v)}</td></tr>'
        for k, v in pairs)
    return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
            f'style="border-radius:12px;background:{GROUND};padding:4px 18px 8px;font-size:16px">{cells}</table>')


def _list(items: list[str], ordered: bool = True) -> str:
    tag = "ol" if ordered else "ul"
    return f'<{tag} style="margin:0;padding-left:22px">' + "".join(
        f'<li style="margin:0 0 8px">{i}</li>' for i in items) + f"</{tag}>"


def _page(title: str, preheader: str, body: str, team: bool = False) -> str:
    """Escape your values before passing them in: body is trusted markup."""
    foot = ("Sent to the Magana team only. " if team else "") + "Magana never asks for a password or bank details."
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>{escape(title)}</title></head>
<body style="margin:0;padding:0;background:#ECEAE4;color:{INK};font-family:{FONT}">
<div style="display:none;max-height:0;overflow:hidden">{escape(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td style="padding:28px 12px 36px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:0 auto;background:#FFFFFF;border-radius:16px;border:1px solid #D9D5CB;overflow:hidden">
<tr><td style="padding:20px 28px;background:{INK};color:#FFFFFF">
<span style="font-size:22px;font-weight:700">Magana</span><br>
<span style="font-size:14px;color:#C9CED4">for Teachers</span></td></tr>
<tr><td style="padding:28px;font-size:18px;line-height:1.5">{body}</td></tr>
<tr><td style="padding:18px 28px 24px;background:{GROUND};border-top:1px solid #E2DED4;font-size:14px;line-height:1.5;color:{MUTED}">
{foot}<br>Questions? Reply to <b style="color:{INK}">{escape(reply_to())}</b> · <a href="https://magana.ng" style="color:{GREEN}">magana.ng</a>
</td></tr></table></td></tr></table></body></html>"""


def _p(text: str, small: bool = False) -> str:
    style = f"margin:0 0 18px;font-size:16px;color:{MUTED}" if small else "margin:0 0 18px"
    return f'<p style="{style}">{text}</p>'


def _h1(text: str) -> str:
    return f'<h1 style="margin:0 0 18px;font-size:26px;line-height:1.25">{escape(text)}</h1>'


def _text(*parts: str) -> str:
    foot = f"Magana never asks for a password or bank details.\nQuestions? Reply to {reply_to()} · magana.ng"
    return "\n\n".join([*parts, foot]) + "\n"


# ---------- the six emails

def sign_in_code(code: str, name: str | None, requested: datetime, user_agent: str = "", tz: str = "") -> Email:
    spaced = f"{code[:3]} {code[3:]}"
    hello = f"Hello {name}, use" if name else "Use"
    place = rough_place(tz)
    where = f"Requested from {device(user_agent)}{f' in {place}' if place else ''} at {lagos_time(requested).split(', ')[1]} (Nigerian time), {day(requested)}."
    boxes = "".join(
        f'<span style="display:inline-block;width:46px;height:58px;line-height:58px;margin:0 {16 if i == 2 else 6}px 6px 0;'
        f'text-align:center;border-radius:10px;background:#FFFFFF;border:2px solid {INK};font-size:30px;font-weight:700">{c}</span>'
        for i, c in enumerate(code))
    body = (_h1("Your sign-in code") + _p(f"{escape(hello)} this code to sign in to Magana for Teachers:")
            + f'<div style="margin:0 0 18px;padding:20px;border-radius:14px;background:#FFF7E0;border:2px solid {AMBER}">'
            + f'<div aria-hidden="true">{boxes}</div>'
            + f'<p style="margin:6px 0 0;font-size:16px;color:{MUTED}">The code is <b style="color:{INK}">{spaced}</b>. It works for 10 minutes.</p></div>'
            + _p(f"{escape(where)} Didn’t ask for this? Ignore this email: nobody can sign in without the code.", small=True))
    pre = f"Works for 10 minutes. {hello} this code to sign in."
    text = _text(f"Your Magana sign-in code is {spaced}", "It works for 10 minutes.",
                 f"{where} Didn't ask for this? Ignore this email: nobody can sign in without the code.")
    return Email("sign_in_code", f"{spaced} is your Magana sign-in code", pre, _page("Your sign-in code", pre, body), text)


def registration_received(name: str, school: str, place: str, role: str, phone: str, reference: str,
                          registered: datetime) -> Email:
    by = day(call_by(registered))
    steps = [f"A member of the Magana team calls you on <b>{escape(masked_phone(phone))}</b> within 2 working days "
             f"(by {escape(by)}) to confirm the school.",
             "When it’s confirmed, we email you and you can invite your teachers.",
             "Teachers add their classes, and learners join with a class code."]
    body = (_h1("We’ve received your school")
            + _p(f"Hello {escape(name)}, thank you for registering <b>{escape(school)}</b> with Magana.")
            + "<p style=\"margin:0 0 10px\"><b>What happens next</b></p>" + _list(steps)
            + "<div style=\"height:12px\"></div>"
            + _rows([("School", school), ("Location", place), ("Your role", role), ("Reference", reference)])
            + "<div style=\"height:18px\"></div>"
            + _p("Wrong details, or didn’t register? Reply to this email and we’ll fix or remove it.", small=True))
    pre = "A Magana team member will call you within 2 working days."
    text = _text(f"Hello {name}, thank you for registering {school} with Magana.",
                 "What happens next\n" + "\n".join(f"{i}. {re.sub('<[^>]+>', '', s)}" for i, s in enumerate(steps, 1)),
                 f"School: {school}\nLocation: {place}\nYour role: {role}\nReference: {reference}",
                 "Wrong details, or didn't register? Reply to this email and we'll fix or remove it.")
    return Email("registration_received", f"We’ve received {school}", pre, _page("School registration received", pre, body), text)


def new_school_request(school: str, place: str, name: str, role: str, email: str, phone: str, reference: str,
                       registered: datetime, portal_url: str, proof: bool, ministry_no: str) -> Email:
    pairs = [("School", school), ("Location", place), ("Registered by", f"{name}, {role}"), ("Email", email),
             ("Phone", local_phone(phone)), ("Registered", lagos_time(registered)), ("Reference", reference),
             ("Proof of school", "Uploaded" if proof else "None"), ("Ministry approval no.", ministry_no or "None")]
    checks = ["Call the phone number and confirm the person and role.",
              "Check the school exists (a call to the school, or its listing).",
              "Note the call in the approval page."]
    by = day(call_by(registered))
    body = (f'<p style="margin:0 0 18px"><span style="display:inline-block;padding:4px 12px;border-radius:12px;'
            f'background:#FFF1D6;color:#4A2800;font-size:15px;font-weight:700">Team only · action needed</span></p>'
            + _h1("New school waiting for approval") + _rows(pairs) + "<div style=\"height:18px\"></div>"
            + "<p style=\"margin:0 0 10px\"><b>Before approving</b></p>" + _list(checks, ordered=False)
            + f'<p style="margin:18px 0">{_button("Review in team admin", f"{portal_url}/admin/")}</p>'
            + _p(f"Promised: a call within 2 working days, by {escape(by)}.", small=True))
    pre = f"Registered by {name}, {role}."
    text = _text("New school waiting for approval (team only)", "\n".join(f"{k}: {v}" for k, v in pairs),
                 "Before approving\n" + "\n".join(f"- {c}" for c in checks),
                 f"Review in team admin: {portal_url}/admin/", f"Promised: a call within 2 working days, by {by}.")
    html = _page("New school request", pre, body, team=True)
    return Email("new_school_request", f"New school to approve: {school}", pre, html, text)


def school_approved(name: str, school: str, portal_url: str) -> Email:
    steps = ["<b>Add a second admin</b>, such as your vice principal, so the school is never locked out.",
             "<b>Invite your teachers</b> with any email address.",
             "Teachers <b>create classes</b> and share class codes with learners."]
    body = (_h1("Your school is ready")
            + _p(f"Hello {escape(name)}, <b>{escape(school)}</b> is confirmed. You’re its first school admin.")
            + "<p style=\"margin:0 0 10px\"><b>Your first three steps</b></p>" + _list(steps)
            + f'<p style="margin:18px 0">{_button("Open Magana for Teachers", f"{portal_url}/sign-in/")}</p>'
            + _p(f"{escape(portal_url.split('//')[-1])} · sign in with this email and a 6-digit code.", small=True))
    pre = "You’re the first school admin. Here are your first three steps."
    text = _text(f"Hello {name}, {school} is confirmed. You're its first school admin.",
                 "Your first three steps\n" + "\n".join(f"{i}. {re.sub('<[^>]+>', '', s)}" for i, s in enumerate(steps, 1)),
                 f"Open Magana for Teachers: {portal_url}/sign-in/ (sign in with this email and a 6-digit code)")
    return Email("school_approved", f"{school} is ready on Magana", pre, _page("School approved", pre, body), text)


# Why a school wasn't confirmed: the label the team picks, and what the applicant reads.
REASONS = {
    "unreachable": "Couldn’t reach them after 3 calls",
    "role_unconfirmed": "Person couldn’t confirm their role",
    "not_found": "School couldn’t be found",
    "duplicate": "Duplicate of an existing school",
}


def reason_text(reason: str, school: str, phone: str, place: str) -> tuple[str, list[str]]:
    """(what happened, what they can do), plain text, for the email and its preview."""
    if reason == "unreachable":
        return (f"We tried to call you 3 times on {masked_phone(phone)} but couldn’t get through, so we haven’t "
                f"confirmed {school} yet.",
                ["Reply to this email with a better time or another phone number, and we’ll call again.",
                 "Or attach a photo of the school’s letterhead or Ministry approval letter."])
    if reason == "role_unconfirmed":
        return (f"When we called, we couldn’t confirm that you lead {school} or have its permission to register it.",
                ["Ask the principal or proprietor to register the school, or to reply to this email.",
                 "Or reply with a photo of the school’s letterhead or your staff ID card."])
    if reason == "not_found":
        return (f"We couldn’t find {school} in {place}.",
                ["Reply with the school’s address, or its Ministry of Education approval number.",
                 "Or attach a photo of the school’s letterhead or stamp."])
    return (f"{school} is already on Magana.",
            ["Ask the school’s Magana admin to invite you: they can do it from the Teachers page.",
             "Think it’s a different school? Reply to this email and tell us."])


def school_not_approved(name: str, school: str, phone: str, place: str, reason: str, reference: str) -> Email:
    what, can = reason_text(reason, school, phone, place)
    body = (_h1("We couldn’t confirm your school yet")
            + _p(f"Hello {escape(name)}, thank you for registering <b>{escape(school)}</b>. {escape(what)}")
            + "<p style=\"margin:0 0 10px\"><b>What you can do</b></p>" + _list([escape(c) for c in can], ordered=False)
            + f'<p style="margin:18px 0">{_button("Reply to the Magana team", f"mailto:{reply_to()}?subject=" + reference)}</p>'
            + _p(f"Reference {escape(reference)}. Nothing has been shared, and your details will be deleted in 30 days "
                 f"if we don’t hear from you.", small=True))
    pre = what
    text = _text(f"Hello {name}, thank you for registering {school}. {what}",
                 "What you can do\n" + "\n".join(f"- {c}" for c in can),
                 f"Reference {reference}. Nothing has been shared, and your details will be deleted in 30 days "
                 f"if we don't hear from you.")
    return Email("school_not_approved", f"We couldn’t confirm {school} yet", pre, _page("School not confirmed", pre, body), text)


def teacher_invitation(name: str | None, school: str, inviter: str, role: str, classes: list[str], email: str,
                       portal_url: str) -> Email:
    pairs = [("School", school), ("Your role", role)] + ([("Class" if len(classes) == 1 else "Classes", ", ".join(classes))]
                                                         if classes else [])
    hello = f"Hello {name}, " if name else ""
    link = f"{portal_url}/sign-in/?email={email}"
    body = (_h1("You’re invited to Magana")
            + _p(f"{escape(hello)}<b>{escape(inviter)}</b> has invited you to join <b>{escape(school)}</b> on Magana for Teachers.")
            + _p("Magana reads printed pages aloud for blind and low-vision learners. As a teacher you can share notes, "
                 "write voice quizzes and take attendance.")
            + _rows(pairs) + f'<p style="margin:18px 0">{_button("Accept invitation", link)}</p>'
            + _p("This invitation works for 7 days. No password needed: you’ll sign in with a code sent to this email. "
                 "Not expecting this? Ignore it.", small=True))
    pre = f"Join {school} on Magana for Teachers."
    text = _text(f"{hello}{inviter} has invited you to join {school} on Magana for Teachers.",
                 "\n".join(f"{k}: {v}" for k, v in pairs), f"Accept the invitation: {link}",
                 "This invitation works for 7 days. No password needed: you'll sign in with a code sent to this email. "
                 "Not expecting this? Ignore it.")
    return Email("teacher_invitation", f"{inviter} invited you to Magana", pre, _page("Teacher invitation", pre, body), text)


def team_invitation(name: str, inviter: str, role: str, can: str, email: str, portal_url: str) -> Email:
    """To a new Magana team member (not a school): what the role can do, and the extra protection."""
    link = f"{portal_url}/sign-in/?email={email}"
    steps = ["Sign in with this email: we send you a 6-digit code.",
             "Set up an authenticator app (Google Authenticator, Microsoft Authenticator, Authy or 2FAS). "
             "We show you 8 backup codes once: keep them somewhere safe.",
             "Every sign-in after that asks for an authenticator code too."]
    body = (f'<p style="margin:0 0 18px"><span style="display:inline-block;padding:4px 12px;border-radius:12px;'
            f'background:#FFF1D6;color:#4A2800;font-size:15px;font-weight:700">Magana staff only</span></p>'
            + _h1("You’re invited to the Magana team")
            + _p(f"Hello {escape(name)}, <b>{escape(inviter)}</b> has added you to the team that runs Magana.")
            + _rows([("Your role", role), ("You can", can)]) + '<div style="height:18px"></div>'
            + '<p style="margin:0 0 10px"><b>Your first sign-in</b></p>' + _list([escape(x) for x in steps])
            + f'<p style="margin:18px 0">{_button("Accept and sign in", link)}</p>'
            + _p("Team accounts never see learners’ names, progress or consent. This invitation works for 7 days. "
                 "Not expecting it? Ignore this email.", small=True))
    pre = f"{inviter} added you as {role}."
    text = _text(f"Hello {name}, {inviter} has added you to the team that runs Magana.",
                 f"Your role: {role}\nYou can: {can}",
                 "Your first sign-in\n" + "\n".join(f"{i}. {x}" for i, x in enumerate(steps, 1)),
                 f"Accept and sign in: {link}",
                 "Team accounts never see learners' names, progress or consent. This invitation works for 7 days. "
                 "Not expecting it? Ignore this email.")
    return Email("team_invitation", "You’re invited to the Magana team", pre, _page("Team invitation", pre, body, team=True), text)


# ---------- sending

def _outbox(to: str, email: Email) -> None:
    if os.environ.get("MAGANA_ENV", "production") == "production":
        raise MailError("outbox mail is for development only: set MAGANA_MAIL=ses")
    d = Path(os.environ.get("MAGANA_DATA_DIR", "data")) / "outbox"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{secrets.token_hex(6)}.json").write_text(json.dumps(
        {"to": to, "kind": email.kind, "subject": email.subject, "text": email.text, "html": email.html,
         "reply_to": reply_to()}))


def _ses(to: str, email: Email) -> None:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError

    try:
        boto3.client("sesv2", region_name=os.environ.get("SES_REGION", "eu-west-2")).send_email(
            FromEmailAddress=os.environ.get("MAIL_FROM", DEFAULT_FROM),
            Destination={"ToAddresses": [to]},
            ReplyToAddresses=[reply_to()],
            Content={"Simple": {"Subject": {"Data": email.subject, "Charset": "UTF-8"},
                                "Body": {"Text": {"Data": email.text, "Charset": "UTF-8"},
                                         "Html": {"Data": email.html, "Charset": "UTF-8"}}}},
        )
    except (BotoCoreError, ClientError) as e:
        raise MailError(type(e).__name__) from e


def send(to: str, email: Email) -> None:
    how = os.environ.get("MAGANA_MAIL", "outbox" if os.environ.get("MAGANA_ENV") == "development" else "ses")
    (_ses if how == "ses" else _outbox)(to, email)
    # Only the kind and the time: never an address, a name, a code or any content.
    log.info("email sent: %s, %s", email.kind, datetime.now(timezone.utc).isoformat(timespec="seconds"))
