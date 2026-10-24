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
