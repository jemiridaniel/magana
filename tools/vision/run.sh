#!/bin/bash
# Compile Apple Vision's reader exactly as the iPhone app has it, then run it on one image.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
out="${TMPDIR:-/tmp}/magana-vision"
mkdir -p "$out"
sed -n '/VISION-BEGIN/,/VISION-END/p' "$here/../../app/ios/Runner/MaganaChannels.swift" > "$out/VisionText.swift"
printf 'import Vision\nimport CoreGraphics\n' | cat - "$out/VisionText.swift" > "$out/VisionText2.swift"
swiftc -O -o "$out/vision" "$here/main.swift" "$out/VisionText2.swift" 2>&1 | grep -v warning || true
"$out/vision" "$@"
