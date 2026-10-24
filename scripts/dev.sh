#!/usr/bin/env bash
# Run Magana locally: the backend (with the dev API key from backend/.env) and the app on
# the Android emulator or in Chrome, with the same key and the right backend address.
#
#   scripts/dev.sh             # emulator if one is running or can be started, else Chrome
#   scripts/dev.sh emulator    # Android emulator: backend at http://10.0.2.2:8765
#   scripts/dev.sh chrome      # Chrome: backend at http://localhost:8765, app on :5173
#
# Ctrl+C (or q in Flutter) stops the app and the backend.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${MAGANA_DEV_PORT:-8765}"          # 8000 is Ibà's in docker; 8010 is taken on this Mac
AVD="${MAGANA_AVD:-Medium_Phone_API_36.1}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
export PATH="$HOME/development/flutter/bin:$PATH"
ENV_FILE="$ROOT/backend/.env"

# ---- backend/.env with a dev key (created once; never committed)
if [ ! -f "$ENV_FILE" ]; then
  cp "$ROOT/backend/.env.example" "$ENV_FILE"
  # No local Ibà: the built-in danger-sign rules answer, without retrying a server that isn't there.
  sed -i '' 's|^IBA_API_URL=.*|IBA_API_URL=|' "$ENV_FILE"
  echo "created backend/.env"
fi
grep -q '^MAGANA_ENV=' "$ENV_FILE" || echo "MAGANA_ENV=development" >> "$ENV_FILE"
if ! grep -q '^MAGANA_API_KEY=.\+' "$ENV_FILE"; then
  key="dev-$(openssl rand -hex 16)"
  if grep -q '^MAGANA_API_KEY=' "$ENV_FILE"; then
    sed -i '' "s|^MAGANA_API_KEY=.*|MAGANA_API_KEY=$key|" "$ENV_FILE"
  else
    echo "MAGANA_API_KEY=$key" >> "$ENV_FILE"
  fi
  echo "added a dev MAGANA_API_KEY to backend/.env"
fi
KEY="$(grep '^MAGANA_API_KEY=' "$ENV_FILE" | cut -d= -f2-)"

# ---- Python environment
if [ ! -x "$ROOT/backend/.venv/bin/uvicorn" ]; then
  echo "setting up backend/.venv (Python 3.11+)"
  "${PYTHON:-python3.11}" -m venv "$ROOT/backend/.venv"
  "$ROOT/backend/.venv/bin/pip" install -q -r "$ROOT/backend/requirements.txt"
fi

# ---- where the app runs
target="${1:-auto}"
emulator_id() { "$ADB" devices 2>/dev/null | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}'; }
if [ "$target" = auto ]; then
  if [ -n "$(emulator_id)" ] || [ -x "$SDK/emulator/emulator" ]; then target=emulator; else target=chrome; fi
fi
case "$target" in
  emulator)
    if [ -z "$(emulator_id)" ]; then
      echo "starting the emulator ($AVD)"
      "$SDK/emulator/emulator" -avd "$AVD" -cores 4 -memory 4096 -no-snapshot-load -no-boot-anim \
        >/tmp/magana-emulator.log 2>&1 &
      "$ADB" wait-for-device
      until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
    fi
    DEVICE="$(emulator_id)"
    API="http://10.0.2.2:$PORT"     # the emulator's name for this Mac
    ;;
  chrome)
    DEVICE=chrome
    API="http://localhost:$PORT"
    ;;
  *) echo "usage: $0 [emulator|chrome]" >&2; exit 2 ;;
esac

# ---- backend
if lsof -ti "tcp:$PORT" >/dev/null 2>&1; then
  echo "port $PORT is already in use; stop that first (lsof -i tcp:$PORT)" >&2
  exit 1
fi
(cd "$ROOT/backend" && exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port "$PORT" \
   --env-file .env --reload) &
BACKEND=$!
trap 'kill $BACKEND 2>/dev/null; wait $BACKEND 2>/dev/null' EXIT INT TERM
echo -n "waiting for the backend on :$PORT "
for _ in $(seq 1 60); do
  curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1 && { echo "ok"; break; }
  kill -0 $BACKEND 2>/dev/null || { echo "the backend stopped; see the log above" >&2; exit 1; }
  echo -n "."; sleep 1
done
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://localhost:$PORT/explain/check" \
  -H 'Content-Type: application/json' -d '{"source_text":"a","explanation":"a"}')
echo "backend refuses calls without the key: HTTP $code (expect 401)"

# ---- app
cd "$ROOT/app"
args=(-d "$DEVICE" --dart-define=MAGANA_API="$API" --dart-define=MAGANA_API_KEY="$KEY" --dart-define=MAGANA_ENV=development)
[ "$DEVICE" = chrome ] && args+=(--web-port 5173)
echo "flutter run ${args[*]/MAGANA_API_KEY=*/MAGANA_API_KEY=<dev key>}"
flutter run "${args[@]}"
