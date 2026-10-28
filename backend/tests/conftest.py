import os

import pytest

# MAGANA_TEST_DATABASE_URL=postgresql://… runs every test on Postgres, as the test-phase server does
# (docs/INFRA.md): each test's MAGANA_DATA_DIR gets its own schema, as it gets its own SQLite file.
if os.environ.get("MAGANA_TEST_DATABASE_URL"):
    os.environ["DATABASE_URL"] = os.environ["MAGANA_TEST_DATABASE_URL"]
    os.environ["MAGANA_DB_SCHEMA_PER_DATA_DIR"] = "1"
else:
    os.environ.pop("DATABASE_URL", None)



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
