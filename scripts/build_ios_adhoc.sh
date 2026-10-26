#!/usr/bin/env bash
# Ad Hoc .ipa for registered iPhones (install with Diawi), signed automatically with the
# team in app/ios/ExportOptions.plist. docs/FINDINGS.md, "iOS".
#   scripts/build_ios_adhoc.sh
# The .ipa goes to a third-party site. It carries the server's address and the public app key
# (MAGANA_API, MAGANA_API_KEY from ~/.magana/app.env), the same as the APK and the PWA: an app
# identifier, not a secret; the server's rate limits and daily caps protect it. The script
# refuses to finish if scripts/check_bundle_secrets.py finds any real secret inside the .ipa.
set -euo pipefail
source "${MAGANA_APP_ENV:-$HOME/.magana/app.env}"
: "${MAGANA_API:?set MAGANA_API in ~/.magana/app.env}"
: "${MAGANA_API_KEY:?set MAGANA_API_KEY in ~/.magana/app.env}"
export PATH="$HOME/development/flutter/bin:$PATH"
cd "$(dirname "$0")/../app"

flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define=MAGANA_API="$MAGANA_API" \
  --dart-define=MAGANA_API_KEY="$MAGANA_API_KEY"

ipa=$(ls -t build/ios/ipa/*.ipa | head -1)

# No real secret may ship (AWS, SES, model and WhatsApp keys, signing passwords...).
if ! ../backend/.venv/bin/python ../scripts/check_bundle_secrets.py "$ipa"; then
  echo "REFUSED: delete $ipa and don't upload it." >&2
  rm -f "$ipa"
  exit 1
fi

version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo
echo "Version: $version"
echo "IPA:     $(pwd)/$ipa"
echo "Size:    $(du -h "$ipa" | cut -f1) ($(stat -f%z "$ipa") bytes)"
echo "Key:     the public app key only (an app identifier, rate-limited)"
