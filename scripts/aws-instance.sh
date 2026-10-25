#!/usr/bin/env bash
# Start, stop or check the Magana EC2 instance from your Mac (docs/DEPLOY_AWS.md).
#   scripts/aws-instance.sh start | stop | status
# Reads ~/.magana/aws.env (kept outside the repo):
#   MAGANA_INSTANCE_ID=i-0123456789abcdef0
#   AWS_PROFILE=magana
#   AWS_REGION=eu-west-2
#   MAGANA_HOST=18.130.12.34          # the Elastic IP
#   MAGANA_SSH_KEY=~/.ssh/magana-london.pem
set -euo pipefail
# shellcheck disable=SC1090
source "${MAGANA_AWS_ENV:-$HOME/.magana/aws.env}"
: "${MAGANA_INSTANCE_ID:?set MAGANA_INSTANCE_ID in ~/.magana/aws.env}"
export AWS_PROFILE="${AWS_PROFILE:-magana}" AWS_REGION="${AWS_REGION:-eu-west-2}"

state() {
  aws ec2 describe-instances --instance-ids "$MAGANA_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[State.Name,InstanceType,PublicIpAddress]' --output text
}

case "${1:-status}" in
  start)
    aws ec2 start-instances --instance-ids "$MAGANA_INSTANCE_ID" >/dev/null
    aws ec2 wait instance-running --instance-ids "$MAGANA_INSTANCE_ID"
    echo "running: $(state)"
    if [ -n "${MAGANA_HOST:-}" ]; then
      domain="api.$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["domain"])' "$(dirname "$0")/../config/public.json")"
      echo -n "waiting for https://$domain/health "
      for _ in $(seq 1 40); do
        curl -fsS "https://$domain/health" >/dev/null 2>&1 && { echo "ok"; exit 0; }
        echo -n "."; sleep 5
      done
      echo " not answering yet (containers may still be starting)"
    fi
    ;;
  stop)
    aws ec2 stop-instances --instance-ids "$MAGANA_INSTANCE_ID" >/dev/null
    aws ec2 wait instance-stopped --instance-ids "$MAGANA_INSTANCE_ID"
    echo "stopped: $(state)  (the disk and Elastic IP still cost a little while stopped)"
    ;;
  status)
    echo "$(state)"
    ;;
  *)
    echo "usage: $0 start|stop|status" >&2
    exit 2
    ;;
esac
