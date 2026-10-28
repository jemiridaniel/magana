#!/usr/bin/env bash
# Assemble what the Hugging Face Space builds (docs/INFRA.md): its Dockerfile and README, the
# backend's code and requirements, and content/ (phrase templates, number words, places).
#   scripts/build-space.sh <out-dir>
# Never copies a secret: the Space's secrets are set in its Settings, not in files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?usage: scripts/build-space.sh <out-dir>}"
mkdir -p "$OUT"
cp "$ROOT/deploy/hf-space/Dockerfile" "$ROOT/deploy/hf-space/README.md" "$OUT/"
cp "$ROOT/backend/requirements.txt" "$ROOT/backend/requirements-second-ocr.txt" "$OUT/"
rsync -a --delete --exclude '__pycache__' --exclude '*.pyc' "$ROOT/backend/app/" "$OUT/app/"
rsync -a --delete --exclude '__pycache__' "$ROOT/content/" "$OUT/content/"
# The commit, for /health: the deploy waits until the Space answers with it.
[ -n "${MAGANA_BUILD:-}" ] && echo "$MAGANA_BUILD" > "$OUT/app/build.txt"
# Nothing that looks like a key goes to the Space repo.
if grep -rIlE '(hf_[A-Za-z0-9]{30,}|re_[A-Za-z0-9]{20,}|whsec_[A-Za-z0-9+/=]{20,}|postgres(ql)?://[^ ]+:[^ @]+@)' "$OUT" >/dev/null; then
  echo "refusing: something in the Space bundle looks like a secret" >&2
  exit 1
fi
echo "Space bundle in $OUT ($(du -sh "$OUT" | cut -f1))"
