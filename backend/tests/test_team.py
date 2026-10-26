"""Magana team accounts (team.py, team_api.py): roles, the first owner made on the server, sign-in
with an email code plus an authenticator code, 15 minutes idle, one role per email, the activity
log, and the proof that team accounts can't see learners."""
import json
import re
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from app import accounts, team, team_setup, totp
from app.main import app
from test_accounts import (APPROVE, PRINCIPAL, TEAM, TOTP_SECRET, approved_school, fresh, last_code,  # noqa: F401
                           make_team, new_class, outbox, phone, register, sign_in, totp_code)


def email_step(tmp, email) -> tuple[TestClient, dict]:
    c = TestClient(app)
    assert c.post("/portal/auth/request-code", json={"email": email}).status_code == 200
    r = c.post("/portal/auth/verify", json={"email": email, "code": last_code(tmp, email)})
    assert r.status_code == 200, r.text
    return c, r.json()


# ---------- the first owner, on the server

def test_the_first_owner_is_made_once_on_the_server(fresh, monkeypatch, capsys):
    monkeypatch.setenv("MAGANA_ENV", "production")
    monkeypatch.setenv("MAGANA_CODE_KEY", "k" * 32)
    # The fixture already made TEAM an owner: a second "first owner" is refused outside development.
    assert team_setup.main(["--email", "other@magana.test", "--name", "Other"]) == 1
    assert "already exists" in capsys.readouterr().err
    assert team_setup.main(["--email", "x@magana.test", "--name", "X", "--totp-secret", TOTP_SECRET]) == 2
    with accounts.db() as con:
        assert con.execute("UPDATE team_members SET status = 'removed'").rowcount == 1
    assert team_setup.main(["--email", "daniel@magana.test", "--name", "Jemiri Daniel Taiwo"]) == 0
    with accounts.db() as con:
        m = team.member_by_email(con, "daniel@magana.test")
    assert (m["role"], m["status"], m["totp_confirmed_at"]) == ("owner", "active", None)


def test_there_is_no_web_route_that_makes_an_owner_without_an_owner():
    paths = {getattr(r, "path", "") for r in app.routes}
    assert not [p for p in paths if "setup" in p or "bootstrap" in p]
    assert TestClient(app).post("/portal/team/members", json={"email": "a@b.ng", "name": "AB", "role": "owner"}).status_code == 401


# ---------- sign-in: email code, then the authenticator

def test_first_sign_in_sets_up_the_authenticator_and_shows_backup_codes_once(fresh):
    make_team("remi@magana.test", "reviewer", "Oluremi Balogun", totp_ready=False)
    c, r = email_step(fresh, "remi@magana.test")
    assert r["code"] == "totp_setup" and r["uri"].startswith("otpauth://totp/Magana:remi%40magana.test?secret=")
    secret = r["key"].replace(" ", "")
    assert c.get("/portal/me").json()["detail"]["code"] == "totp_required"  # not signed in yet
    assert c.post("/portal/auth/totp", json={"code": "000000"}).json()["detail"]["code"] == "totp_wrong"
    r = c.post("/portal/auth/totp", json={"code": totp_code("remi@magana.test", secret)}).json()
    assert r["code"] == "signed_in" and r["me"]["role"] == "reviewer" and len(r["backup_codes"]) == 8
    backup = r["backup_codes"]
    assert all(re.fullmatch(r"\d{4}-\d{4}", b) for b in backup)
    with accounts.db() as con:
        stored = team.member_by_email(con, "remi@magana.test")
    assert secret not in (stored["totp_sealed"] or "") and backup[0] not in stored["backup_codes"]  # sealed and hashed

    # Next time: the authenticator code (never the same one twice), or a backup code, once.
    c2, r = email_step(fresh, "remi@magana.test")
    assert r == {"code": "totp_required"}
    used = totp_code("remi@magana.test", secret)
    assert c2.post("/portal/auth/totp", json={"code": used}).json()["code"] == "signed_in"
    c3, _ = email_step(fresh, "remi@magana.test")
    assert c3.post("/portal/auth/totp", json={"code": used}).json()["detail"]["code"] == "totp_wrong"  # replay
    assert c3.post("/portal/auth/totp", json={"backup_code": backup[0]}).json()["code"] == "signed_in"
    c4, _ = email_step(fresh, "remi@magana.test")
    assert c4.post("/portal/auth/totp", json={"backup_code": backup[0]}).json()["detail"]["code"] == "totp_wrong"


def test_three_wrong_authenticator_codes_lock_it(fresh):
    c, _ = email_step(fresh, TEAM)
    for _ in range(2):
        assert c.post("/portal/auth/totp", json={"code": "111111"}).status_code == 400
    r = c.post("/portal/auth/totp", json={"code": "111111"})
    assert (r.status_code, r.json()["detail"]["code"]) == (429, "code_locked")
    assert c.post("/portal/auth/totp", json={"code": totp_code(TEAM)}).json()["detail"]["code"] == "code_locked"


def test_team_sessions_end_after_15_idle_minutes(fresh, monkeypatch):
    c = sign_in(fresh, TEAM)
    assert c.get("/portal/me").status_code == 200
    import app.portal_api as pa
    real = pa.now
    monkeypatch.setattr(pa, "now", lambda: real() + timedelta(minutes=16))
    assert c.get("/portal/me").json()["detail"]["code"] == "session_expired"


# ---------- roles

def test_what_each_role_can_do(fresh):
    sid = register()
    make_team("rev@magana.test", "reviewer")
    make_team("sup@magana.test", "support")
    owner, rev, sup = sign_in(fresh, TEAM), sign_in(fresh, "rev@magana.test"), sign_in(fresh, "sup@magana.test")
    # Support (view only): schools, a school's teachers, resend emails. Nothing else.
    assert sup.get("/portal/admin/schools").status_code == 200
    assert [t["email"] for t in sup.get(f"/portal/admin/schools/{sid}/teachers").json()] == [PRINCIPAL]
    assert sup.post(f"/portal/admin/schools/{sid}/resend").json()["code"] == "school_email_resent"
    for method, path, body in [("post", f"/portal/admin/schools/{sid}", APPROVE), ("put", f"/portal/admin/schools/{sid}/notes", {}),
                               ("get", f"/portal/admin/reasons?school_id={sid}", None), ("get", "/portal/admin/activity", None),
                               ("get", "/portal/team/members", None)]:
        r = getattr(sup, method)(path, **({"json": body} if body is not None else {}))
        assert (r.status_code, r.json()["detail"]["code"]) == (403, "team_role_needed"), path
    # School reviewer: decides schools and sees the log; not the team.
    assert rev.get("/portal/admin/activity").status_code == 200
    assert rev.get("/portal/team/members").status_code == 403
    assert rev.post(f"/portal/admin/schools/{sid}", json=APPROVE).json()["code"] == "school_approved"
    # Owner: the team.
    assert {m["email"] for m in owner.get("/portal/team/members").json()} == {TEAM, "rev@magana.test", "sup@magana.test"}


def test_owners_invite_change_and_remove_and_one_owner_always_stays(fresh):
    owner = sign_in(fresh, TEAM)
    me = owner.get("/portal/team/members").json()[0]
    assert owner.post(f"/portal/team/members/{me['id']}/remove").json()["detail"]["code"] == "owners_minimum"
    assert owner.patch(f"/portal/team/members/{me['id']}", json={"role": "support"}).json()["detail"]["code"] == "owners_minimum"
    r = owner.post("/portal/team/members", json={"email": "amos@magana.test", "name": "Dr. Oluba Amos", "role": "reviewer"})
    assert r.status_code == 201 and r.json()["emailed"]
    [mail] = outbox(fresh, "amos@magana.test")
    assert mail["kind"] == "team_invitation" and "School reviewer" in mail["text"]
    amos = r.json()["id"]
    c, step = email_step(fresh, "amos@magana.test")
    assert step["code"] == "totp_setup"
    c.post("/portal/auth/totp", json={"code": totp_code("amos@magana.test", step["key"].replace(" ", ""))})
    assert owner.patch(f"/portal/team/members/{amos}", json={"role": "owner"}).json()["code"] == "team_role_changed"
    assert owner.post(f"/portal/team/members/{me['id']}/remove").json()["code"] == "team_member_removed"  # two owners: fine
    assert owner.get("/portal/me").status_code == 401  # signed out at once
    log = [a["action"] for a in c.get("/portal/admin/activity").json()["items"]]
    assert {"team_member_invited", "team_authenticator_set_up", "team_role_changed", "team_member_removed"} <= set(log)


# ---------- one role per email

def test_a_team_email_cant_be_a_teacher_and_a_teacher_cant_join_the_team(fresh):
    _, principal = approved_school(fresh)
    owner = sign_in(fresh, TEAM)
    assert owner.post("/portal/team/members", json={"email": PRINCIPAL, "name": "Principal", "role": "support"}).json()["detail"]["code"] == "email_is_teacher"
    assert principal.post("/portal/staff", json={"email": TEAM, "name": "Team Person", "role": "teacher"}).json()["detail"]["code"] == "email_is_team"
    r = TestClient(app).post("/portal/schools/register", json={
        "email": TEAM, "name": "Mr T", "role": "Principal", "phone": "0803 000 0009", "school": "T School",
        "state": "NG-LA", "lga": "NG-LA-IKEJA", "agree": True})
    assert r.json()["detail"]["code"] == "email_is_team"
    assert team_setup.main(["--email", PRINCIPAL, "--name", "Principal", "--role", "support"]) == 1


# ---------- learners: never visible to the team

def test_team_accounts_cant_see_any_learner_data(fresh):
    sid, principal = approved_school(fresh)
    cls = new_class(principal)
    t = TestClient(app)
    joined = t.post("/learner/join", json={"class_code": cls["code"]}, headers=phone()).json()
    [learner] = principal.get(f"/portal/classes/{cls['id']}/learners").json()
    principal.patch(f"/portal/learners/{learner['id']}", json={"name": "Chiamaka Obi"})
    principal.post(f"/portal/learners/{learner['id']}/consent", json={"how": "form"})
    owner = sign_in(fresh, TEAM)
    ids = {"school_id": sid, "class_id": cls["id"], "learner_id": learner["id"], "staff_id": "x", "quiz_id": "x",
           "deletion_id": "x", "upload_id": "x", "member_id": "x"}
    leaked = []
    for route in app.routes:
        path = getattr(route, "path", "")
        if not path.startswith(("/portal/", "/learner/")):
            continue
        url = re.sub(r"\{(\w+)\}", lambda m: ids.get(m.group(1), "x"), path)
        for method in getattr(route, "methods", []) - {"HEAD", "OPTIONS"}:
            r = owner.request(method, url, json={})
            text = r.text
            if "Chiamaka" in text or learner["id"] in text or joined["token"] in text:
                leaked.append((method, path, r.status_code))
            team_ok = path.startswith(("/portal/admin/", "/portal/team/", "/portal/auth/", "/portal/me", "/portal/places",
                                       "/portal/schools/register", "/learner/"))
            if not team_ok:
                assert r.status_code in (401, 403, 404, 405, 422), (method, path, r.status_code)
    assert leaked == []
    # The learner, class, progress and consent pages in particular say why.
    for path in (f"/portal/classes/{cls['id']}/learners", f"/portal/learners/{learner['id']}", "/portal/home", "/portal/classes"):
        assert owner.get(path).json()["detail"]["code"] == "not_for_team"


# ---------- resetting the authenticator (a leaked key, a lost phone)

def test_reset_my_authenticator_needs_a_current_code_and_kills_the_old_key(fresh):
    c = sign_in(fresh, TEAM)
    assert c.post("/portal/team/me/authenticator/reset", json={"code": "000000"}).json()["detail"]["code"] == "totp_wrong"
    assert c.post("/portal/team/me/authenticator/reset", json={"code": totp_code(TEAM)}).json()["code"] == "authenticator_reset"
    assert c.get("/portal/me").status_code == 401  # signed out everywhere
    c2, step = email_step(fresh, TEAM)
    assert step["code"] == "totp_setup" and step["key"].replace(" ", "") != TOTP_SECRET  # a new key
    assert c2.post("/portal/auth/totp", json={"code": totp.code_at(TOTP_SECRET, totp.counter_now())}).json()["detail"]["code"] == "totp_wrong"
    new = step["key"].replace(" ", "")
    assert c2.post("/portal/auth/totp", json={"code": totp_code(TEAM, new)}).json()["code"] == "signed_in"
    [reset] = [a for a in c2.get("/portal/admin/activity").json()["items"] if a["action"] == "team_authenticator_reset"]
    assert "(self)" in reset["about"]


def test_an_owner_resets_another_members_authenticator_and_the_server_command_is_the_fallback(fresh, capsys):
    make_team("rev@magana.test", "reviewer")
    rev = sign_in(fresh, "rev@magana.test")
    owner = sign_in(fresh, TEAM)
    rid = next(m["id"] for m in owner.get("/portal/team/members").json() if m["email"] == "rev@magana.test")
    me = next(m["id"] for m in owner.get("/portal/team/members").json() if m["email"] == TEAM)
    assert owner.post(f"/portal/team/members/{me}/reset-authenticator").json()["detail"]["code"] == "use_reset_my_authenticator"
    assert rev.post(f"/portal/team/members/{me}/reset-authenticator").status_code == 403  # owners only
    assert owner.post(f"/portal/team/members/{rid}/reset-authenticator").json()["code"] == "authenticator_reset"
    assert rev.get("/portal/me").status_code == 401
    assert email_step(fresh, "rev@magana.test")[1]["code"] == "totp_setup"
    # The server command: for an owner locked out with no other owner to help.
    assert team_setup.main(["--email", TEAM, "--reset-authenticator"]) == 0
    assert "authenticator is reset" in capsys.readouterr().out
    assert owner.get("/portal/me").status_code == 401
    with accounts.db() as con:
        actions = [(r["actor"], json.loads(r["detail"])["by"]) for r in
                   con.execute("SELECT actor, detail FROM audit WHERE action = 'team_authenticator_reset' ORDER BY id")]
    assert actions == [(f"team:{TEAM}", "owner"), ("server", "server command")]
