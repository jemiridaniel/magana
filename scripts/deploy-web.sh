#!/usr/bin/env bash
# Build the tester PWA and copy it to the server, where Caddy serves it at https://app.<domain>/.
# Normally not needed: every push to main deploys it (.github/workflows/ci.yml).
# Uses ~/.magana/app.env (MAGANA_API = https://<server>, MAGANA_API_KEY) and ~/.magana/aws.env.
# Hold until the AWS server is up (docs/DEPLOY_AWS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-web.sh"
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_HOST:?set MAGANA_HOST in ~/.magana/aws.env}"
KEY="${MAGANA_SSH_KEY/#\~/$HOME}"
ssh -i "$KEY" "ubuntu@$MAGANA_HOST" 'mkdir -p ~/srv/magana/deploy/web'
rsync -az --delete -e "ssh -i $KEY" "$ROOT/app/build/web/" "ubuntu@$MAGANA_HOST:srv/magana/deploy/web/"
echo "PWA at https://app.$(python3 -c 'import json;print(json.load(open("'"$ROOT"'/config/public.json"))["domain"])')/ (Caddy serves the new files straight away)"
