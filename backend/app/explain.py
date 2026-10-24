"""Explanations of page text in the learner's language.

N-ATLAS will answer here once it is hosted. Until then the preview explainer gives back
the page text itself, so the app can show the Explain screen honestly as a preview.
Whatever an explainer returns goes through safety.guard_explanation before the app speaks
it; page text is data, never instructions (CLAUDE.md rules 1 and 6).
"""
from __future__ import annotations

import os
from typing import Protocol

# About 3,500 tokens: what N-ATLAS's 8,192-token context leaves room for (see the iba-natlas
# serving notes); longer pages are explained part by part.
MAX_SOURCE_CHARS = 12_000


class Explainer(Protocol):
    preview: bool

    def explain(self, source_text: str, question: str | None, lang: str, style: str) -> str: ...


class PreviewExplainer:
    """No model: returns the page text unchanged, so nothing can be added or invented."""

    preview = True

    def explain(self, source_text: str, question: str | None, lang: str, style: str) -> str:
        return source_text


def default_explainer() -> Explainer:
    """MAGANA_EXPLAIN selects the engine; only the preview exists until N-ATLAS is hosted."""
    engine = os.environ.get("MAGANA_EXPLAIN", "preview").lower()
    if engine != "preview":
        raise RuntimeError(f"MAGANA_EXPLAIN={engine!r}: only 'preview' exists until N-ATLAS is hosted")
    return PreviewExplainer()
