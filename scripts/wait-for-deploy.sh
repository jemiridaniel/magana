#!/usr/bin/env bash
# Wait until api.magana.ng runs a commit (CI's deploy job and the Rollback workflow; docs/INFRA.md).
#   scripts/wait-for-deploy.sh <12-character commit> [minutes, default 30]
# Reads https://api.magana.ng/deploy-status (written by deploy/server/magana-deploy) and stops
# early if the server says this commit failed. Then checks /health (this commit, database ok) and
# that the API still refuses callers without the app key. Prints only commits and states.
set -euo pipefail
want="${1:?usage: wait-for-deploy.sh <commit> [minutes]}"
minutes="${2:-30}"
API="https://api.${DOMAIN:-magana.ng}"
end=$((SECONDS + minutes * 60)); last=""
while [ $SECONDS -lt $end ]; do
  st=$(curl -s --max-time 15 "$API/deploy-status" || true)
  state=$(jq -r '.state // empty' <<<"$st" 2>/dev/null || true)
  build=$(jq -r '.build // empty' <<<"$st" 2>/dev/null || true)
  live=$(jq -r '.live // empty' <<<"$st" 2>/dev/null || true)
  now="state=${state:-unreachable} build=${build:-none} live=${live:-none}"
  [ "$now" = "$last" ] || { echo "$(date -u +%T) $now"; last=$now; }
  if [ "$build" = "$want" ] && [ "$state" = failed ]; then
    echo "the server refused $want: $(jq -r '.message' <<<"$st"). The previous commit is still live."
    exit 1
  fi
  [ "$live" = "$want" ] && [ "$state" = live ] && break
  sleep 15
done
[ "$live" = "$want" ] || { echo "the server didn't switch to $want within $minutes minutes"; exit 1; }

body=$(curl -s --max-time 30 "$API/health")
[ "$(jq -r .build <<<"$body")" = "$want" ] || { echo "/health answers from another commit"; exit 1; }
[ "$(jq -r .database <<<"$body")" = ok ] || { echo "the server is up but its database isn't"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/read")
[ "$code" = 401 ] || { echo "a call without the app key gave $code, not 401"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/portal/me" -H "X-Magana-Key: x")
[ "$code" = 401 ] || { echo "the portal API without a key or session gave $code, not 401"; exit 1; }
echo "live: $want, database ok, keys required"
