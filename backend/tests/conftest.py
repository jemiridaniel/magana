import pytest


@pytest.fixture(autouse=True)
def no_real_iba(monkeypatch: pytest.MonkeyPatch) -> None:
    """Tests never reach a real Ibà service; test_triage.py injects a fake one."""
    monkeypatch.delenv("IBA_API_URL", raising=False)
    monkeypatch.delenv("IBA_API_KEY", raising=False)


@pytest.fixture(autouse=True)
def fresh_iba_monitor():
    """Each test starts with Ibà healthy (the monitor is process-wide)."""
    from app.iba_monitor import monitor

    monitor.success()
    yield
    monitor.success()


@pytest.fixture(autouse=True)
def fresh_rate_limits(monkeypatch):
    """Every test starts with empty buckets and generous limits; test_ratelimit.py sets its own."""
    from app import ratelimit

    monkeypatch.setattr(ratelimit, "limiter", ratelimit.RateLimiter())
    for name in ("RATE_IP_PER_MIN", "RATE_DEVICE_PER_MIN", "RATE_HEAVY_IP_PER_MIN", "RATE_HEAVY_DEVICE_PER_MIN",
                 "RATE_HEAVY_IP_PER_DAY", "RATE_HEAVY_DEVICE_PER_DAY"):
        monkeypatch.setenv(name, "100000")
