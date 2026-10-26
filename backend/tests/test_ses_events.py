"""Bounces and complaints (ses_events.py, ses_health.py, mailer.py): SNS signatures, the
subscription, marking an address undeliverable and never sending to it again, the portal flags,
the configuration set on every email, the sign-in code limits, and the weekly reputation check."""
import base64
import json
from datetime import datetime, timedelta, timezone

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID
from fastapi.testclient import TestClient

from app import accounts, mailer, portal_api, ses_events, ses_health
from app.main import app
from test_accounts import (PRINCIPAL, TEAM, approved_school, fresh, invite, outbox, register,  # noqa: F401
                           sign_in)

TOPIC = "arn:aws:sns:eu-west-2:111122223333:magana-ses-events"
CERT_URL = "https://sns.eu-west-2.amazonaws.com/SimpleNotificationService-test.pem"
KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _cert(key) -> bytes:
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "sns.amazonaws.com")])
    t = datetime.now(timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(1).not_valid_before(t - timedelta(days=1)).not_valid_after(t + timedelta(days=1))
            .sign(key, hashes.SHA256()))
    return cert.public_bytes(serialization.Encoding.PEM)


@pytest.fixture(autouse=True)
def sns(monkeypatch):
    monkeypatch.setenv("SES_EVENTS_TOPIC_ARN", TOPIC)
    ses_events._certs.clear()
    fetched, confirmed = [], []
    monkeypatch.setattr(ses_events, "fetch_cert", lambda url: fetched.append(url) or _cert(KEY))
    monkeypatch.setattr(ses_events, "confirm", lambda url: confirmed.append(url))
    return {"fetched": fetched, "confirmed": confirmed}


def signed(kind="Notification", key=KEY, version="2", **fields) -> dict:
    msg = {"Type": kind, "MessageId": "m-1", "TopicArn": TOPIC,
           "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
           "SignatureVersion": version, "SigningCertURL": CERT_URL, **fields}
    if kind != "Notification":
        msg.setdefault("Token", "tok")
        msg.setdefault("SubscribeURL", "https://sns.eu-west-2.amazonaws.com/?Action=ConfirmSubscription&Token=tok")
        msg.setdefault("Message", "You have chosen to subscribe")
    text = "".join(f"{k}\n{msg[k]}\n" for k in ses_events.SIGNED[kind] if k in msg)
    algo = hashes.SHA256() if version == "2" else hashes.SHA1()
    msg["Signature"] = base64.b64encode(key.sign(text.encode(), padding.PKCS1v15(), algo)).decode()
    return msg


def bounce(email, kind="Permanent") -> dict:
    # The "mail" part carries the subject (a sign-in code's subject holds the code): never read.
    return {"eventType": "Bounce", "mail": {"commonHeaders": {"subject": "642 126 is your Magana sign-in code"}},
            "bounce": {"bounceType": kind, "bounceSubType": "General", "bouncedRecipients": [{"emailAddress": email}]}}


def post(msg) -> "object":
    return TestClient(app).post("/internal/ses-events", content=json.dumps(msg), headers={"content-type": "text/plain"})


# ---------- the signature, the topic, the subscription

def test_subscription_is_confirmed_only_through_sns(sns):
    r = post(signed("SubscriptionConfirmation"))
    assert r.status_code == 200 and r.json()["done"] == "confirmed"
    assert sns["confirmed"] == ["https://sns.eu-west-2.amazonaws.com/?Action=ConfirmSubscription&Token=tok"]
    # A SubscribeURL anywhere else is never visited, even when signed.
    r = post(signed("SubscriptionConfirmation", SubscribeURL="https://evil.example/?Action=Confirm"))
    assert r.status_code == 403 and len(sns["confirmed"]) == 1


def test_needs_no_api_key(monkeypatch):
    monkeypatch.setenv("MAGANA_API_KEY", "secret")
    assert post(signed(Message=json.dumps({"eventType": "Delivery"}))).json()["done"] == "delivery"


@pytest.mark.parametrize("change", [
    "other_key", "other_topic", "tampered", "old", "cert_elsewhere", "cert_http", "no_version"])
def test_refuses_anything_not_signed_by_sns_for_our_topic(change, sns):
    msg = signed(Message=json.dumps(bounce("teacher@gmail.com")))
    if change == "other_key":
        msg = signed(key=rsa.generate_private_key(public_exponent=65537, key_size=2048),
                     Message=json.dumps(bounce("teacher@gmail.com")))
    elif change == "other_topic":
        msg = signed(TopicArn="arn:aws:sns:eu-west-2:999999999999:magana-ses-events",
                     Message=json.dumps(bounce("teacher@gmail.com")))
    elif change == "tampered":
        msg["Message"] = json.dumps(bounce("someone.else@gmail.com"))
    elif change == "old":
        msg = signed(Timestamp=(datetime.now(timezone.utc) - timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                     Message=json.dumps(bounce("teacher@gmail.com")))
    elif change == "cert_elsewhere":
        msg["SigningCertURL"] = "https://sns.eu-west-2.amazonaws.com.evil.example/cert.pem"
    elif change == "cert_http":
        msg["SigningCertURL"] = CERT_URL.replace("https", "http")
    elif change == "no_version":
        msg["SignatureVersion"] = "3"
    assert post(msg).status_code == 403
    assert not ses_events.is_undeliverable("teacher@gmail.com")
    assert not ses_events.is_undeliverable("someone.else@gmail.com")
    if change.startswith("cert_"):
        assert sns["fetched"] == []  # never fetched from anywhere but SNS


def test_signature_version_1_still_works():
    assert post(signed(version="1", Message=json.dumps(bounce("teacher@gmail.com")))).json()["done"] == "bounce"


def test_topic_defaults_to_ours_in_this_account(monkeypatch):
    monkeypatch.delenv("SES_EVENTS_TOPIC_ARN")
    monkeypatch.setattr(ses_events, "account_id", lambda: "111122223333")
    ses_events._expected.clear()
    try:
        assert ses_events.expected_topic() == TOPIC
    finally:
        ses_events._expected.clear()


def test_not_json_is_400():
    assert TestClient(app).post("/internal/ses-events", content="hello").status_code == 400


# ---------- bounces and complaints

def test_hard_bounce_marks_the_address_and_stops_every_send(fresh, caplog):
    caplog.set_level("INFO")
    assert post(signed(Message=json.dumps(bounce("Teacher@Gmail.com")))).json()["done"] == "bounce"
    assert ses_events.is_undeliverable("teacher@gmail.com")
    with pytest.raises(mailer.Undeliverable):
        mailer.send("teacher@gmail.com", mailer.sign_in_code("123456", "T", accounts.now(), "", ""))
    assert outbox(fresh, "teacher@gmail.com") == []
    # Logged with the address masked and nothing from the email itself.
    logs = caplog.text
    assert "t***@gmail.com" in logs and "teacher@gmail.com" not in logs.lower()
    assert "642 126" not in logs and "sign-in code" not in logs


def test_soft_bounce_and_delivery_change_nothing():
    assert post(signed(Message=json.dumps(bounce("teacher@gmail.com", "Transient")))).json()["done"] == "soft_bounce"
    assert post(signed(Message=json.dumps({"eventType": "Delivery", "delivery": {"recipients": ["teacher@gmail.com"]}}))
                ).json()["done"] == "delivery"
    assert not ses_events.is_undeliverable("teacher@gmail.com")


def test_complaint_marks_the_address():
    event = {"eventType": "Complaint", "complaint": {"complainedRecipients": [{"emailAddress": "head@school.ng"}],
                                                     "complaintFeedbackType": "abuse"}}
    assert post(signed(Message=json.dumps(event))).json()["done"] == "complaint"
    assert ses_events.is_undeliverable("head@school.ng")


def test_identity_notifications_work_too():
    event = {"notificationType": "Bounce", "bounce": {"bounceType": "Permanent", "bouncedRecipients": [
        {"emailAddress": "a@b.ng"}]}}
    assert post(signed(Message=json.dumps(event))).json()["done"] == "bounce"


def test_activity_log_and_clear(fresh):
    ses_events.mark("teacher@gmail.com", "bounce", "Permanent/General")
    team = sign_in(fresh, TEAM)
    entries = team.get("/portal/admin/activity", params={"action": "team_email_undeliverable"}).json()["items"]
    assert entries and entries[0]["label"] == "Email undeliverable"
    assert entries[0]["about"] == "t***@gmail.com · Hard bounce"
    assert ses_events.clear("teacher@gmail.com") and not ses_events.is_undeliverable("teacher@gmail.com")


# ---------- what the portal shows and refuses

def test_portal_flags_and_refuses_undeliverable_addresses(fresh):
    sid, admin = approved_school(fresh)
    invite(admin, fresh, "ok.teacher@gmail.com")
    r = admin.post("/portal/staff", json={"email": "late.teacher@gmail.com", "name": "Late Teacher"})
    late = r.json()["id"]
    ses_events.mark("late.teacher@gmail.com", "bounce")
    ses_events.mark("ok.teacher@gmail.com", "complaint")
    ses_events.mark("blocked@gmail.com", "bounce")
    staff = {s["email"]: s["undeliverable"] for s in admin.get("/portal/staff").json()}
    assert staff == {PRINCIPAL: False, "ok.teacher@gmail.com": True, "late.teacher@gmail.com": True}
    # No new invite to it, and no resend.
    r = admin.post("/portal/staff", json={"email": "blocked@gmail.com", "name": "Blocked Person"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"
    r = admin.post(f"/portal/staff/{late}/resend")
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"


def test_team_lists_show_it(fresh):
    register("bounced.head@gmail.com")
    ses_events.mark("bounced.head@gmail.com", "bounce")
    team = sign_in(fresh, TEAM)
    schools = team.get("/portal/admin/schools").json()
    assert [s["contact_undeliverable"] for s in schools] == [True]
    r = team.post("/portal/team/members", json={"email": "bounced.head@gmail.com", "name": "X Y", "role": "support"})
    assert r.status_code == 409  # a school's email (one role per email) or undeliverable: never sent
    ses_events.mark("new.support@gmail.com", "complaint")
    r = team.post("/portal/team/members", json={"email": "new.support@gmail.com", "name": "New Support", "role": "support"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "mail_undeliverable"
    members = {m["email"]: m["undeliverable"] for m in team.get("/portal/team/members").json()}
    assert members == {TEAM: False}


def test_sign_in_answers_the_same_for_an_undeliverable_address(fresh):
    approved_school(fresh)
    ses_events.mark(PRINCIPAL, "bounce")
    before = len(outbox(fresh, PRINCIPAL))
    r = TestClient(app).post("/portal/auth/request-code", json={"email": PRINCIPAL})
    assert r.status_code == 200 and r.json()["code"] == "sign_in_code_sent"
    assert len(outbox(fresh, PRINCIPAL)) == before


# ---------- the sign-in code limits (as told to AWS)

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


# ---------- every email goes through the configuration set

class FakeSes:
    def __init__(self, fail_first=None):
        self.calls, self.fail_first = [], fail_first

    def send_email(self, **kw):
        from botocore.exceptions import ClientError
        self.calls.append(kw)
        if self.fail_first and len(self.calls) == 1:
            raise ClientError({"Error": {"Code": self.fail_first, "Message": "x"}}, "SendEmail")


def test_every_email_uses_the_configuration_set(monkeypatch):
    monkeypatch.setenv("MAGANA_MAIL", "ses")
    fake = FakeSes()
    monkeypatch.setattr(mailer, "ses_client", lambda: fake)
    mailer.send("a@b.ng", mailer.ses_reputation_alert(0.03, None))
    assert fake.calls[0]["ConfigurationSetName"] == "magana-default"


def test_missing_configuration_set_still_sends_loudly(monkeypatch, caplog):
    monkeypatch.setenv("MAGANA_MAIL", "ses")
    fake = FakeSes(fail_first="NotFoundException")
    monkeypatch.setattr(mailer, "ses_client", lambda: fake)
    mailer.send("a@b.ng", mailer.ses_reputation_alert(0.03, None))
    assert len(fake.calls) == 2 and "ConfigurationSetName" not in fake.calls[1]
    assert "setup-ses-events" in caplog.text


def test_other_ses_errors_are_mail_errors(monkeypatch):
    monkeypatch.setenv("MAGANA_MAIL", "ses")
    monkeypatch.setattr(mailer, "ses_client", lambda: FakeSes(fail_first="MessageRejected"))
    with pytest.raises(mailer.MailError):
        mailer.send("a@b.ng", mailer.ses_reputation_alert(0.03, None))


# ---------- the weekly reputation check

@pytest.mark.parametrize("bounce_rate, complaint_rate, alert", [
    (0.019, 0.0004, False), (0.021, 0.0, True), (0.0, 0.0006, True), (None, None, False)])
def test_weekly_reputation_check(fresh, monkeypatch, bounce_rate, complaint_rate, alert):
    rates = {"Reputation.BounceRate": bounce_rate, "Reputation.ComplaintRate": complaint_rate}
    monkeypatch.setattr(ses_health, "read_metric", lambda m: rates[m])
    found = ses_health.run_if_due()
    assert bool(found["over"]) is alert
    sent = outbox(fresh, "daniel@magana.ng")
    assert len(sent) == (1 if alert else 0)
    if alert:
        assert "limit 2%" in sent[0]["text"] and "limit 0.05%" in sent[0]["text"]
    assert ses_health.run_if_due() is None  # once a week
    t = accounts.now() + timedelta(days=7, minutes=1)
    monkeypatch.setattr(ses_health, "now", lambda: t)
    assert ses_health.run_if_due() is not None


def test_reputation_check_failure_retries_next_time(monkeypatch):
    def broken(_):
        raise RuntimeError("no permission")
    monkeypatch.setattr(ses_health, "read_metric", broken)
    assert ses_health.run_if_due() is None and ses_health.due()


def test_check_runs_only_on_the_production_ses_server(monkeypatch):
    assert not ses_health.enabled()  # tests: development, outbox
    monkeypatch.setenv("MAGANA_ENV", "production")
    monkeypatch.setenv("MAGANA_MAIL", "ses")
    assert ses_health.enabled()
