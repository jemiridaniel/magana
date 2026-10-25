#!/usr/bin/env bash
# Put the latest signed arm64 APK on the website: https://<domain>/downloads/magana.apk (and
# magana-<version>.apk), linked from https://<domain>/android/. Run after scripts/build-apk.sh.
# Copies over SSH (~/.magana/aws.env), so the security group must allow your current IP.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_HOST:?set MAGANA_HOST in ~/.magana/aws.env}"
KEY="${MAGANA_SSH_KEY/#\~/$HOME}"
APK="$ROOT/app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
VERSION=$(grep '^version:' "$ROOT/app/pubspec.yaml" | awk '{print $2}')
DOMAIN=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["domain"])' "$ROOT/config/public.json")
[ -f "$APK" ] || { echo "no APK: run scripts/build-apk.sh first" >&2; exit 1; }
tmp=$(mktemp -d)
cp "$APK" "$tmp/magana-$VERSION.apk"
cp "$APK" "$tmp/magana.apk"
# The page shows the version, size and checksum, so testers can check what they downloaded.
python3 - "$tmp" "$VERSION" <<'PY'
import hashlib, json, os, sys
d, version = sys.argv[1], sys.argv[2]
apk = os.path.join(d, "magana.apk")
json.dump({"version": version, "bytes": os.path.getsize(apk),
           "sha256": hashlib.sha256(open(apk, "rb").read()).hexdigest()},
          open(os.path.join(d, "latest.json"), "w"), indent=1)
PY
ssh -i "$KEY" "ubuntu@$MAGANA_HOST" 'mkdir -p ~/srv/magana/deploy/downloads'
rsync -az -e "ssh -i $KEY" "$tmp/" "ubuntu@$MAGANA_HOST:srv/magana/deploy/downloads/"
rm -rf "$tmp"
echo "https://$DOMAIN/downloads/magana.apk  (version $VERSION)"
