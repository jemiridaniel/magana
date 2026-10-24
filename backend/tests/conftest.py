import pytest


@pytest.fixture(autouse=True)
def no_real_iba(monkeypatch: pytest.MonkeyPatch) -> None:
    """Tests never reach a real Ibà service; test_triage.py injects a fake one."""
    monkeypatch.delenv("IBA_API_URL", raising=False)
    monkeypatch.delenv("IBA_API_KEY", raising=False)
