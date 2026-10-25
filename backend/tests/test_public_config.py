"""Every copy of the support address matches config/public.json (scripts/set_public_config.py)."""
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "config" / "public.json").read_text())
# Our own addresses (anything at magana.ng, or Magana's Gmail); FINDINGS.md is history.
ADDRESS = re.compile(r"[\w.+-]+@magana\.ng\b|[\w.+-]*magana[\w.+-]*@gmail\.com", re.I)


# Built, downloaded or generated: not ours to check. (No git here: CI runs this in the
# production image, which has none.)
SKIP_DIRS = {".git", "node_modules", ".venv", "build", "out", ".next", ".dart_tool", "test-results", "__pycache__"}


def tracked(*suffixes):
    found = []
    for dirpath, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".") or d in (".github",)]
        found += [Path(dirpath) / n for n in names if n.endswith(suffixes)]
    return [p for p in found if p.relative_to(ROOT).as_posix() != "docs/FINDINGS.md"]


def test_every_support_address_is_the_configured_one():
    seen = {}
    for path in tracked(".md", ".dart", ".ts", ".tsx", ".html", ".json", ".arb"):
        if not path.exists():
            continue
        for found in ADDRESS.findall(path.read_text(encoding="utf-8", errors="ignore")):
            seen.setdefault(found, []).append(path.relative_to(ROOT).as_posix())
    assert set(seen) == {CONFIG["support_email"]}, seen


def test_the_address_reaches_the_app_portal_and_docs():
    email = CONFIG["support_email"]
    for rel in ("app/lib/screens/about.dart", "portal/lib/site.ts", "website/lib/site.ts", "docs/ACCESSIBILITY.md", "docs/PRIVACY.md", "docs/TESTER_INSTALL.md"):
        assert email in (ROOT / rel).read_text(encoding="utf-8"), rel
