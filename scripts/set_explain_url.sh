#!/usr/bin/env bash
# Point the AWS server's Explain at a new N-ATLaS URL (e.g. the Kaggle tunnel printed by
# notebooks/magana-serve) and restart the backend.
#   scripts/set_explain_url.sh https://abc-def.trycloudflare.com [engine]
# engine: vllm (default) | hf_space | llamacpp. Use "stub" with no URL to go back to the preview:
#   scripts/set_explain_url.sh "" stub
# EXPLAIN_API_KEY must already be in the server's .env (the same key the vLLM server requires).
set -euo pipefail
url="${1:?usage: $0 <url> [engine]}"
engine="${2:-vllm}"
case "$engine" in stub|vllm|hf_space|llamacpp) ;; *) echo "unknown engine: $engine" >&2; exit 2 ;; esac
[[ "$engine" == stub || "$url" == https://* ]] || { echo "the URL must start with https://" >&2; exit 2; }
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_HOST:?set MAGANA_HOST in ~/.magana/aws.env}"

ssh -i "${MAGANA_SSH_KEY/#\~/$HOME}" "ubuntu@$MAGANA_HOST" bash -s -- "$url" "$engine" <<'REMOTE'
set -euo pipefail
url="$1"; engine="$2"
cd ~/srv/magana
set_var() {  # replace KEY=... or append it
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
set_var EXPLAIN_ENGINE "$engine"
set_var EXPLAIN_URL "$url"
grep -q '^EXPLAIN_API_KEY=.\+' .env || [ "$engine" = stub ] || echo "warning: EXPLAIN_API_KEY is empty in .env"
# .env changes are only picked up when the container is recreated.
sudo docker compose -f docker-compose.prod.yml up -d --force-recreate --no-deps magana
sleep 5
sudo docker compose -f docker-compose.prod.yml exec -T magana \
  python -c "from app.explain import default_engine as d; e = d(); print('engine:', type(e).__name__, getattr(e, 'url', ''))"
REMOTE
