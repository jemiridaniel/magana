"""Bounces and complaints (mail_events.py, mail_health.py, mailer.py): Resend's signed webhook,
marking an address undeliverable and never sending to it again, the portal flags, the sign-in
code limits, and the weekly reputation check from our own counts."""
import base64
import hashlib
import hmac
import json
import time
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from app import accounts, mail_events, mail_health, mailer, portal_api
from app.main import app
from test_accounts import (PRINCIPAL, TEAM, approved_school, fresh, invite, outbox, register,  # noqa: F401
                           sign_in)

SECRET = base64.b64encode(b"magana-test-webhook-secret").decode()


@pytest.fixture(autouse=True)
def webhook_secret(monkeypatch):
    monkeypatch.setenv("RESEND_WEBHOOK_SECRET", f"whsec_{SECRET}")


def headers(body: bytes, secret: str = SECRET, at: float | None = None, msg_id: str = "msg_1") -> dict:
    stamp = str(int(time.time() if at is None else at))
    sig = base64.b64encode(hmac.new(base64.b64decode(secret), f"{msg_id}.{stamp}.".encode() + body,
                                    hashlib.sha256).digest()).decode()
    return {"svix-id": msg_id, "svix-timestamp": stamp, "svix-signature": f"v1,{sig}", "content-type": "application/json"}


def event(kind: str, to: str, **data) -> bytes:
    # The subject (a sign-in code's subject holds the code) is in the event: never read or logged.
    return json.dumps({"type": kind, "created_at": "2026-10-28T09:00:00Z",
                       "data": {"email_id": "e1", "to": [to], "subject": "Your Magana verification code: 642126", **data}}).encode()


def post(body: bytes, h: dict | None = None):
    return TestClient(app).post("/internal/mail-events", content=body, headers=headers(body) if h is None else h)


# ---------- the signature

def test_needs_no_api_key_but_a_signature(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "app-key")
    body = event("email.delivered", "a@b.ng")
    assert post(body).json()["done"] == "delivered"


@pytest.mark.parametrize("change", ["no_headers", "wrong_secret", "tampered", "too_old", "no_secret_set"])
def test_refuses_anything_not_signed_with_our_secret(change, monkeypatch):
    body = event("email.bounced", "teacher@gmail.com")
    h = headers(body)
    if change == "no_headers":
        h = {"content-type": "application/json"}
    elif change == "wrong_secret":
        h = headers(body, secret=base64.b64encode(b"someone-else").decode())
    elif change == "tampered":
        body = event("email.bounced", "other@gmail.com")
    elif change == "too_old":
        h = headers(body, at=time.time() - 6 * 60)
    else:
        monkeypatch.delenv("RESEND_WEBHOOK_SECRET")
    assert post(body, h).status_code == 403
    assert not mail_events.is_undeliverable("teacher@gmail.com")


def test_a_rotated_secret_still_works_with_two_signatures():
    body = event("email.delivered", "a@b.ng")
    h = headers(body)
    old = headers(body, secret=base64.b64encode(b"old-secret").decode())
    h["svix-signature"] = f"{old['svix-signature']} {h['svix-signature']}"
    assert post(body, h).status_code == 200


# ---------- bounces and complaints

def test_bounce_marks_the_address_and_stops_every_send(fresh, caplog):
    caplog.set_level("INFO")
    assert post(event("email.bounced", "Teacher@Gmail.com", bounce={"type": "Permanent"})).json()["done"] == "bounce"
    assert mail_events.is_undeliverable("teacher@gmail.com")
    with pytest.raises(mailer.Undeliverable):
        mailer.send("teacher@gmail.com", mailer.sign_in_code("123456", "T", accounts.now(), "", ""))
    assert outbox(fresh, "teacher@gmail.com") == []
    # Logged with the address masked and nothing from the email itself.
    logs = caplog.text
    assert "t***@gmail.com" in logs and "teacher@gmail.com" not in logs.lower()
    assert "642126" not in logs and "verification code" not in logs


def test_delay_and_delivery_change_nothing():
    assert post(event("email.delivery_delayed", "teacher@gmail.com")).json()["done"] == "delivery_delayed"
    assert post(event("email.delivered", "teacher@gmail.com")).json()["done"] == "delivered"
    assert not mail_events.is_undeliverable("teacher@gmail.com")


def test_complaint_marks_the_address():
    assert post(event("email.complained", "head@school.ng")).json()["done"] == "complaint"
    assert mail_events.is_undeliverable("head@school.ng")


def test_activity_log_and_clear(fresh):
    mail_events.mark("teacher@gmail.com", "bounce", "Permanent/General")
    team = sign_in(fresh, TEAM)
    entries = team.get("/portal/admin/activity", params={"action": "team_email_undeliverable"}).json()["items"]
    assert entries and entries[0]["label"] == "Email undeliverable"
    assert entries[0]["about"] == "t***@gmail.com · Hard bounce"
    assert mail_events.clear("teacher@gmail.com") and not mail_events.is_undeliverable("teacher@gmail.com")


# ---------- what the portal shows and refuses

def test_portal_flags_and_refuses_undeliverable_addresses(fresh):
    sid, admin = approved_school(fresh)
    invite(admin, fresh, "ok.teacher@gmail.com")
    r = admin.post("/portal/staff", json={"email": "late.teacher@gmail.com", "name": "Late Teacher"})
    late = r.json()["id"]
    mail_events.mark("late.teacher@gmail.com", "bounce")
    mail_events.mark("ok.teacher@gmail.com", "complaint")
    mail_events.mark("blocked@gmail.com", "bounce")
    staff = {s["email"]: s["undeliverable"] for s in admin.get("/portal/staff").json()}
    assert staff == {PRINCIPAL: False, "ok.teacher@gmail.com": True, "late.teacher@gmail.com": True}
    # No new invite to it, and no resend.
    r = admin.post("/portal/staff", json={"email": "blocked@gmail.com", "name": "Blocked Person"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"
    r = admin.post(f"/portal/staff/{late}/resend")
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"


def test_team_lists_show_it(fresh):
    register("bounced.head@gmail.com")
    mail_events.mark("bounced.head@gmail.com", "bounce")
    team = sign_in(fresh, TEAM)
    schools = team.get("/portal/admin/schools").json()
    assert [s["contact_undeliverable"] for s in schools] == [True]
    r = team.post("/portal/team/members", json={"email": "bounced.head@gmail.com", "name": "X Y", "role": "support"})
    assert r.status_code == 409  # a school's email (one role per email) or undeliverable: never sent
    mail_events.mark("new.support@gmail.com", "complaint")
    r = team.post("/portal/team/members", json={"email": "new.support@gmail.com", "name": "New Support", "role": "support"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"
    members = {m["email"]: m["undeliverable"] for m in team.get("/portal/team/members").json()}
    assert members == {TEAM: False}


def test_sign_in_answers_the_same_for_an_undeliverable_address(fresh):
    approved_school(fresh)
    mail_events.mark(PRINCIPAL, "bounce")
    before = len(outbox(fresh, PRINCIPAL))
    r = TestClient(app).post("/portal/auth/request-code", json={"email": PRINCIPAL})
    assert r.status_code == 200 and r.json()["code"] == "sign_in_code_sent"
    assert len(outbox(fresh, PRINCIPAL)) == before


# ---------- the sign-in code limits

def test_sign_in_code_limits(fresh, monkeypatch):
    assert portal_api.CODES_PER_HOUR == 5 and accounts.LOGIN_CODE_MINUTES == 10 and portal_api.CODE_GAP_S == 45
    approved_school(fresh)
    t = [accounts.now()]
    monkeypatch.setattr(portal_api, "now", lambda: t[0])
    c = TestClient(app)
    for _ in range(4):  # the first came from sign_in in approved_school
        t[0] += timedelta(seconds=46)
        r = c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
        assert r.status_code == 200 and r.json()["minutes"] == 10
    t[0] += timedelta(seconds=46)
    r = c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    assert r.status_code == 429 and r.json()["detail"]["code"] == "too_many_codes"
    t[0] += timedelta(hours=1)
    assert c.post("/portal/auth/request-code", json={"email": PRINCIPAL}).status_code == 200


# ---------- the weekly reputation check, from our own counts

def counts(sent: int, bounced: int = 0, complained: int = 0) -> None:
    with accounts.db() as con:
        con.execute("INSERT OR REPLACE INTO mail_counts(day, sent, bounced, complained) VALUES (?,?,?,?)",
                    (accounts.now().date().isoformat(), sent, bounced, complained))


@pytest.mark.parametrize("sent, bounced, complained, alert", [
    (1000, 19, 0, False), (1000, 21, 0, True), (10000, 0, 6, True), (10, 5, 5, False)])
def test_weekly_reputation_check(fresh, monkeypatch, sent, bounced, complained, alert):
    counts(sent, bounced, complained)
    found = mail_health.run_if_due()
    assert bool(found["over"]) is alert
    alerts = outbox(fresh, "daniel@magana.ng")
    assert len(alerts) == (1 if alert else 0)
    if alert:
        assert "limit 2%" in alerts[0]["text"] and "limit 0.05%" in alerts[0]["text"]
    assert mail_health.run_if_due() is None  # once a week
    t = accounts.now() + timedelta(days=7, minutes=1)
    monkeypatch.setattr(mail_health, "now", lambda: t)
    assert mail_health.run_if_due() is not None


def test_sends_and_events_are_counted(fresh):
    mailer.send("a@b.ng", mailer.sign_in_code("123456", "T", accounts.now(), "", ""))
    post(event("email.bounced", "x@b.ng"))
    post(event("email.complained", "y@b.ng"))
    with accounts.db() as con:
        r = con.execute("SELECT sent, bounced, complained FROM mail_counts").fetchone()
    assert tuple(r) == (1, 1, 1)


def test_check_runs_only_on_the_production_server(monkeypatch):
    assert not mail_health.enabled()  # tests: development, outbox
    monkeypatch.setenv("MAGANA_ENV", "production")
    monkeypatch.setenv("MAGANA_MAIL", "resend")
    assert mail_health.enabled()
