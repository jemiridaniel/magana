#!/usr/bin/env bash
# Publish the signed tester APKs from scripts/build-apk.sh.
#   scripts/publish-apk.sh [release-notes.md]
# 1. Makes the GitHub release v<version> (the repository is public, so its files are too), marked
#    "latest", with:
#    - magana.apk: 64-bit ARM, the default (https://<domain>/download/android redirects to it);
#    - magana-32bit.apk: 32-bit ARM, for older phones (/download/android-32bit);
#    - magana-universal.apk: every CPU type, for emulators and testing (release page only);
#    - the same three with the version in the name, and latest.json (sizes, checksums, date).
# 2. Redeploys the website, which shows each file's size from latest.json. The APKs never go to
#    Cloudflare Pages (files over 25 MB aren't allowed there); website/public/_redirects points
#    at the newest release, so the addresses never change.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/app/build/app/outputs/flutter-apk"
VERSION=$(grep '^version:' "$ROOT/app/pubspec.yaml" | awk '{print $2}')
TAG="v$VERSION"
NOTES="${1:-}"
for f in app-arm64-v8a-release.apk app-armeabi-v7a-release.apk app-release.apk; do
  [ -f "$OUT/$f" ] || { echo "no $f: run scripts/build-apk.sh first" >&2; exit 1; }
  # Never publish a build with a real secret in it (docs/INFRA.md, "Secrets").
  "$ROOT/backend/.venv/bin/python" "$ROOT/scripts/check_bundle_secrets.py" "$OUT/$f"
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$OUT/app-arm64-v8a-release.apk" "$tmp/magana.apk"
cp "$OUT/app-armeabi-v7a-release.apk" "$tmp/magana-32bit.apk"
cp "$OUT/app-release.apk" "$tmp/magana-universal.apk"
cp "$tmp/magana.apk" "$tmp/magana-$VERSION.apk"
cp "$tmp/magana-32bit.apk" "$tmp/magana-$VERSION-32bit.apk"
cp "$tmp/magana-universal.apk" "$tmp/magana-$VERSION-universal.apk"
python3 - "$tmp" "$VERSION" <<'PY'
import datetime, hashlib, json, os, sys
d, version = sys.argv[1], sys.argv[2]
def facts(name, abis):
    p = os.path.join(d, name)
    return {"name": name, "bytes": os.path.getsize(p), "abis": abis,
            "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}
files = {"arm64": facts("magana.apk", ["arm64-v8a"]),
         "arm32": facts("magana-32bit.apk", ["armeabi-v7a"]),
         "universal": facts("magana-universal.apk", ["armeabi-v7a", "arm64-v8a", "x86_64"])}
lagos = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=1)))
# "bytes" and "sha256" at the top are the default (64-bit) file, as before.
json.dump({"version": version, "date": lagos.date().isoformat(), "min_android": "7.0",
           "bytes": files["arm64"]["bytes"], "sha256": files["arm64"]["sha256"], "files": files},
          open(os.path.join(d, "latest.json"), "w"), indent=1)
mb = lambda f: f"{round(files[f]['bytes'] / 1048576)} MB"
open(os.path.join(d, "notes.md"), "w").write(f"""Tester build {version}. Install it from https://magana.ng/download/android

| File | For | Size |
|---|---|---|
| **magana.apk** | Most phones from 2017 onwards (64-bit) | {mb('arm64')} |
| **magana-32bit.apk** | Older phone? If install says "App not installed" or "not compatible", use this one (32-bit) | {mb('arm32')} |
| **magana-universal.apk** | For emulators and testing ({mb('universal')}): every CPU type | {mb('universal')} |

The files with the version in their name are the same builds.
""")
PY
[ -n "$NOTES" ] || NOTES="$tmp/notes.md"
ASSETS=("$tmp/magana.apk" "$tmp/magana-32bit.apk" "$tmp/magana-universal.apk" "$tmp/magana-$VERSION.apk"
        "$tmp/magana-$VERSION-32bit.apk" "$tmp/magana-$VERSION-universal.apk" "$tmp/latest.json")
export GH_TOKEN="${GH_TOKEN:-$(gh auth token --user jemiridaniel 2>/dev/null || gh auth token)}"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "${ASSETS[@]}" --clobber
  gh release edit "$TAG" --notes-file "$NOTES" >/dev/null
else
  gh release create "$TAG" --latest --title "Magana for Android $VERSION (testers)" --notes-file "$NOTES" "${ASSETS[@]}"
fi
gh workflow run ci.yml --ref main && echo "Website redeploy started (gh run watch)"
echo "https://magana.ng/download/android  (version $VERSION)"
