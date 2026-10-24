#!/usr/bin/env bash
# Deploy the latest main to the server: pull both repos and rebuild (docs/DEPLOY_AWS.md).
set -euo pipefail
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_HOST:?set MAGANA_HOST in ~/.magana/aws.env}"
ssh -i "${MAGANA_SSH_KEY/#\~/$HOME}" "ubuntu@$MAGANA_HOST" '
  set -e
  cd ~/srv/iba-natlas && git pull --ff-only
  cd ~/srv/magana && git pull --ff-only
  sudo docker compose -f docker-compose.prod.yml up -d --build
  sudo docker image prune -f >/dev/null
  sudo docker compose -f docker-compose.prod.yml ps
'
