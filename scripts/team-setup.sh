#!/usr/bin/env bash
# Make the first Magana admin (or reset an authenticator) in the test-phase database, from this
# Mac (docs/DEPLOY.md, step 8). The database is outside the server, so this runs here, not on it.
#   scripts/team-setup.sh --email you@example.com --name "Your Name"
#   scripts/team-setup.sh --email you@example.com --reset-authenticator
# Reads DATABASE_URL and MAGANA_CODE_KEY from ~/.magana/space.env: the same values as the Space's
# secrets (the key seals the authenticator, so it must match the server's).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "${MAGANA_SPACE_ENV:-$HOME/.magana/space.env}"
: "${DATABASE_URL:?set DATABASE_URL in ~/.magana/space.env}"
: "${MAGANA_CODE_KEY:?set MAGANA_CODE_KEY in ~/.magana/space.env (the same as the Space secret)}"
cd "$ROOT/backend"
DATABASE_URL="$DATABASE_URL" MAGANA_CODE_KEY="$MAGANA_CODE_KEY" MAGANA_ENV=production \
  MAGANA_PORTAL_URL="${MAGANA_PORTAL_URL:-https://teachers.magana.ng}" \
  .venv/bin/python -m app.team_setup "$@"
