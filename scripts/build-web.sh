#!/usr/bin/env bash
# Build the PWA for testers: served at https://<server>/app/ by Caddy, talking to the API on
# the same server. Writes app/build/web (and fills in the service worker's file list).
#   scripts/build-web.sh                   # uses MAGANA_API and MAGANA_API_KEY from ~/.magana/app.env
#   MAGANA_API=http://localhost:8765 MAGANA_API_KEY=... scripts/build-web.sh   # local test
# The key ends up in the page, readable by anyone: the backend's rate limits are what
# protect it (backend/app/ratelimit.py).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${MAGANA_API:-}" ] || [ -z "${MAGANA_API_KEY:-}" ]; then
  # shellcheck disable=SC1090
  source "${MAGANA_APP_ENV:-$HOME/.magana/app.env}"
fi
: "${MAGANA_API:?set MAGANA_API}" "${MAGANA_API_KEY:?set MAGANA_API_KEY}"
BASE="${MAGANA_WEB_BASE:-/app/}"
export PATH="$HOME/development/flutter/bin:$PATH"
cd "$ROOT/app"

# Everything from our own server (no CDN), so the app also loads offline.
flutter build web --release --base-href "$BASE" --no-web-resources-cdn --no-source-maps \
  --dart-define=MAGANA_API="$MAGANA_API" --dart-define=MAGANA_API_KEY="$MAGANA_API_KEY"

# The service worker's precache list: the app shell and assets. The renderer is not in it:
# each browser loads one of several CanvasKit builds (about 5 to 7 MB), and the service
# worker keeps whichever one it fetched on the first, online visit.
cd build/web
python3 - "$BASE" <<'PY'
import hashlib, json, os, sys
files = []
for dirpath, _, names in os.walk("."):
    for name in names:
        path = os.path.join(dirpath, name)[2:]
        if (name in ("magana_sw.js", "flutter_service_worker.js", ".DS_Store", ".last_build_id", "NOTICES")
                or path.startswith("canvaskit/") or name.endswith(".symbols")):
            continue
        files.append(path)
files.sort()
digest = hashlib.sha256()
for f in files:
    digest.update(f.encode()); digest.update(open(f, "rb").read())
sw = open("magana_sw.js").read()
sw = sw.replace("const VERSION = 'dev';", f"const VERSION = {digest.hexdigest()[:16]!r};")
sw = sw.replace("[/*__MAGANA_PRECACHE__*/]", json.dumps(["./"] + files, indent=1))
assert "__MAGANA_PRECACHE__" not in sw and "'dev'" not in sw, "service worker template changed"
open("magana_sw.js", "w").write(sw)
size = sum(os.path.getsize(f) for f in files)
print(f"precache: {len(files)} files, {size / 1048576:.1f} MB, version {digest.hexdigest()[:16]}")
PY
echo "PWA ready in $(pwd) (serve it at $BASE)"
