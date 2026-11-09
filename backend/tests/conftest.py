import os
import tempfile

import pytest

# Tests that don't set their own MAGANA_DATA_DIR (most set tmp_path) share one per test process,
# never backend/data/: under pytest-xdist (-n auto) each worker then has its own SQLite file
# and, on Postgres, its own schema (database._schema hashes the data dir).
os.environ["MAGANA_DATA_DIR"] = tempfile.mkdtemp(prefix="magana-tests-")

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


@pytest.fixture
def natlas_test_prompts(monkeypatch, tmp_path):
    """Hausa, Yorùbá and Igbo switched on with test prompts, for tests of the checks around the
    model (their real prompts are placeholders until native speakers write them, which keeps
    them off: test_natlas_guard.py)."""
    from llm import natlas_guard as g

    monkeypatch.setenv("NATLAS_ENABLED_LANGS", "en,ha,yo,ig")
    (tmp_path / "en.txt").write_text((g.PROMPTS / "en.txt").read_text(encoding="utf-8"), encoding="utf-8")
    for lang in ("ha", "yo", "ig"):
        (tmp_path / f"{lang}.txt").write_text(
            f"# version: test-{lang}\n# status: test\nTest rules for {lang}. Copy every marker exactly once.\n",
            encoding="utf-8")
    monkeypatch.setattr(g, "PROMPTS", tmp_path)
    g.prompt.cache_clear()
    yield
    g.prompt.cache_clear()
