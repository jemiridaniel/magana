"""Change a public setting everywhere at once (config/public.json is the one source).

    python3 scripts/set_public_config.py support_email support@magana.ng

Replaces the old value with the new one in every tracked text file (code, docs, the website
and portal), then writes config/public.json. FINDINGS.md is history and is left alone.
backend/tests/test_public_config.py fails if any copy disagrees afterwards.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "public.json"
SKIP = {"docs/FINDINGS.md", "config/public.json"}
TEXT = {".md", ".dart", ".ts", ".tsx", ".js", ".json", ".html", ".sh", ".py", ".yml", ".yaml", ".arb", ".txt", ".css"}


def tracked_text_files() -> list[Path]:
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [ROOT / p for p in out.splitlines() if p not in SKIP and Path(p).suffix in TEXT]


def main(key: str, value: str) -> None:
    config = json.loads(CONFIG.read_text())
    if key not in config or key.startswith("_"):
        sys.exit(f"unknown setting {key!r}; known: {[k for k in config if not k.startswith('_')]}")
    old = config[key]
    if key == "domain":
        sys.exit("the domain also lives in the server's Caddyfile (deploy/server/Caddyfile), its DNS record "
                 "and GitHub's MAGANA_DOMAIN variable: change it with docs/DEPLOY.md, not here")
    changed = []
    for path in tracked_text_files():
        text = path.read_text(encoding="utf-8")
        if old in text:
            path.write_text(text.replace(old, value), encoding="utf-8")
            changed.append(path.relative_to(ROOT))
    config[key] = value
    CONFIG.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    print(f"{key}: {old} -> {value} in {len(changed)} files:")
    for p in changed:
        print(f"  {p}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
