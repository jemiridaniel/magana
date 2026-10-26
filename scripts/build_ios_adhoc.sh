#!/usr/bin/env bash
# Ad Hoc .ipa for registered iPhones (install with Diawi), signed automatically with the
# team in app/ios/ExportOptions.plist. docs/FINDINGS.md, "iOS".
#   scripts/build_ios_adhoc.sh
# The .ipa goes to a third-party site, so NO key is built in: only the server's address
# (MAGANA_API from ~/.magana/app.env). The script refuses to finish if it finds the API key,
# the web key or a private key inside the .ipa.
set -euo pipefail
source "${MAGANA_APP_ENV:-$HOME/.magana/app.env}"
: "${MAGANA_API:?set MAGANA_API in ~/.magana/app.env}"
export PATH="$HOME/development/flutter/bin:$PATH"
cd "$(dirname "$0")/../app"

flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define=MAGANA_API="$MAGANA_API"

ipa=$(ls -t build/ios/ipa/*.ipa | head -1)

# No secret may ship: unpack and search every file for the keys we know of.
check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
unzip -q "$ipa" -d "$check"
for secret in "${MAGANA_API_KEY:-}" "${MAGANA_WEB_API_KEY:-}"; do
  if [ -n "$secret" ] && grep -rqF -- "$secret" "$check"; then
    echo "REFUSED: an API key is inside $ipa. Delete it; don't upload it." >&2
    rm -f "$ipa"
    exit 1
  fi
done
if grep -rqE -- "-----BEGIN (RSA |EC )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}" "$check"; then
  echo "REFUSED: a private key or AWS key is inside $ipa. Delete it; don't upload it." >&2
  rm -f "$ipa"
  exit 1
fi

version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo
echo "Version: $version"
echo "IPA:     $(pwd)/$ipa"
echo "Size:    $(du -h "$ipa" | cut -f1) ($(stat -f%z "$ipa") bytes)"
echo "Secrets: none found (API key, web key, private keys, AWS keys)"
