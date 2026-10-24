"""Explain: tier rules, the preview engine, and the guard on every explanation."""
from fastapi.testclient import TestClient

from app import explain
from app.main import app, get_explainer

client = TestClient(app)
LABEL = "Paracetamol 500 mg tablets. Take 2 tablets every 4 to 6 hours."


def post(body: dict, tier: str = "standard", **headers):
    return client.post("/explain", json=body, headers={"X-Magana-Tier": tier, **headers})


def test_preview_gives_back_the_page_text_unchanged():
    body = post({"source_text": LABEL, "lang": "ha"}).json()
    assert body == {"code": "explain_preview", "explanation": LABEL, "read_instead": None, "preview": True}


class Inventing:
    preview = False

    def explain(self, source_text, question, lang, style):
        return "Take 3 tablets every 4 hours."  # 3 is not on the page


def test_an_explanation_with_a_number_not_on_the_page_is_never_given():
    app.dependency_overrides[get_explainer] = lambda: Inventing()
    try:
        body = post({"source_text": LABEL, "question": "How many?"}).json()
    finally:
        app.dependency_overrides.clear()
    assert body == {"code": "numbers_unconfirmed", "explanation": None, "read_instead": LABEL, "preview": False}


def test_guided_learners_may_use_explain_but_classroom_may_not():
    assert post({"source_text": LABEL}, tier="guided", **{"X-Magana-Guardian-Consent": "yes"}).status_code == 200
    r = post({"source_text": LABEL}, tier="classroom", **{"X-Magana-Teacher-Session": "yes"})
    assert r.status_code == 403


def test_empty_or_too_long_source_is_refused():
    assert post({"source_text": "  "}).json()["detail"] == {"code": "explain_bad_source"}
    assert post({"source_text": "a" * (explain.MAX_SOURCE_CHARS + 1)}).status_code == 400


def test_unknown_language_or_style_is_refused():
    assert post({"source_text": LABEL, "lang": "fr"}).status_code == 422
    assert post({"source_text": LABEL, "style": "poem"}).status_code == 422


def test_only_the_preview_engine_exists_until_natlas_is_hosted(monkeypatch):
    assert explain.default_explainer().preview is True
    monkeypatch.setenv("MAGANA_EXPLAIN", "natlas")
    import pytest
    with pytest.raises(RuntimeError):
        explain.default_explainer()
