#!/usr/bin/env python3
"""Set the Hugging Face Space's secrets and variables from files on this Mac (docs/DEPLOY.md, step 6).

    python3 scripts/space_secrets.py            # set them all
    python3 scripts/space_secrets.py --check    # only list which are set locally (names, never values)

Reads (both outside the repository, never committed):
- ~/.magana/space.env: HF_SPACE, HF_DEPLOY_TOKEN, DATABASE_URL, MAGANA_CODE_KEY, MAGANA_WEB_API_KEY,
  RESEND_API_KEY, RESEND_WEBHOOK_SECRET, and any optional ones below;
- ~/.magana/app.env: MAGANA_API_KEY, the key already built into the testers' APK and IPA, so
  installed apps keep working.
Values are sent to Hugging Face's API over HTTPS and never printed. Secrets are hidden in the Space's
settings; variables (not secret) are visible there.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

SPACE_ENV = Path(os.environ.get("MAGANA_SPACE_ENV", Path.home() / ".magana" / "space.env"))
APP_ENV = Path(os.environ.get("MAGANA_APP_ENV", Path.home() / ".magana" / "app.env"))

REQUIRED_SECRETS = ["DATABASE_URL", "MAGANA_CODE_KEY", "MAGANA_API_KEY", "MAGANA_WEB_API_KEY",
                    "RESEND_API_KEY", "RESEND_WEBHOOK_SECRET"]
OPTIONAL_SECRETS = ["WHATSAPP_TOKEN", "WHATSAPP_APP_SECRET", "WHATSAPP_VERIFY_TOKEN", "WHATSAPP_PHONE_NUMBER_ID",
                    "EXPLAIN_API_KEY", "EXPLAIN_URL", "IBA_API_URL", "IBA_API_KEY", "MAGANA_ALERT_WEBHOOK_URL",
                    "AZURE_VISION_ENDPOINT", "AZURE_VISION_KEY", "RATE_EXEMPT_DEVICES",
                    # Rotating a key (docs/DEPLOY.md, "Later"): the old one keeps working until the date.
                    "MAGANA_API_KEY_PREVIOUS", "MAGANA_API_KEY_PREVIOUS_UNTIL",
                    "MAGANA_WEB_API_KEY_PREVIOUS", "MAGANA_WEB_API_KEY_PREVIOUS_UNTIL"]
VARIABLES = {
    "MAGANA_ENV": "production",
    "MAGANA_MAIL": "resend",
    "MAIL_FROM": "Magana for Teachers <no-reply@magana.ng>",
    "MAGANA_PORTAL_URL": "https://teachers.magana.ng",
    "MAGANA_CORS_ORIGIN_REGEX": r"https://(app|teachers|www)\.magana\.ng|https://magana\.ng",
    "EXPLAIN_ENGINE": "stub",
}


def read_env(path: Path) -> dict[str, str]:
    out = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        if k.startswith("export "):
            k = k[len("export "):].strip()
        out[k] = v.strip().strip('"').strip("'")
    return out


def call(space: str, token: str, kind: str, key: str, value: str, description: str = "") -> int:
    req = urllib.request.Request(
        f"https://huggingface.co/api/spaces/{space}/{kind}",
        data=json.dumps({"key": key, "value": value, "description": description}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def main() -> int:
    env = read_env(SPACE_ENV)
    app = read_env(APP_ENV)
    if "MAGANA_API_KEY" in app:
        env.setdefault("MAGANA_API_KEY", app["MAGANA_API_KEY"])
    if env.get("EXPLAIN_ENGINE"):
        VARIABLES["EXPLAIN_ENGINE"] = env["EXPLAIN_ENGINE"]
    missing = [k for k in ["HF_SPACE", "HF_DEPLOY_TOKEN", *REQUIRED_SECRETS] if not env.get(k)]
    for k in ["HF_SPACE", "HF_DEPLOY_TOKEN", *REQUIRED_SECRETS, *OPTIONAL_SECRETS]:
        print(f"  {'set    ' if env.get(k) else 'missing'}  {k}")
    if "<" in env.get("HF_SPACE", ""):
        missing.append("HF_SPACE (still the example)")
    if missing:
        print(f"\nMissing in {SPACE_ENV} (or {APP_ENV}): {', '.join(missing)}")
        return 1
    if "--check" in sys.argv:
        return 0
    space, token = env["HF_SPACE"], env["HF_DEPLOY_TOKEN"]
    failed = []
    for k in REQUIRED_SECRETS + [k for k in OPTIONAL_SECRETS if env.get(k)]:
        status = call(space, token, "secrets", k, env[k])
        print(f"secret   {k}: {'ok' if status < 300 else status}")
        if status >= 300:
            failed.append(k)
    for k, v in VARIABLES.items():
        status = call(space, token, "variables", k, v)
        print(f"variable {k}: {'ok' if status < 300 else status}")
        if status >= 300:
            failed.append(k)
    if failed:
        print("\nNot set: " + ", ".join(failed) + ". Check that HF_DEPLOY_TOKEN has write access to the Space.")
        return 1
    print("\nDone. The Space restarts with them (Settings → Variables and secrets).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
