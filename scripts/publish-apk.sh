#!/usr/bin/env bash
# Publish the latest signed arm64 APK for testers. Run after scripts/build-apk.sh.
#   scripts/publish-apk.sh [release-notes.md]
# 1. Makes the GitHub release v<version> (the repository is public, so its files are too) with:
#    magana.apk (always this name), magana-<version>.apk and latest.json (version, size, date,
#    checksum). It is marked "latest".
# 2. Redeploys the website, which shows latest.json next to the button. The button's address,
#    https://<domain>/download/android, redirects to
#    https://github.com/jemiridaniel/magana/releases/latest/download/magana.apk (website/public/
#    _redirects), so it always serves the newest release and never has to change. The APK itself
#    never goes to Cloudflare Pages (files over 25 MB aren't allowed there).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="$ROOT/app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
VERSION=$(grep '^version:' "$ROOT/app/pubspec.yaml" | awk '{print $2}')
TAG="v$VERSION"
NOTES="${1:-}"
[ -f "$APK" ] || { echo "no APK: run scripts/build-apk.sh first" >&2; exit 1; }
# Never publish a build with a real secret in it (docs/INFRA.md, "Secrets").
"$ROOT/backend/.venv/bin/python" "$ROOT/scripts/check_bundle_secrets.py" "$APK"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$APK" "$tmp/magana-$VERSION.apk"
cp "$APK" "$tmp/magana.apk"
python3 - "$tmp" "$VERSION" <<'PY'
import datetime, hashlib, json, os, sys
d, version = sys.argv[1], sys.argv[2]
apk = os.path.join(d, "magana.apk")
lagos = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=1)))
json.dump({"version": version, "bytes": os.path.getsize(apk), "date": lagos.date().isoformat(),
           "min_android": "7.0", "sha256": hashlib.sha256(open(apk, "rb").read()).hexdigest()},
          open(os.path.join(d, "latest.json"), "w"), indent=1)
PY
export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel 2>/dev/null || gh auth token)}"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$tmp/magana.apk" "$tmp/magana-$VERSION.apk" "$tmp/latest.json" --clobber
else
  gh release create "$TAG" --latest --title "Magana for Android $VERSION (testers)" \
    ${NOTES:+--notes-file "$NOTES"} ${NOTES:---notes "Tester build $VERSION. Install it from https://magana.ng/download/android"} \
    "$tmp/magana.apk" "$tmp/magana-$VERSION.apk" "$tmp/latest.json"
fi
gh workflow run ci.yml --ref main && echo "Website redeploy started (gh run watch)"
echo "https://magana.ng/download/android  (version $VERSION)"
