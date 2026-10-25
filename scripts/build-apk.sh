#!/usr/bin/env bash
# Build the tester APKs (release, signed with the upload key, one per CPU type) and print
# the arm64 one, which fits almost all current Android phones.
# Reads ~/.magana/app.env (outside the repo):
#   MAGANA_API=https://api.magana.ng             # the server (docs/DEPLOY_AWS.md)
#   MAGANA_API_KEY=...                           # the server's MAGANA_API_KEY
# Bump `version:` in app/pubspec.yaml before each build you hand out (the +N must grow).
set -euo pipefail
# shellcheck disable=SC1090
source "${MAGANA_APP_ENV:-$HOME/.magana/app.env}"
: "${MAGANA_API:?set MAGANA_API in ~/.magana/app.env}"
: "${MAGANA_API_KEY:?set MAGANA_API_KEY in ~/.magana/app.env}"
export PATH="$HOME/development/flutter/bin:$PATH"
cd "$(dirname "$0")/../app"
[ -e android/key.properties ] || { echo "android/key.properties missing (docs/TESTER_INSTALL.md, signing)" >&2; exit 1; }

flutter build apk --release --split-per-abi \
  --dart-define=MAGANA_API="$MAGANA_API" \
  --dart-define=MAGANA_API_KEY="$MAGANA_API_KEY"

apk="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo
echo "Version: $version"
echo "APK:     $(pwd)/$apk"
echo "Size:    $(du -h "$apk" | cut -f1) ($(stat -f%z "$apk") bytes)"
apksigner=$(ls -d "$HOME"/Library/Android/sdk/build-tools/*/ | tail -1)apksigner
echo "Signed:  $("$apksigner" verify --print-certs "$apk" | grep -m1 'SHA-256' | sed 's/.*: //')"
