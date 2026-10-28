#!/usr/bin/env bash
# Start ~/.magana/space.env, the test-phase server's settings on this Mac (docs/DEPLOY.md, step 5).
# Makes the two keys this Mac can make itself, MAGANA_CODE_KEY and MAGANA_WEB_API_KEY, and leaves a
# line for each value you paste from a dashboard. Never prints a value; the file is only yours (600).
#   scripts/space-env-init.sh            # create it (refuses to overwrite)
#   scripts/space-env-init.sh --github   # copy MAGANA_WEB_API_KEY, RESEND_API_KEY and HF_DEPLOY_TOKEN to GitHub secrets
set -euo pipefail
F="${MAGANA_SPACE_ENV:-$HOME/.magana/space.env}"
get() { grep -E "^$1=" "$F" | head -1 | cut -d= -f2-; }

if [ "${1:-}" = "--github" ]; then
  cd "$(dirname "$0")/.."
  export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel)}"
  for k in MAGANA_WEB_API_KEY RESEND_API_KEY HF_DEPLOY_TOKEN; do
    v=$(get "$k"); [ -n "$v" ] || { echo "$k is empty in $F"; exit 1; }
    printf '%s' "$v" | gh secret set "$k" >/dev/null && echo "GitHub secret $k set"
  done
  space=$(get HF_SPACE); [ -n "$space" ] && gh variable set HF_SPACE --body "$space" >/dev/null && echo "GitHub variable HF_SPACE = $space"
  exit 0
fi

[ -e "$F" ] && { echo "$F already exists: edit it, or move it away first"; exit 1; }
mkdir -p "$(dirname "$F")" && umask 077
cat > "$F" <<ENV
# Magana test-phase server (docs/DEPLOY.md). Never commit, share or paste this file.
HF_SPACE=<your-hf-username>/magana-api
HF_DEPLOY_TOKEN=
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
