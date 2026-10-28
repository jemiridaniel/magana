#!/usr/bin/env bash
# Use the repository's tracked hooks (.githooks/): today a pre-commit secret scan with gitleaks.
#   scripts/install-hooks.sh
# Run once per clone. Without gitleaks the hook only warns (brew install gitleaks to turn it on).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/*
git config core.hooksPath .githooks
echo "Hooks installed: core.hooksPath = .githooks"
if command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks $(gitleaks version) will scan the staged changes before each commit."
else
  echo "gitleaks isn't installed: the pre-commit scan is skipped until you install it (brew install gitleaks)."
fi
