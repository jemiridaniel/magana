"""Every copy of the support address matches config/public.json (scripts/set_public_config.py)."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "config" / "public.json").read_text())
# Our own addresses (anything at magana.ng, or Magana's Gmail); FINDINGS.md is history.
ADDRESS = re.compile(r"[\w.+-]+@magana\.ng\b|[\w.+-]*magana[\w.+-]*@gmail\.com", re.I)


def tracked(*suffixes):
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [ROOT / p for p in out.splitlines() if p.endswith(suffixes) and p != "docs/FINDINGS.md"]


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
    for rel in ("app/lib/screens/about.dart", "portal/lib/site.ts", "docs/PRIVACY.md", "docs/TESTER_INSTALL.md"):
        assert email in (ROOT / rel).read_text(encoding="utf-8"), rel
