"""Checks a built app (APK, IPA or the PWA folder) for real secrets before it is shared.

    backend/.venv/bin/python scripts/check_bundle_secrets.py app/build/ios/ipa/Magana.ipa app/build/web ...

Allowed: the app key (MAGANA_API_KEY / MAGANA_WEB_API_KEY). It is an app identifier, not a
secret, and the server's rate limits and daily caps protect it (backend/app/ratelimit.py).
Refused (exit 1), reported by name only, never by value:
- patterns: AWS access keys and secret keys, private keys (PEM), Hugging Face, OpenAI-style,
  GitHub, Google API, Slack and Meta (WhatsApp) tokens;
- the names of the server's secrets (a sign a value was copied with them): AWS_SECRET_ACCESS_KEY,
  IBA_API_KEY, EXPLAIN_API_KEY, WHATSAPP_ACCESS_TOKEN, WHATSAPP_APP_SECRET, MAGANA_CODE_KEY, HF_TOKEN;
- the actual secret values kept on this Mac: the signing passwords (~/.magana/key.properties),
  the portal login (~/.magana/portal-login.txt), AWS secret keys (~/.aws/credentials), and any
  value in an env file passed with --env (for example a copy of the server's .env).
"""
from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

HOME = Path.home()
PATTERNS = {
    "AWS access key": re.compile(rb"\b(AKIA|ASIA)[0-9A-Z]{16}\b"),
    "AWS secret key": re.compile(rb"aws_secret_access_key\s*[=:]\s*[A-Za-z0-9/+=]{40}", re.I),
    "private key": re.compile(rb"-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "Hugging Face token": re.compile(rb"\bhf_[A-Za-z0-9]{30,}\b"),
    "OpenAI-style key": re.compile(rb"\bsk-[A-Za-z0-9_-]{32,}\b"),
    "GitHub token": re.compile(rb"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    "Google API key": re.compile(rb"\bAIza[0-9A-Za-z_-]{35}\b"),
    "Slack token": re.compile(rb"\bxox[abpors]-[A-Za-z0-9-]{10,}\b"),
    "Meta access token": re.compile(rb"\bEAA[A-Za-z0-9]{100,}\b"),
}
SECRET_NAMES = [b"AWS_SECRET_ACCESS_KEY", b"IBA_API_KEY", b"EXPLAIN_API_KEY", b"WHATSAPP_ACCESS_TOKEN",
                b"WHATSAPP_APP_SECRET", b"MAGANA_CODE_KEY", b"HF_TOKEN"]
APP_KEYS = ("MAGANA_API_KEY", "MAGANA_WEB_API_KEY")


def env_values(path: Path, skip: tuple[str, ...] = ()) -> dict[str, str]:
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(errors="ignore").splitlines():
        m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.]*)\s*[=:]\s*(.+?)\s*$", line)
        if m and not line.lstrip().startswith("#"):
            name, value = m.group(1), m.group(2).strip().strip("'\"")
            if name not in skip:
                out[name] = value
    return out


def known_secrets(extra_env: list[Path]) -> dict[str, bytes]:
    """name -> value, for values long enough not to match by chance (8+ characters)."""
    found: dict[str, str] = {}
    for k, v in env_values(HOME / ".magana" / "key.properties").items():
        if "password" in k.lower():
            found[f"signing {k}"] = v
    login = HOME / ".magana" / "portal-login.txt"
    if login.exists():
        for i, line in enumerate(login.read_text(errors="ignore").split()):
            found[f"portal login part {i + 1}"] = line
    for k, v in env_values(HOME / ".aws" / "credentials").items():
        if "secret" in k.lower() or "session_token" in k.lower():
            found[f"~/.aws/credentials {k}"] = v
    for env in extra_env:
        for k, v in env_values(env, skip=APP_KEYS + ("MAGANA_API", "MAGANA_DOMAIN", "MAGANA_HOST")).items():
            found[f"{env.name} {k}"] = v
    return {k: v.encode() for k, v in found.items() if len(v) >= 8}


def files_in(target: Path):
    if target.is_dir():
        for p in target.rglob("*"):
            if p.is_file():
                yield str(p.relative_to(target)), p.read_bytes()
    elif zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as z:
            for name in z.namelist():
                if not name.endswith("/"):
                    yield name, z.read(name)
    else:
        yield target.name, target.read_bytes()


def check(target: Path, secrets: dict[str, bytes]) -> list[str]:
    problems = []
    for name, data in files_in(target):
        for label, rx in PATTERNS.items():
            if rx.search(data):
                problems.append(f"{label} in {name}")
        for s in SECRET_NAMES:
            if s in data:
                problems.append(f"the name {s.decode()} in {name}")
        for label, value in secrets.items():
            if value in data:
                problems.append(f"{label} in {name}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("targets", nargs="+", type=Path)
    ap.add_argument("--env", action="append", type=Path, default=[], help="an env file whose values are secrets")
    a = ap.parse_args()
    secrets = known_secrets(a.env)
    bad = False
    for t in a.targets:
        problems = check(t, secrets)
        bad = bad or bool(problems)
        print(f"{t}: " + ("no secrets found" if not problems else "REFUSED"))
        for p in sorted(set(problems)):
            print(f"  - {p}")
    print(f"(checked {len(PATTERNS)} patterns, {len(SECRET_NAMES)} secret names, {len(secrets)} known secret values)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
