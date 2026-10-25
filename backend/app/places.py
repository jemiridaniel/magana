"""Nigeria's 36 states and the FCT, and their 774 local government areas, as codes.

content/places/ng_states_lgas.json (MIT, docs/DATA_SOURCES.md S34): state codes are ISO
3166-2:NG ("NG-LA"), LGA codes Magana's own state-scoped ones ("NG-LA-IKEJA"; the source's
Wikidata IDs repeat for three same-name LGAs, so they aren't codes). Magana stores the codes, never
free text, and every form that asks for a location uses these lists.
"""
from __future__ import annotations

import json
from functools import lru_cache

from .placeholders import content_dir


@lru_cache(maxsize=1)
def data() -> dict:
    raw = json.loads((content_dir() / "places" / "ng_states_lgas.json").read_text(encoding="utf-8"))
    return {"states": raw["states"]}


@lru_cache(maxsize=1)
def _index() -> tuple[dict, dict]:
    states = {s["code"]: s for s in data()["states"]}
    lgas = {l["code"]: (s["code"], l["name"]) for s in data()["states"] for l in s["lgas"]}
    return states, lgas


def valid(state: str, lga: str) -> bool:
    states, lgas = _index()
    return state in states and lga in lgas and lgas[lga][0] == state


def state_name(code: str) -> str | None:
    s = _index()[0].get(code)
    return s["name"] if s else None


def lga_name(code: str) -> str | None:
    l = _index()[1].get(code)
    return l[1] if l else None
