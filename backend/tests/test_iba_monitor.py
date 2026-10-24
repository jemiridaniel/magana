"""Outage fallbacks are marked in the logs, and one alert goes out after 10 minutes."""
import asyncio
import logging

import httpx
import pytest
from fastapi.testclient import TestClient

from app import main, triage
from app.iba_client import IbaClient
from app.iba_monitor import ALERT_AFTER_S, IbaMonitor, monitor
from app.main import app

client = TestClient(app)


class Clock:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


@pytest.fixture
def watched():
    clock, sent = Clock(), []
    return IbaMonitor(clock=clock, notify=sent.append), clock, sent


def failing_iba(status=503) -> IbaClient:
    return IbaClient("http://iba.test", "k", transport=httpx.MockTransport(lambda r: httpx.Response(status)))


def test_alert_threshold_is_ten_minutes():
    assert ALERT_AFTER_S == 600


def test_no_alert_before_ten_minutes(watched, caplog):
    m, clock, sent = watched
    for _ in range(10):  # a failure every minute for 9 minutes
        m.failure("timeout")
        clock.t += 54
    assert sent == [] and not [r for r in caplog.records if r.levelno >= logging.CRITICAL]


def test_one_alert_after_ten_minutes_then_resolved(watched, caplog):
    m, clock, sent = watched
    caplog.set_level(logging.INFO, logger="magana.iba")
    m.failure("connection")
    clock.t += ALERT_AFTER_S + 1
    m.failure("connection")
    m.failure("connection")  # still down: no second alert
    assert len(sent) == 1 and sent[0].startswith("ALERT: Ibà triage service unreachable for 10 minutes")
    assert "last error: connection" in sent[0]
    assert [r.levelno for r in caplog.records].count(logging.CRITICAL) == 1
    assert m.status()["alerting"] is True

    clock.t += 120
    m.success()
    assert sent[1].startswith("RESOLVED: Ibà triage service reachable again after 12.0 minutes")
    assert m.status() == {"reachable": True, "alerting": False}


def test_a_short_blip_resets_the_clock(watched):
    m, clock, sent = watched
    m.failure("timeout")
    clock.t += 500
    m.success()
    clock.t += 500
    m.failure("timeout")
    clock.t += 200
    m.failure("timeout")
    assert sent == []


def test_fallback_answers_are_marked_in_the_logs_without_the_answers(watched, caplog):
    m, clock, sent = watched
    caplog.set_level(logging.INFO, logger="magana.triage")
    r = asyncio.run(triage.assess({"bleeding": True, "fever_days": 17}, failing_iba(503), m))
    assert r.source == "fallback"
    lines = [rec.getMessage() for rec in caplog.records]
    assert "triage source=fallback reason=http_503 priority=emergency" in lines
    assert not any("17" in l or "bleeding" in l for l in lines)
    assert m.status()["last_error"] == "http_503"


def test_not_configured_is_logged_but_is_not_an_outage(watched, caplog):
    m, clock, sent = watched
    caplog.set_level(logging.INFO, logger="magana.triage")
    asyncio.run(triage.assess({}, None, m))
    assert "triage source=fallback reason=not_configured priority=urgent" in [r.getMessage() for r in caplog.records]
    assert m.status()["reachable"] is True


def test_health_reports_ibas_state():
    assert client.get("/health").json()["iba"] == {"configured": False, "reachable": True, "alerting": False}
    monitor.failure("timeout")
    iba = client.get("/health").json()["iba"]
    assert (iba["reachable"], iba["last_error"], iba["alerting"]) == (False, "timeout", False)


def test_background_probe_notices_an_outage(monkeypatch):
    monkeypatch.setenv("IBA_API_URL", "http://iba.test")
    seen = []
    monkeypatch.setattr(main.IbaClient, "from_env", classmethod(lambda cls: failing_iba(502)))
    monkeypatch.setattr(main.iba_monitor, "failure", lambda reason: seen.append(reason))

    async def one_round():
        task = asyncio.create_task(main._probe_iba(3600))
        await asyncio.sleep(0.05)
        task.cancel()

    asyncio.run(one_round())
    assert seen == ["http_502"]
