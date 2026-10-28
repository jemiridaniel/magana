"""Accounts: schools, sign-in by email code, roles, class and teacher codes, the class link,
consent, removal, deletion, the audit log and Home (portal_api.py, learner_api.py)."""
import io
import json
import re
from datetime import timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import accounts, codes, database, places
from app.main import app

TEAM = "team@magana.test"
TOTP_SECRET = "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"  # test team members' authenticator key (development only)
APPROVE = {"decision": "approve", "checks": ["person_confirmed", "school_exists", "details_correct"]}
PRINCIPAL = "adebayo.folake@gmail.com"


@pytest.fixture(autouse=True)
def fresh(tmp_path, monkeypatch):
    monkeypatch.setenv("MAGANA_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("MAGANA_ENV", "development")
    monkeypatch.setenv("MAGANA_MAIL", "outbox")
    monkeypatch.delenv("MAGANA_API_KEY", raising=False)
    accounts.reset_for_tests()
    codes.attempts = codes.Attempts()
    import app.learner_api as la
    import app.portal_api as pa
    monkeypatch.setattr(pa, "codes", codes)
    monkeypatch.setattr(la, "codes", codes)
    pa.ip_rate.hits.clear()
    make_team(TEAM, "owner")
    yield tmp_path


def make_team(email: str, role: str = "owner", name: str = "Magana Owner", totp_ready: bool = True) -> None:
    """A Magana team member, made with the server's setup command (development flags)."""
    from app import team_setup
    args = ["--email", email, "--name", name, "--role", role] + (["--totp-secret", TOTP_SECRET] if totp_ready else [])
    assert team_setup.main(args) == 0


def totp_code(email: str, secret: str = TOTP_SECRET) -> str:
    """The next authenticator code this member hasn't used (codes can't be used twice)."""
    from app import team, totp
    with accounts.db() as con:
        last = team.member_by_email(con, email)["totp_last_counter"]
    c = totp.counter_now() if last is None else max(totp.counter_now(), last + 1)
    return totp.code_at(secret, c)


def outbox(tmp: Path, to: str) -> list[dict]:
    d = tmp / "outbox"
    mails = [json.loads(p.read_text()) for p in sorted(d.glob("*.json"), key=lambda p: p.stat().st_mtime)] if d.exists() else []
    return [m for m in mails if m["to"] == to]


def last_code(tmp: Path, to: str) -> str:
    """The code from the last sign-in email's subject ("642 126 is your Magana sign-in code")."""
    subject = [m for m in outbox(tmp, to) if m["kind"] == "sign_in_code"][-1]["subject"]
    return re.match(r"(\d{3}) (\d{3})", subject).group(0).replace(" ", "")


def sign_in(tmp: Path, email: str) -> TestClient:
    c = TestClient(app)
    accounts_now = accounts.now  # the 45 s gap is per email; tests sign in once per email
    r = c.post("/portal/auth/request-code", json={"email": email})
    assert r.status_code == 200, r.text
    r = c.post("/portal/auth/verify", json={"email": email, "code": last_code(tmp, email)})
    assert r.status_code == 200, r.text
    if r.json()["code"] == "totp_required":  # a Magana team member: the authenticator step
        r = c.post("/portal/auth/totp", json={"code": totp_code(email)})
        assert r.status_code == 200, r.text
    assert accounts.now is accounts_now
    return c


def lagos_ikeja() -> tuple[str, str]:
    lagos = next(s for s in places.data()["states"] if s["name"] == "Lagos")
    return lagos["code"], next(l["code"] for l in lagos["lgas"] if l["name"] == "Ikeja")


def register(email=PRINCIPAL) -> str:
    state, lga = lagos_ikeja()
    r = TestClient(app).post("/portal/schools/register", json={
        "email": email, "name": "Mrs Folake Adebayo", "role": "Principal", "phone": "0803 000 0001",
        "school": "Ikeja Community School", "state": state, "lga": lga, "agree": True})
    assert r.status_code == 201, r.text
    return r.json()["school_id"]


def approved_school(tmp) -> tuple[str, TestClient]:
    sid = register()
    team = sign_in(tmp, TEAM)
    assert team.post(f"/portal/admin/schools/{sid}", json=APPROVE).status_code == 200
    return sid, sign_in(tmp, PRINCIPAL)


def invite(admin: TestClient, tmp, email: str, role="teacher") -> TestClient:
    r = admin.post("/portal/staff", json={"email": email, "name": f"Teacher {email[:4]}", "role": role})
    assert r.status_code == 201, r.text
    assert "invited you" in outbox(tmp, email)[-1]["text"]
    return sign_in(tmp, email)


def new_class(c: TestClient, name="SS2 Science", mode="guided", level="sss2") -> dict:
    r = c.post("/portal/classes", json={"name": name, "level": level, "mode": mode})
    assert r.status_code == 201, r.text
    return r.json()


def phone(tier="guided", device="dev-1"):
    return {"X-Magana-Tier": tier, "X-Magana-Device": device}


def png():
    buf = io.BytesIO()
    Image.new("RGB", (300, 200), "white").save(buf, "PNG")
    return buf.getvalue()


def everything_in_db(tmp) -> str:
    """Every row of every table (SQLite or Postgres), for "never stored" checks."""
    out = []
    with accounts.db() as con:
        for t in database.tables(con):
            out += [repr(tuple(r)) for r in con.execute(f"SELECT * FROM {t}").fetchall()]
    return "\n".join(out)


# ---------- places

def test_states_and_lgas_are_complete_and_coded():
    states = places.data()["states"]
    assert len(states) == 37  # 36 states and the FCT
    assert sum(len(s["lgas"]) for s in states) == 774
    by = {s["name"]: len(s["lgas"]) for s in states}
    assert (by["Lagos"], by["Kano"], by["Katsina"], by["Federal Capital Territory"], by["Bayelsa"]) == (20, 44, 34, 6, 8)
    assert all(re.fullmatch(r"NG-[A-Z]{2}", s["code"]) for s in states)
    lga_codes = [l["code"] for s in states for l in s["lgas"]]
    assert len(set(lga_codes)) == 774 and all(re.fullmatch(r"NG-[A-Z]{2}-[A-Z0-9-]+", c) for c in lga_codes)
    assert all(c.startswith(s["code"] + "-") for s in states for c in (l["code"] for l in s["lgas"]))
    state, lga = lagos_ikeja()
    assert places.valid(state, lga) and not places.valid("NG-KN", lga)


# ---------- codes

@pytest.mark.parametrize("code", ["111111", "123456", "654321", "121212", "123123", "112233", "123321", "012345", "12345"])
def test_simple_codes_are_never_made(code):
    assert codes.is_simple(code)


def test_new_codes_are_six_digits_and_not_simple():
    for _ in range(200):
        c = codes.new_code()
        assert re.fullmatch(r"\d{6}", c) and not codes.is_simple(c)


def test_three_wrong_tries_lock_for_five_minutes():
    t = [0.0]
    a = codes.Attempts(clock=lambda: t[0])
    assert a.failed("k") == 0 and a.failed("k") == 0
    assert a.failed("k") == 300
    t[0] = 299
    assert a.locked_for("k") > 0
    t[0] = 301
    assert a.locked_for("k") == 0


# ---------- schools and sign-in

def test_a_new_school_is_pending_until_the_magana_team_approves_it(fresh):
    sid = register()
    principal = sign_in(fresh, PRINCIPAL)
    me = principal.get("/portal/me").json()
    assert me["role"] == "admin" and me["school"]["status"] == "pending"
    r = principal.get("/portal/classes")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "school_pending"
    assert principal.get("/portal/admin/schools").status_code == 403  # not the team
    team = sign_in(fresh, TEAM)
    assert [s["id"] for s in team.get("/portal/admin/schools").json()] == [sid]
    team.post(f"/portal/admin/schools/{sid}", json=APPROVE)
    assert principal.get("/portal/classes").status_code == 200


def test_registration_checks_place_codes_phone_and_agreement():
    state, lga = lagos_ikeja()
    base = {"email": "x@yahoo.com", "name": "Mr X", "role": "Principal", "phone": "0803 000 0002",
            "school": "Kano School", "state": "NG-KN", "lga": lga, "agree": True}
    c = TestClient(app)
    assert c.post("/portal/schools/register", json=base).json()["detail"]["code"] == "place_unknown"
    assert c.post("/portal/schools/register", json={**base, "state": state, "phone": "12345"}).status_code == 422
    assert c.post("/portal/schools/register", json={**base, "state": state, "agree": False}).json()["detail"]["code"] == "agree_required"


def test_uninvited_emails_get_the_same_answer_and_no_email(fresh):
    r = TestClient(app).post("/portal/auth/request-code", json={"email": "nobody@gmail.com"})
    assert r.status_code == 200 and r.json()["code"] == "sign_in_code_sent"
    assert outbox(fresh, "nobody@gmail.com") == []
    r = TestClient(app).post("/portal/auth/verify", json={"email": "nobody@gmail.com", "code": "482915"})
    assert r.status_code == 400


def test_wrong_codes_lock_sign_in_and_a_new_code_waits_45_seconds(fresh):
    register()
    c = TestClient(app)
    c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    again = c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    assert again.status_code == 429 and again.json()["detail"]["code"] == "code_sent_recently"
    right = last_code(fresh, PRINCIPAL)
    wrong = "730913" if right != "730913" else "815204"
    codes_seen = [c.post("/portal/auth/verify", json={"email": PRINCIPAL, "code": wrong}).json()["detail"]["code"]
                  for _ in range(3)]
    assert codes_seen == ["sign_in_code_wrong", "sign_in_code_wrong", "code_locked"]
    r = c.post("/portal/auth/verify", json={"email": PRINCIPAL, "code": right})
    assert r.status_code == 429  # even the right code waits out the lock


def test_a_code_expires_after_10_minutes(fresh, monkeypatch):
    register()
    c = TestClient(app)
    c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    code = last_code(fresh, PRINCIPAL)
    later = accounts.now() + timedelta(minutes=11)
    import app.portal_api as pa
    monkeypatch.setattr(pa, "now", lambda: later)
    r = c.post("/portal/auth/verify", json={"email": PRINCIPAL, "code": code})
    assert r.json()["detail"]["code"] == "sign_in_code_expired"


def test_the_session_cookie_is_httponly_and_ends_after_30_idle_minutes(fresh, monkeypatch):
    register()
    c = TestClient(app)
    c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    r = c.post("/portal/auth/verify", json={"email": PRINCIPAL, "code": last_code(fresh, PRINCIPAL)})
    cookie = r.headers["set-cookie"].lower()
    assert "httponly" in cookie and "samesite=lax" in cookie and "path=/" in cookie
    assert c.get("/portal/me").status_code == 200
    later = accounts.now() + timedelta(minutes=31)
    import app.portal_api as pa
    monkeypatch.setattr(pa, "now", lambda: later)
    r = c.get("/portal/me")
    assert r.status_code == 401 and r.json()["detail"]["code"] == "session_expired"


def test_in_production_the_cookie_is_secure(fresh, monkeypatch):
    register()
    sent = []
    import app.portal_api as pa
    monkeypatch.setattr(pa.mailer, "send", lambda to, email: sent.append(email.subject[:7].replace(" ", "")))
    monkeypatch.setenv("MAGANA_ENV", "production")
    monkeypatch.setenv("MAGANA_CODE_KEY", "k" * 32)
    c = TestClient(app)
    c.post("/portal/auth/request-code", json={"email": PRINCIPAL})
    r = c.post("/portal/auth/verify", json={"email": PRINCIPAL, "code": sent[-1]})
    assert "secure" in r.headers["set-cookie"].lower()


# ---------- staff and roles

def test_invites_expire_after_7_days(fresh, monkeypatch):
    _, admin = approved_school(fresh)
    admin.post("/portal/staff", json={"email": "late@gmail.com", "name": "Late Teacher"})
    with accounts.db() as con:  # 8 days later
        con.execute("UPDATE staff SET invite_expires = ? WHERE email = ?",
                    (accounts.iso(accounts.now() - timedelta(days=1)), "late@gmail.com"))
    TestClient(app).post("/portal/auth/request-code", json={"email": "late@gmail.com"})
    assert [m for m in outbox(fresh, "late@gmail.com") if "sign-in code" in m["subject"]] == []
    assert [s["status"] for s in admin.get("/portal/staff").json() if s["email"] == "late@gmail.com"] == ["expired"]


def test_inviting_the_same_email_twice_sends_one_invitation_and_logs_one(fresh):
    sid, admin = approved_school(fresh)
    body = {"email": "tunde.bakare@gmail.com", "name": "Mr Tunde Bakare", "role": "teacher"}
    assert admin.post("/portal/staff", json=body).status_code == 201
    r = admin.post("/portal/staff", json={**body, "email": "Tunde.Bakare@gmail.com"})
    assert (r.status_code, r.json()["detail"]["code"]) == (409, "email_taken")
    assert len(outbox(fresh, "tunde.bakare@gmail.com")) == 1
    with accounts.db() as con:
        assert con.execute("SELECT COUNT(*) FROM audit WHERE school_id = ? AND action = 'staff_invited'", (sid,)).fetchone()[0] == 1


def test_teachers_see_only_their_classes_and_admins_see_all(fresh):
    _, admin = approved_school(fresh)
    grace = invite(admin, fresh, "grace.eze@gmail.com")
    musa = invite(admin, fresh, "musabello@ikejacs.edu.ng")
    g = new_class(grace, "Primary 5", "classroom", "p5")
    m = new_class(musa, "JSS 1 English", "guided", "jss1")
    assert [c["id"] for c in grace.get("/portal/classes").json()] == [g["id"]]
    assert {c["id"] for c in admin.get("/portal/classes").json()} == {g["id"], m["id"]}
    assert grace.get(f"/portal/classes/{m['id']}/learners").status_code == 404
    assert grace.get("/portal/staff").json()["detail"]["code"] == "not_admin"


def test_the_last_admin_cant_go_and_two_admins_stay(fresh):
    _, admin = approved_school(fresh)
    me = admin.get("/portal/me").json()
    r = admin.post(f"/portal/staff/{me['id']}/remove", json={})
    assert r.json()["detail"]["code"] == "last_admin"
    vice = invite(admin, fresh, "c.okafor@yahoo.com", role="admin")
    vid = vice.get("/portal/me").json()["id"]
    r = admin.patch(f"/portal/staff/{vid}", json={"role": "teacher"})
    assert r.json()["detail"]["code"] == "admins_minimum"
    third = invite(admin, fresh, "third@gmail.com", role="admin")
    assert admin.patch(f"/portal/staff/{vid}", json={"role": "teacher"}).status_code == 200
    assert third.get("/portal/me").json()["role"] == "admin"


def test_removing_a_teacher_needs_their_classes_moved_and_signs_them_out(fresh):
    _, admin = approved_school(fresh)
    ngozi = invite(admin, fresh, "ngozi.uche@gmail.com")
    musa = invite(admin, fresh, "musa@gmail.com")
    cls = new_class(ngozi, "JSS 2 Maths", "guided", "jss2")
    nid = ngozi.get("/portal/me").json()["id"]
    mid = musa.get("/portal/me").json()["id"]
    r = admin.post(f"/portal/staff/{nid}/remove", json={})
    assert r.json()["detail"] == {"code": "classes_need_new_teacher", "classes": [cls["id"]]}
    assert ngozi.get("/portal/me").status_code == 200
    assert admin.post(f"/portal/staff/{nid}/remove", json={"reassign": {cls["id"]: mid}}).status_code == 200
    assert ngozi.get("/portal/me").status_code == 401  # signed out at once
    assert [c["id"] for c in musa.get("/portal/classes").json()] == [cls["id"]]
    actions = [(a["action"], a["target"]) for a in admin.get("/portal/audit").json()]
    assert ("staff_removed", nid) in actions and ("staff_invited", nid) in actions


# ---------- the class link

def test_class_codes_are_stored_hashed_and_rotating_kills_the_old_one(fresh):
    _, admin = approved_school(fresh)
    cls = new_class(admin)
    assert re.fullmatch(r"\d{6}", cls["code"])
    assert cls["code"] not in everything_in_db(fresh)
    t = TestClient(app)
    old = cls["code"]
    new = admin.post(f"/portal/classes/{cls['id']}/rotate-code").json()["class_code"]
    assert t.post("/learner/join", json={"class_code": old}, headers=phone("standard", "a")).json()["detail"]["code"] == "class_code_wrong"
    assert t.post("/learner/join", json={"class_code": new}, headers=phone("standard", "b")).status_code == 200


def test_under_18_waits_for_consent_reads_schoolwork_only_until_the_teacher_records_it(fresh):
    _, admin = approved_school(fresh)
    cls = new_class(admin)
    t = TestClient(app)
    j = t.post("/learner/join", json={"class_code": cls["code"]}, headers=phone()).json()
    assert j["status"] == "waiting_consent" and j["class"]["name"] == "SS2 Science"
    linked = {**phone(), "X-Magana-Learner": j["token"], "X-Magana-Guardian-Consent": "yes"}  # the app can't claim it
    assert t.post("/read", files={"file": ("p.png", png())}, data={"mode": "school"}, headers=linked).status_code == 200
    r = t.post("/explain", json={"source_text": "Plants make food.", "lang": "en"}, headers=linked)
    assert r.json()["detail"]["code"] == "consent_required"
    [l] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    assert l["consent"] == "pending" and l["phone_linked"]
    admin.post(f"/portal/learners/{l['id']}/consent", json={"how": "signed_form"})
    assert t.get("/learner/me", headers=linked).json()["status"] == "active"
    assert t.post("/explain", json={"source_text": "Plants make food.", "lang": "en"}, headers=linked).status_code == 200


def test_classroom_classes_and_under_13s_dont_join(fresh):
    _, admin = approved_school(fresh)
    p5 = new_class(admin, "Primary 5", "classroom", "p5")
    t = TestClient(app)
    assert t.post("/learner/join", json={"class_code": p5["code"]}, headers=phone("standard")).json()["detail"]["code"] == "class_has_no_accounts"
    assert t.post("/learner/join", json={"class_code": p5["code"]}, headers=phone("classroom")).status_code == 403


def test_three_wrong_class_codes_lock_the_phone_for_5_minutes(fresh):
    approved_school(fresh)
    t = TestClient(app)
    got = [t.post("/learner/join", json={"class_code": c}, headers=phone(device="guesser")).json()["detail"]["code"]
           for c in ("730913", "815204", "482917")]
    assert got == ["class_code_wrong", "class_code_wrong", "code_locked"]


def test_an_under_18_changes_class_only_with_a_teacher_code(fresh):
    _, admin = approved_school(fresh)
    a, b = new_class(admin, "SS2 Science"), new_class(admin, "SS2 Arts")
    t = TestClient(app)
    j = t.post("/learner/join", json={"class_code": a["code"]}, headers=phone(device="teen")).json()
    me = {**phone(device="teen"), "X-Magana-Learner": j["token"]}
    assert t.post("/learner/join", json={"class_code": b["code"]}, headers=me).json()["detail"]["code"] == "teacher_code_needed"
    tc = admin.get("/portal/me/teacher-code").json()["teacher_code"]
    assert tc not in everything_in_db(fresh)
    wrong = [t.post("/learner/change-class", json={"teacher_code": w, "class_code": b["code"]}, headers=me).json()["detail"]["code"]
             for w in ("730913", "815204", "482917")]
    assert wrong == ["teacher_code_wrong", "teacher_code_wrong", "code_locked"]
    codes.attempts.succeeded("teacher:teen")
    r = t.post("/learner/change-class", json={"teacher_code": tc, "class_code": b["code"]}, headers=me)
    assert r.status_code == 200 and r.json()["class"]["name"] == "SS2 Arts"


def test_adults_change_class_freely(fresh):
    _, admin = approved_school(fresh)
    a, b = new_class(admin, "Adult literacy", "standard", "sss3"), new_class(admin, "JAMB prep", "standard", "sss3")
    t = TestClient(app)
    j = t.post("/learner/join", json={"class_code": a["code"]}, headers=phone("standard", "adult")).json()
    assert j["status"] == "active"
    me = {**phone("standard", "adult"), "X-Magana-Learner": j["token"]}
    assert t.post("/learner/join", json={"class_code": b["code"]}, headers=me).json()["class"]["name"] == "JAMB prep"


def test_remove_from_class_needs_a_reason_unlinks_the_phone_and_keeps_the_record(fresh):
    _, admin = approved_school(fresh)
    cls = new_class(admin)
    t = TestClient(app)
    j = t.post("/learner/join", json={"class_code": cls["code"]}, headers=phone()).json()
    [l] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    assert admin.post(f"/portal/learners/{l['id']}/remove", json={}).json()["detail"]["code"] == "reason_required"
    assert admin.post(f"/portal/learners/{l['id']}/remove", json={"reason": "left"}).status_code == 200
    assert t.get("/learner/me", headers={"X-Magana-Learner": j["token"]}).json()["status"] == "not_linked"
    [kept] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    assert kept["status"] == "removed" and not kept["phone_linked"] and kept["removed_reason"] == "left"
    assert ("learner_removed", l["id"]) in [(a["action"], a["target"]) for a in admin.get("/portal/audit").json()]


def test_move_learner_only_within_the_school(fresh):
    _, admin = approved_school(fresh)
    a, b = new_class(admin, "SS2 Science"), new_class(admin, "SS2 Arts")
    TestClient(app).post("/learner/join", json={"class_code": a["code"]}, headers=phone())
    [l] = admin.get(f"/portal/classes/{a['id']}/learners").json()
    assert admin.post(f"/portal/learners/{l['id']}/move", json={"class_id": "cls_other"}).status_code == 404
    assert admin.post(f"/portal/learners/{l['id']}/move", json={"class_id": b["id"]}).status_code == 200
    assert [x["id"] for x in admin.get(f"/portal/classes/{b['id']}/learners").json()] == [l["id"]]


def test_a_guardians_deletion_request_leaves_nothing_about_the_learner(fresh):
    _, admin = approved_school(fresh)
    cls = new_class(admin)
    TestClient(app).post("/learner/join", json={"class_code": cls["code"]}, headers=phone())
    [l] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    admin.patch(f"/portal/learners/{l['id']}", json={"name": "Chiamaka Okafor", "formats": ["large_print", "audio"]})
    admin.post(f"/portal/learners/{l['id']}/consent", json={"how": "in_person"})
    admin.put(f"/portal/classes/{cls['id']}/attendance",
              json={"day": "2026-11-18", "marks": [{"learner_id": l["id"], "mark": "absent"}]})
    with accounts.db() as con:
        con.execute("INSERT INTO learner_stats(learner_id, week, pages, unaided, quiz_avg) VALUES (?,?,?,?,?)",
                    (l["id"], "2026-W47", 23, 10, 58))
    r = admin.post(f"/portal/learners/{l['id']}/remove", json={"reason": "deletion"}).json()
    [pending] = admin.get("/portal/deletions").json()
    assert pending["id"] == r["deletion_id"]
    home = admin.get("/portal/home").json()
    assert any(a["kind"] == "deletion" for a in home["attention"])
    assert admin.post(f"/portal/deletions/{r['deletion_id']}/confirm").status_code == 200
    db = everything_in_db(fresh)
    assert l["id"] not in db and "Chiamaka" not in db and "large_print" not in db and "2026-W47" not in db
    assert admin.get(f"/portal/learners/{l['id']}").status_code == 404


# ---------- Home

def test_home_with_nothing_to_do_and_with_real_attention_items(fresh):
    _, admin = approved_school(fresh)
    home = admin.get("/portal/home").json()
    assert [a["kind"] for a in home["attention"]] == ["second_admin"] and home["week"] is None
    cls = new_class(admin)
    t = TestClient(app)
    t.post("/learner/join", json={"class_code": cls["code"]}, headers=phone(device="d1"))
    [l] = admin.get(f"/portal/classes/{cls['id']}/learners").json()
    for day, mark in (("2026-11-11", "absent"), ("2026-11-12", "present"), ("2026-11-13", "absent")):
        admin.put(f"/portal/classes/{cls['id']}/attendance", json={"day": day, "marks": [{"learner_id": l["id"], "mark": mark}]})
    kinds = [a["kind"] for a in admin.get("/portal/home").json()["attention"]]
    assert "consent" in kinds and "low_attendance" in kinds
    r = admin.post(f"/portal/learners/{l['id']}/remind").json()
    assert r["code"] == "reminder_ready" and r["class_name"] == "SS2 Science"
    assert admin.get("/portal/home").json()["classes"][0]["attendance"] == 33
