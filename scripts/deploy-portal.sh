#!/usr/bin/env bash
# Build the teacher portal for https://teachers.<domain>/ and copy it to the server, where
# Caddy serves it behind a login (deploy/Caddyfile). The built files carry the API key, so it is read from the
# server's .env here, never printed, and the local build
# is deleted afterwards. Uses ~/.magana/aws.env (MAGANA_HOST, MAGANA_SSH_KEY).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_HOST:?set MAGANA_HOST in ~/.magana/aws.env}"
KEY="${MAGANA_SSH_KEY/#\~/$HOME}"
remote() { ssh -i "$KEY" "ubuntu@$MAGANA_HOST" "$@"; }
env_value() { remote "grep -m1 '^$1=' ~/srv/magana/.env | cut -d= -f2-"; }

DOMAIN="$(env_value MAGANA_DOMAIN)"
cd "$ROOT/portal"
rm -rf out
PORTAL_EXPORT=1 \
NEXT_PUBLIC_API_URL="https://api.$DOMAIN" \
NEXT_PUBLIC_API_KEY="$(env_value MAGANA_API_KEY)" \
  npx next build >/dev/null
remote 'mkdir -p ~/srv/magana/deploy/teachers'
rsync -az --delete -e "ssh -i $KEY" out/ "ubuntu@$MAGANA_HOST:srv/magana/deploy/teachers/"
rm -rf out  # the build carries the keys
echo "Teacher portal at https://teachers.$DOMAIN/ (sign in with an invited email)"
