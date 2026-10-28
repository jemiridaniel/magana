#!/usr/bin/env bash
# The test-phase server's settings (docs/DEPLOY.md). Never prints a value.
#   scripts/server-env.sh            create ~/.magana/server.env (refuses to overwrite) with the two
#                                    keys made here, MAGANA_CODE_KEY and MAGANA_WEB_API_KEY
#   scripts/server-env.sh --check    which settings are filled in (names only)
#   scripts/server-env.sh --push     send them to the server as /etc/magana/magana.env (root only),
#                                    restart the API with them, and keep an encrypted copy in the
#                                    private backups repository (settings/server.env.age)
#   scripts/server-env.sh --github   GitHub secrets: MAGANA_WEB_API_KEY (the PWA and portal),
#                                    RESEND_API_KEY (alert emails), DATABASE_URL (the daily backup)
# MAGANA_API_KEY, the key in the testers' APK and IPA, is read from ~/.magana/app.env, so installed
# apps keep working. On the server itself, the same file can be edited with
# "sudo nano /etc/magana/magana.env" followed by "sudo magana-deploy --restart".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="${MAGANA_SERVER_ENV:-$HOME/.magana/server.env}"
APP_ENV="${MAGANA_APP_ENV:-$HOME/.magana/app.env}"
HOST="${MAGANA_SERVER:-magana-api}"  # the server's Tailscale name (docs/INFRA.md)
KEY="${MAGANA_SSH_KEY:-$HOME/.ssh/magana_oracle.key}"
BACKUPS="${MAGANA_BACKUP_REPO:-jemiridaniel/magana-backups}"
REQUIRED="DATABASE_URL MAGANA_CODE_KEY MAGANA_API_KEY MAGANA_WEB_API_KEY RESEND_API_KEY RESEND_WEBHOOK_SECRET"

# The settings file the server reads: every filled line of server.env, the app key, and the fixed
# (not secret) settings unless server.env sets them.
compose() {
  python3 - "$F" "$APP_ENV" <<'PY'
import sys
def read(path):
    out = {}
    try:
        lines = open(path).read().splitlines()
    except FileNotFoundError:
        return out
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        if k.startswith("export "):
            k = k[len("export "):].strip()
        v = v.strip().strip('"').strip("'")
        if v:
            out[k] = v
    return out
env = read(sys.argv[1])
env.setdefault("MAGANA_API_KEY", read(sys.argv[2]).get("MAGANA_API_KEY", ""))
fixed = {
    "MAGANA_ENV": "production",
    "MAGANA_MAIL": "resend",
    "MAIL_FROM": "Magana for Teachers <no-reply@magana.ng>",
    "MAGANA_PORTAL_URL": "https://teachers.magana.ng",
    "MAGANA_CORS_ORIGIN_REGEX": r"https://(app|teachers|www)\.magana\.ng|https://magana\.ng",
    "EXPLAIN_ENGINE": "stub",
}
for k, v in fixed.items():
    env.setdefault(k, v)
for k, v in env.items():
    if v and "\n" not in v:
        print(f"{k}={v}")
PY
}
filled() { compose | grep -q "^$1="; }

case "${1:-}" in
  --check)
    for k in $REQUIRED WHATSAPP_TOKEN WHATSAPP_APP_SECRET WHATSAPP_VERIFY_TOKEN WHATSAPP_PHONE_NUMBER_ID \
             EXPLAIN_URL EXPLAIN_API_KEY IBA_API_URL IBA_API_KEY RATE_EXEMPT_DEVICES; do
      if filled "$k"; then echo "  set      $k"; else echo "  missing  $k"; fi
    done
    exit 0 ;;

  --push)
    [ -f "$F" ] || { echo "no $F yet: run scripts/server-env.sh first"; exit 1; }
    for k in MAGANA_CODE_KEY MAGANA_API_KEY MAGANA_WEB_API_KEY; do filled "$k" || { echo "$k is empty: refusing"; exit 1; }; done
    missing=""; for k in $REQUIRED; do filled "$k" || missing="$missing $k"; done
    [ -z "$missing" ] || echo "not filled in yet (the server runs without them):$missing"
    compose | ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$HOST" \
      'sudo sh -c "umask 077; mkdir -p /etc/magana; cat > /etc/magana/magana.env.new && mv /etc/magana/magana.env.new /etc/magana/magana.env" && echo "settings saved on the server" && (sudo magana-deploy --restart 2>/dev/null || echo "no live server yet: the next deploy uses them")'
    # An encrypted copy off the server (only the backup key in your password manager opens it):
    # without MAGANA_CODE_KEY, class codes, authenticator keys and proofs can't be opened again.
    if command -v age >/dev/null; then
      export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel)}"
      blob=$(compose | age -r "$(cat "$ROOT/deploy/backup/age-recipient.txt")" | base64 | tr -d '\n')
      sha=$(gh api "repos/$BACKUPS/contents/settings/server.env.age" --jq .sha 2>/dev/null || true)
      gh api -X PUT "repos/$BACKUPS/contents/settings/server.env.age" -f message="Settings, encrypted" \
        -f content="$blob" ${sha:+-f sha="$sha"} >/dev/null 2>&1 && echo "encrypted copy saved in $BACKUPS" \
        || echo "no encrypted copy made: create the private repository $BACKUPS first (docs/DEPLOY.md)"
    else
      echo "age isn't installed (brew install age): no encrypted copy made"
    fi
    exit 0 ;;

  --github)
    export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel)}"
    cd "$ROOT"
    for k in MAGANA_WEB_API_KEY RESEND_API_KEY DATABASE_URL; do
      v=$(compose | grep "^$k=" | head -1 | cut -d= -f2- || true)
      if [ -n "$v" ]; then printf '%s' "$v" | gh secret set "$k" >/dev/null && echo "GitHub secret $k set"
      else echo "$k is empty in $F: not set"; fi
    done
    exit 0 ;;
esac

[ -e "$F" ] && { echo "$F already exists: edit it, or move it away first"; exit 1; }
mkdir -p "$(dirname "$F")" && umask 077
cat > "$F" <<ENV
# Magana test-phase server (docs/DEPLOY.md). Never commit, share or paste this file.
# After editing: scripts/server-env.sh --push (and --github for the three CI secrets).
DATABASE_URL=
MAGANA_CODE_KEY=$(openssl rand -hex 32)
MAGANA_WEB_API_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
RESEND_API_KEY=
RESEND_WEBHOOK_SECRET=
# Optional (leave empty to keep off):
WHATSAPP_TOKEN=
WHATSAPP_APP_SECRET=
WHATSAPP_VERIFY_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
EXPLAIN_ENGINE=
EXPLAIN_URL=
EXPLAIN_API_KEY=
ENV
chmod 600 "$F"
echo "Created $F with MAGANA_CODE_KEY and MAGANA_WEB_API_KEY filled in. Open it in a text editor to paste the rest."
