"""The team's activity log (portal_api: /portal/admin/activity): search, filter, pages, an entry's
details; append-only (no way to edit or delete), kept 2 years, never holding learner data or codes.
And the authenticator setup: the QR drawn here, nothing secret logged or cacheable."""
import json
import logging
from datetime import timedelta

from fastapi.testclient import TestClient

from app import accounts
from app.main import app
from test_accounts import (APPROVE, PRINCIPAL, TEAM, approved_school, fresh, last_code, make_team,  # noqa: F401
                           new_class, phone, register, sign_in, totp_code)

TZ = {"X-Magana-Timezone": "Africa/Lagos",
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130.0 Safari/537.36"}


def team_client(tmp, email=TEAM) -> TestClient:
    c = TestClient(app, headers=TZ)
    c.post("/portal/auth/request-code", json={"email": email})
    c.post("/portal/auth/verify", json={"email": email, "code": last_code(tmp, email)})
    assert c.post("/portal/auth/totp", json={"code": totp_code(email)}).json()["code"] == "signed_in"
    return c


def test_search_filter_pages_and_an_approvals_details(fresh):
    sids = [register() if i == 0 else None for i in range(1)]
    team = team_client(fresh)
    team.put(f"/portal/admin/schools/{sids[0]}/notes", json={"call_notes": "Called 11:05, confirmed.", "checks": ["person_confirmed"]})
    team.post(f"/portal/admin/schools/{sids[0]}", json={**APPROVE, "call_notes": "Called 11:05, confirmed."})
    log = team.get("/portal/admin/activity").json()
    assert log["page"] == 1 and log["size"] == 25 and log["total"] >= 4
    top = log["items"][0]
    assert (top["label"], top["who_email"], top["about"]) == ("Approved school", TEAM, "Ikeja Community School · SCH-1047")
    assert {"date", "time", "who"} <= set(top)
    assert [e["action"] for e in team.get("/portal/admin/activity?action=school_approved").json()["items"]] == ["school_approved"]
    assert team.get("/portal/admin/activity?q=ikeja").json()["total"] >= 3
    assert team.get("/portal/admin/activity?q=nothing-like-this").json()["total"] == 0
    two = team.get("/portal/admin/activity?size=10&page=99").json()
    assert two["page"] == two["pages"]  # past the end: the last page

    d = team.get(f"/portal/admin/activity/{top['id']}").json()
    assert d["who"] == "Magana Owner" and d["who_role"] == "Owner" and d["reference"] == "SCH-1047"
    assert d["signed_in_from"] == {"browser": "Chrome on a Mac", "place": "Nigeria"}  # never an IP address
    assert {"field": "Status", "before": "Waiting", "after": "Approved"} in d["changes"]
    assert d["call_notes"] == "Called 11:05, confirmed."
    assert d["emails"] == [{"subject": "Ikeja Community School is ready on Magana", "to": "principal", "sent": True}]
    assert d["kept_for"] == "2 years"
    notes = team.get("/portal/admin/activity?action=school_call_noted").json()["items"][0]
    assert {"field": "Call notes", "before": "", "after": "Called 11:05, confirmed."} in \
        team.get(f"/portal/admin/activity/{notes['id']}").json()["changes"]


def test_the_log_is_append_only():
    # No endpoint edits or deletes an entry: the activity routes are read-only.
    for r in app.routes:
        path = getattr(r, "path", "")
        if "activity" in path or "audit" in path:
            assert getattr(r, "methods", set()) <= {"GET", "HEAD"}, (path, r.methods)


def test_entries_are_kept_2_years(fresh):
    team = team_client(fresh)
    with accounts.db() as con:
        con.execute("INSERT INTO audit(school_id, actor, action, target, detail, at) VALUES (NULL, ?, 'team_signed_in', NULL, '{}', ?)",
                    (f"team:{TEAM}", accounts.iso(accounts.now() - timedelta(days=731))))
        old = con.execute("SELECT MAX(id) FROM audit").fetchone()[0]
    team.get("/portal/admin/activity")
    with accounts.db() as con:
        assert con.execute("SELECT COUNT(*) FROM audit WHERE id = ?", (old,)).fetchone()[0] == 0


def test_the_log_never_holds_learner_data_or_codes(fresh):
    sid, principal = approved_school(fresh)
    cls = new_class(principal)
    j = TestClient(app).post("/learner/join", json={"class_code": cls["code"]}, headers=phone()).json()
    [learner] = principal.get(f"/portal/classes/{cls['id']}/learners").json()
    principal.patch(f"/portal/learners/{learner['id']}", json={"name": "Chiamaka Obi"})
    c = TestClient(app)
    make_team("fresh@magana.test", "reviewer", totp_ready=False)
    c.post("/portal/auth/request-code", json={"email": "fresh@magana.test"})
    step = c.post("/portal/auth/verify", json={"email": "fresh@magana.test", "code": last_code(fresh, "fresh@magana.test")}).json()
    key = step["key"].replace(" ", "")
    done = c.post("/portal/auth/totp", json={"code": totp_code("fresh@magana.test", key)}).json()
    team_client(fresh)
    with accounts.db() as con:
        log = json.dumps([dict(r) for r in con.execute("SELECT * FROM audit WHERE action LIKE 'team_%' OR action LIKE 'school_%'")])
    for secret in [key, step["qr"][-40:], *done["backup_codes"], cls["code"], j["token"], "Chiamaka", learner["id"],
                   last_code(fresh, TEAM), last_code(fresh, "fresh@magana.test")]:
        assert secret not in log, secret


def test_setup_shows_a_qr_drawn_here_and_nothing_secret_is_logged_or_cacheable(fresh, caplog):
    caplog.set_level(logging.DEBUG)
    make_team("new@magana.test", "support", totp_ready=False)
    c = TestClient(app)
    c.post("/portal/auth/request-code", json={"email": "new@magana.test"})
    r = c.post("/portal/auth/verify", json={"email": "new@magana.test", "code": last_code(fresh, "new@magana.test")})
    step = r.json()
    assert r.headers["cache-control"] == "no-store"
    assert step["qr"].startswith("data:image/svg+xml") and step["account"] == "new@magana.test"
    assert step["uri"].startswith("otpauth://totp/Magana:new%40magana.test?") and "issuer=Magana" in step["uri"]
    key = step["key"].replace(" ", "")
    r = c.post("/portal/auth/totp", json={"code": totp_code("new@magana.test", key)})
    assert r.headers["cache-control"] == "no-store" and len(r.json()["backup_codes"]) == 8
    logged = "\n".join(rec.getMessage() for rec in caplog.records)
    assert key not in logged and "svg" not in logged and not any(b in logged for b in r.json()["backup_codes"])
