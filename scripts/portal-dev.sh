#!/usr/bin/env bash
# Run the teacher portal locally on http://localhost:3000.
#
#   scripts/portal-dev.sh             # sample data, no backend (its endpoints don't exist yet)
#   scripts/portal-dev.sh --backend   # call the local backend (scripts/dev.sh, port 8765) with
#                                     # the dev key from backend/.env
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/portal"
[ -d node_modules ] || npm install
if [ "${1:-}" = "--backend" ]; then
  KEY="$(grep '^MAGANA_API_KEY=' "$ROOT/backend/.env" 2>/dev/null | cut -d= -f2-)"
  [ -n "$KEY" ] || { echo "no MAGANA_API_KEY in backend/.env: run scripts/dev.sh once first" >&2; exit 1; }
  export NEXT_PUBLIC_API_URL="http://localhost:${MAGANA_DEV_PORT:-8765}"
  export NEXT_PUBLIC_API_KEY="$KEY"
  echo "portal -> $NEXT_PUBLIC_API_URL (with the dev key). Uploads and registers will fail until"
  echo "the backend has /materials and /sessions; without --backend the portal uses sample data."
fi
exec npm run dev -- --port 3000
