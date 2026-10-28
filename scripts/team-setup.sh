#!/usr/bin/env bash
# Make the first Magana admin (or reset an authenticator), on the test-phase server, in its live
# container: the same database and MAGANA_CODE_KEY as the API (docs/DEPLOY.md).
#   scripts/team-setup.sh --email you@example.com --name "Your Name"
#   scripts/team-setup.sh --email you@example.com --reset-authenticator
# From any computer with the server's SSH key; or, on the server itself:
#   sudo magana-deploy exec python -m app.team_setup --email … --name …
set -euo pipefail
HOST="${MAGANA_SERVER:-api.magana.ng}"
KEY="${MAGANA_SSH_KEY:-$HOME/.ssh/magana_oracle.key}"
args=$(printf ' %q' "$@")
ssh -t -i "$KEY" "ubuntu@$HOST" "sudo magana-deploy exec python -m app.team_setup$args"
