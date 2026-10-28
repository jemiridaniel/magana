"""The six emails (mailer.py), who gets them, and the team's school approval (portal_api.py):
call notes, three checks, a reason, the proof of school kept private and deleted after."""
import base64
import io
import json
import logging
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import accounts, blobs, mailer, proofs
from app.main import app
from test_accounts import APPROVE, PRINCIPAL, TEAM, fresh, lagos_ikeja, make_team, outbox, sign_in  # noqa: F401

T = datetime(2026, 10, 26, 8, 36, tzinfo=timezone.utc)  # Mon 26 Oct, 09:36 in Lagos


def all_kinds():
    return [
        mailer.sign_in_code("642126", "Mrs Adebayo", T, "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/130.0", "Africa/Lagos"),
        mailer.registration_received("Mrs Adebayo", "Ikeja Community School", "Ikeja, Lagos", "Principal", "+2348030000000", "SCH-1047", T),
        mailer.new_school_request("Ikeja Community School", "Ikeja, Lagos", "Mrs Folake Adebayo", "Principal", PRINCIPAL,
                                  "+2348030000000", "SCH-1047", T, "https://teachers.magana.ng", True, "LSMOE/PS/2019/0412"),
        mailer.school_approved("Mrs Adebayo", "Ikeja Community School", "https://teachers.magana.ng"),
        mailer.school_not_approved("Mr Ade", "Bright Future Academy", "+2348020000011", "Agege, Lagos", "unreachable", "SCH-1048"),
        mailer.teacher_invitation("Mr Bakare", "Ikeja Community School", "Mrs Folake Adebayo", "Teacher", ["JSS 3 Basic Science"],
                                  "bakare@example.com", "https://teachers.magana.ng"),
    ]


def test_nine_emails_each_html_and_text_with_the_same_footer_and_the_logo():
    emails = all_kinds()
    emails.append(mailer.team_invitation("Remi", "Daniel", "School reviewer", "Approve or reject schools",
                                         "remi@example.com", "https://teachers.magana.ng"))
    emails.append(mailer.reputation_alert(0.031, None, 1000))
    emails.append(mailer.problem_report("It read something wrong", "reader", "0.1.0+6", "TECNO KI5q", "ha", "standard",
                                        voice_seconds=12, page_text=False, when=T, link="https://teachers.magana.ng/admin/reports/"))
    assert [e.kind for e in emails] == list(mailer.KINDS)
    for e in emails:
        assert e.html.startswith("<!doctype html>") and 'lang="en"' in e.html
        # One image, the hosted logo with alt text; the header reads the same without it.
        assert e.html.count("<img") == 1 and 'alt="Magana"' in e.html and "https://magana.ng/brand/magana-mark-email.png" in e.html
        assert "data:" not in e.html and "<svg" not in e.html and ">for Teachers<" in e.html
        assert "font-size:18px" in e.html and "background:#14171A" in e.html  # 18 px text, dark header
        assert "support@magana.ng" in e.html and "support@magana.ng" in e.text  # the footer
        assert "Magana never asks for a password or bank details." in e.text
        assert e.subject and e.preheader and len(e.text) > 80


def test_the_sign_in_code_is_in_the_subject_with_when_and_roughly_where():
    e = all_kinds()[0]
    # "verification code" and the digits together, as Gmail, Apple Mail and iOS autofill look for.
    assert e.subject == "Your Magana verification code: 642126"
    assert "642" not in e.preheader  # the inbox shows the subject and the preheader: the code once
    visible = e.html.split("</div>", 1)[1]  # after the hidden preheader
    # The first line says it in words, then one box with the six digits together, monospace at 44 px.
    assert visible.index("<p") < visible.index("YOUR CODE")
    assert ">Your Magana verification code is 642126.</p>" in e.html
    assert e.html.count(">642126<") == 1 and "642 126" not in e.html
    assert "font-size:44px" in e.html and "monospace" in e.html and "user-select:all" in e.html
    assert "Tap and hold (or double-click) the code to copy it." in e.html and "It works for 10 minutes." in e.html
    assert "nobody can sign in without the code" in e.html
    # Plain text: the same first line, then the code alone on its own line, then the rest.
    assert e.text.startswith("Your Magana verification code is 642126.\n\n642126\n\n")
    assert "It works for 10 minutes." in e.text and "nobody can sign in without the code" in e.text
    assert "642 126" not in e.text
    assert "Requested from Chrome on a Mac in Nigeria at 09:36 (Nigerian time), Mon 26 Oct." in e.text
    plain = mailer.sign_in_code("642126", None, T, "", "")
    assert "Requested from a browser at 09:36" in plain.text  # no device or place given: nothing invented
    assert mailer.rough_place("../../etc") is None


def test_phone_numbers_are_partly_hidden_except_for_the_team():
    reg, team, _, nope = all_kinds()[1], all_kinds()[2], None, all_kinds()[4]
    assert "0803 *** **00" in reg.text and "8030000000" not in reg.text
    assert "0802 *** **11" in nope.text and "We tried to call you 3 times" in nope.text
    assert "0803 000 0000" in team.text and "Team only" in team.html  # the team calls it
    assert "by Wed 28 Oct" in reg.text and "by Wed 28 Oct" in team.text  # 2 working days


def test_values_are_escaped_in_the_html():
    e = mailer.school_approved("<script>x</script>", "A & B <School>", "https://teachers.magana.ng")
    assert "<script>x" not in e.html and "A &amp; B &lt;School&gt;" in e.html


def test_every_reason_has_its_own_email_and_preview():
    for reason in mailer.REASONS:
        e = mailer.school_not_approved("Mr Ade", "Bright Future Academy", "+2348020000011", "Agege, Lagos", reason, "SCH-1048")
        what, can = mailer.reason_text(reason, "Bright Future Academy", "+2348020000011", "Agege, Lagos")
        assert what in e.text and all(c in e.text for c in can)
        assert "deleted in 30 days" in e.text


def test_resend_sends_html_and_text_with_replies_to_support(monkeypatch):
    calls = []

    class Answer:
        status_code = 200

    monkeypatch.setattr(mailer, "post", lambda url, **kw: calls.append((url, kw)) or Answer())
    monkeypatch.setenv("MAGANA_MAIL", "resend")
    monkeypatch.setenv("RESEND_API_KEY", "re_test")
    mailer.send("a@example.com", all_kinds()[3])
    url, kw = calls[0]
    body = kw["json"]
    assert url == "https://api.resend.com/emails" and kw["headers"]["Authorization"] == "Bearer re_test"
    assert body["reply_to"] == "support@magana.ng" and body["to"] == ["a@example.com"]
    assert body["html"] and body["text"]
    assert body["from"] == "Magana for Teachers <no-reply@magana.ng>"


def test_resend_errors_are_mail_errors_without_the_answer_text(monkeypatch):
    class Answer:
        status_code = 422
        text = "a@example.com is invalid"

    monkeypatch.setattr(mailer, "post", lambda url, **kw: Answer())
    monkeypatch.setenv("MAGANA_MAIL", "resend")
    monkeypatch.setenv("RESEND_API_KEY", "re_test")
    with pytest.raises(mailer.MailError) as e:
        mailer.send("a@example.com", all_kinds()[3])
    assert "a@example.com" not in str(e.value)
    monkeypatch.delenv("RESEND_API_KEY")
    with pytest.raises(mailer.MailError):
        mailer.send("a@example.com", all_kinds()[3])


def test_the_log_says_only_the_kind_and_the_time(fresh, caplog):
    caplog.set_level(logging.INFO, logger="magana.mail")
    mailer.send("someone@example.com", all_kinds()[0])
    [line] = [r.getMessage() for r in caplog.records]
    assert line.startswith("email sent: sign_in_code, 2")
    assert "someone" not in line and "642" not in line and "Adebayo" not in line


# ---------- registration, approval, the proof file

def png() -> str:
    buf = io.BytesIO()
    Image.new("RGB", (40, 30), "white").save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def register(**extra):
    state, lga = lagos_ikeja()
    body = {"email": PRINCIPAL, "name": "Mrs Folake Adebayo", "role": "Principal", "phone": "0803 000 0000",
            "school": "Ikeja Community School", "state": state, "lga": lga, "agree": True, "address": "14 Allen Avenue", "town": "Ikeja", **extra}
    return TestClient(app).post("/portal/schools/register", json=body)


def kinds_to(tmp, to):
    return [m["kind"] for m in outbox(tmp, to)]


def test_registering_emails_the_principal_and_every_owner_and_reviewer(fresh):
    make_team("second@magana.test", "reviewer")
    make_team("support@example.org", "support")
    r = register(ministry_no="LSMOE/PS/2019/0412")
    assert r.status_code == 201 and r.json()["reference"] == "SCH-1047"
    assert kinds_to(fresh, PRINCIPAL) == ["registration_received"]
    assert kinds_to(fresh, TEAM) == ["new_school_request"] and kinds_to(fresh, "second@magana.test") == ["new_school_request"]
    assert kinds_to(fresh, "support@example.org") == []  # Support (view only) isn't alerted
    [team_mail] = outbox(fresh, TEAM)
    assert "LSMOE/PS/2019/0412" in team_mail["text"] and team_mail["reply_to"] == "support@magana.ng"


def test_the_waiting_page_gets_the_reference_and_the_call_by_day(fresh):
    register()
    principal = sign_in(fresh, PRINCIPAL)
    school = principal.get("/portal/me").json()["school"]
    assert school["status"] == "pending" and school["reference"] == "SCH-1047"
    assert school["phone_masked"] == "0803 *** **00" and school["call_by"] and school["registered"]


def test_approving_needs_all_three_checks_and_emails_the_principal(fresh):
    sid = register().json()["school_id"]
    team = sign_in(fresh, TEAM)
    [s] = team.get("/portal/admin/schools").json()
    assert s["reference"] == "SCH-1047" and s["contact_phone"] == "0803 000 0000" and s["days_left"] >= 0
    r = team.post(f"/portal/admin/schools/{sid}", json={"decision": "approve", "checks": ["person_confirmed", "school_exists"]})
    assert (r.status_code, r.json()["detail"]["code"]) == (400, "checks_required")
    assert team.put(f"/portal/admin/schools/{sid}/notes", json={"call_notes": "Spoke to Mrs Adebayo 11:05.",
                                                                "checks": ["person_confirmed"]}).json()["code"] == "notes_saved"
    assert team.get("/portal/admin/schools").json()[0]["call_notes"] == "Spoke to Mrs Adebayo 11:05."
    r = team.post(f"/portal/admin/schools/{sid}", json=APPROVE)
    assert r.json() == {"code": "school_approved", "emailed": True}
    assert kinds_to(fresh, PRINCIPAL)[-1] == "school_approved"
    [done] = team.get("/portal/admin/schools?status=approved").json()
    assert done["decided_by"] == TEAM and done["call_notes"] == "Spoke to Mrs Adebayo 11:05."
    assert team.post(f"/portal/admin/schools/{sid}", json=APPROVE).json()["detail"]["code"] == "school_decided"


def test_not_approving_needs_a_reason_shows_the_email_first_and_sends_it(fresh):
    sid = register().json()["school_id"]
    team = sign_in(fresh, TEAM)
    assert team.post(f"/portal/admin/schools/{sid}", json={"decision": "reject"}).json()["detail"]["code"] == "reason_required"
    previews = {p["reason"]: p["preview"] for p in team.get(f"/portal/admin/reasons?school_id={sid}").json()}
    assert set(previews) == set(mailer.REASONS) and "0803 *** **00" in previews["unreachable"]
    team.post(f"/portal/admin/schools/{sid}", json={"decision": "reject", "reason": "not_found"})
    [mail] = [m for m in outbox(fresh, PRINCIPAL) if m["kind"] == "school_not_approved"]
    assert "We couldn’t find Ikeja Community School in Ikeja, Lagos." in mail["text"]
    [s] = team.get("/portal/admin/schools?status=rejected").json()
    assert s["reason_label"] == "School couldn’t be found"


def test_only_the_team_can_see_the_approval_pages(fresh):
    sid = register().json()["school_id"]
    principal = sign_in(fresh, PRINCIPAL)
    for path in ("/portal/admin/schools", "/portal/admin/activity", f"/portal/admin/reasons?school_id={sid}",
                 f"/portal/admin/schools/{sid}/proof"):
        assert principal.get(path).status_code == 403, path
    assert principal.post(f"/portal/admin/schools/{sid}", json=APPROVE).status_code == 403
    assert TestClient(app).get("/portal/admin/schools").status_code == 401


def test_the_proof_is_encrypted_team_only_and_deleted_once_decided(fresh):
    sid = register(proof=png()).json()["school_id"]
    stored = blobs.get("proof", sid)
    assert b"PNG" not in stored  # encrypted at rest
    team = sign_in(fresh, TEAM)
    assert team.get("/portal/admin/schools").json()[0]["proof"] == "image/png"
    r = team.get(f"/portal/admin/schools/{sid}/proof")
    assert r.status_code == 200 and r.content.startswith(b"\x89PNG") and r.headers["cache-control"] == "no-store"
    team.post(f"/portal/admin/schools/{sid}", json=APPROVE)
    assert blobs.get("proof", sid) is None and not (fresh / "proofs").exists()
    assert team.get(f"/portal/admin/schools/{sid}/proof").status_code == 404
    log = [a for a in team.get("/portal/admin/activity").json()["items"] if a["action"].startswith("school_")]
    assert [a["action"] for a in log][:3] == ["school_approved", "school_proof_viewed", "school_registered"]
    assert log[0]["who_email"] == TEAM and log[0]["about"] == "Ikeja Community School · SCH-1047"


def test_a_proof_that_isnt_a_photo_or_pdf_is_refused():
    assert register(proof="data:image/png;base64," + base64.b64encode(b"<html>not an image</html>").decode()).json()["detail"]["code"] == "proof_wrong_type"


def test_not_confirmed_schools_are_deleted_after_30_days(fresh):
    sid = register().json()["school_id"]
    team = sign_in(fresh, TEAM)
    team.post(f"/portal/admin/schools/{sid}", json={"decision": "reject", "reason": "unreachable"})
    with accounts.db() as con:
        con.execute("UPDATE schools SET decided_at = ? WHERE id = ?",
                    (accounts.iso(accounts.now() - timedelta(days=31)), sid))
    assert team.get("/portal/admin/schools?status=rejected").json() == []
    with accounts.db() as con:
        assert con.execute("SELECT COUNT(*) FROM staff WHERE email = ?", (PRINCIPAL,)).fetchone()[0] == 0
