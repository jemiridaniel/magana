#!/usr/bin/env bash
# Build the tester APKs (release, signed with the upload key), three of them:
# - 64-bit ARM (arm64-v8a, ~34 MB): the website's default download, most phones from 2017 on;
# - 32-bit ARM (armeabi-v7a): the website's "Older phone?" link (Nurse Balogun's review, build 7);
# - universal (every CPU type, x86_64 too, ~95 MB): GitHub release page only, for emulators.
# Reads ~/.magana/app.env (outside the repo):
#   MAGANA_API=https://api.magana.ng             # the server (docs/INFRA.md)
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

defines=(--dart-define=MAGANA_API="$MAGANA_API" --dart-define=MAGANA_API_KEY="$MAGANA_API_KEY")
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64 "${defines[@]}"
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 "${defines[@]}"

out=build/app/outputs/flutter-apk
version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
apksigner=$(ls -d "$HOME"/Library/Android/sdk/build-tools/*/ | tail -1)apksigner
echo
echo "Version: $version"
for apk in "$out/app-arm64-v8a-release.apk" "$out/app-armeabi-v7a-release.apk" "$out/app-release.apk"; do
  abis=$(unzip -l "$apk" | awk '/lib\/.*\/libflutter.so/{split($4,p,"/"); print p[2]}' | sort | paste -sd' ' -)
  echo "$(basename "$apk"): $(du -h "$apk" | cut -f1), $abis, signed $("$apksigner" verify --print-certs "$apk" | grep -m1 'SHA-256' | sed 's/.*: //' | cut -c1-16)…"
done
