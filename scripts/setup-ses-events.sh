#!/usr/bin/env bash
# Bounces and complaints for Magana's email (docs/DEPLOY_AWS.md, "Bounces and complaints").
# Run it in AWS CloudShell, signed in to the Magana account, in eu-west-2 (London):
#   bash setup-ses-events.sh
# Safe to run again: each step skips or updates what is already there. It stores no key.
#  1. The SES account-level suppression list for BOUNCE and COMPLAINT.
#  2. The configuration set "magana-default" (reputation metrics on).
#  3. The SNS topic "magana-ses-events", which only SES in this account may publish to.
#  4. The set's event destination: Bounce, Complaint and Delivery → the topic.
#  5. The server's role (magana-ec2-ssm): send through the set, and read the SES metrics
#     for the weekly check (backend/app/ses_health.py).
#  6. The HTTPS subscription to https://api.magana.ng/internal/ses-events, which the server
#     confirms itself (backend/app/ses_events.py). Needs the server already updated.
set -euo pipefail

REGION=eu-west-2
SET=magana-default
TOPIC_NAME=magana-ses-events
ROLE=magana-ec2-ssm
POLICY=magana-send-signin-email
ENDPOINT=https://api.magana.ng/internal/ses-events
export AWS_REGION=$REGION AWS_DEFAULT_REGION=$REGION

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "AWS account $ACCOUNT, region $REGION"

echo "1. Account suppression list: BOUNCE and COMPLAINT"
aws sesv2 put-account-suppression-attributes --suppressed-reasons BOUNCE COMPLAINT

echo "2. Configuration set $SET"
if aws sesv2 get-configuration-set --configuration-set-name "$SET" >/dev/null 2>&1; then
  echo "   already there"
else
  aws sesv2 create-configuration-set --configuration-set-name "$SET" \
    --reputation-options ReputationMetricsEnabled=true --sending-options SendingEnabled=true \
    --suppression-options SuppressedReasons=BOUNCE,COMPLAINT
fi

echo "3. SNS topic $TOPIC_NAME"
TOPIC=$(aws sns create-topic --name "$TOPIC_NAME" --query TopicArn --output text)
aws sns set-topic-attributes --topic-arn "$TOPIC" --attribute-name Policy --attribute-value "$(cat <<JSON
{"Version": "2012-10-17", "Statement": [{
  "Sid": "SesInThisAccountOnly", "Effect": "Allow",
  "Principal": {"Service": "ses.amazonaws.com"}, "Action": "SNS:Publish", "Resource": "$TOPIC",
  "Condition": {"StringEquals": {"AWS:SourceAccount": "$ACCOUNT"},
                "ArnLike": {"AWS:SourceArn": "arn:aws:ses:$REGION:$ACCOUNT:configuration-set/$SET"}}}]}
JSON
)"
echo "   $TOPIC"

echo "4. Event destination: Bounce, Complaint, Delivery → the topic"
DEST='{"Enabled": true, "MatchingEventTypes": ["BOUNCE", "COMPLAINT", "DELIVERY"], "SnsDestination": {"TopicArn": "'"$TOPIC"'"}}'
if aws sesv2 get-configuration-set-event-destinations --configuration-set-name "$SET" \
     --query "EventDestinations[?Name=='magana-sns'] | length(@)" --output text | grep -q '^1$'; then
  aws sesv2 update-configuration-set-event-destination --configuration-set-name "$SET" \
    --event-destination-name magana-sns --event-destination "$DEST"
else
  aws sesv2 create-configuration-set-event-destination --configuration-set-name "$SET" \
    --event-destination-name magana-sns --event-destination "$DEST"
fi

echo "5. The server's role $ROLE: send through $SET, read SES metrics"
aws iam put-role-policy --role-name "$ROLE" --policy-name "$POLICY" --policy-document "$(cat <<JSON
{"Version": "2012-10-17", "Statement": [
  {"Sid": "SendFromNoReplyThroughTheSet", "Effect": "Allow", "Action": "ses:SendEmail",
   "Resource": ["arn:aws:ses:$REGION:$ACCOUNT:identity/magana.ng",
                "arn:aws:ses:$REGION:$ACCOUNT:configuration-set/$SET"],
   "Condition": {"StringEquals": {"ses:FromAddress": "no-reply@magana.ng"}}},
  {"Sid": "WeeklyReputationCheck", "Effect": "Allow", "Action": "cloudwatch:GetMetricStatistics", "Resource": "*"}]}
JSON
)"

echo "6. HTTPS subscription → $ENDPOINT"
status=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: text/plain' --data '{}' "$ENDPOINT" || true)
if [ "$status" != "403" ]; then
  echo "   The server answered $status, not 403: it isn't running the new code yet. Push to main, wait for"
  echo "   the deploy (gh run watch), then run this script again. Steps 1-5 are done."
  exit 1
fi
aws sns subscribe --topic-arn "$TOPIC" --protocol https --notification-endpoint "$ENDPOINT" >/dev/null
for _ in $(seq 1 12); do
  sub=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" \
        --query "Subscriptions[?Endpoint=='$ENDPOINT'].SubscriptionArn | [0]" --output text)
  if [ "$sub" != "PendingConfirmation" ] && [ "$sub" != "None" ]; then
    echo "   confirmed: $sub"
    echo "Done. Test it: send to bounce@simulator.amazonses.com through the set (docs/DEPLOY_AWS.md)."
    exit 0
  fi
  sleep 5
done
echo "   Still pending after a minute. Check the server log for 'ses events: subscription confirmed'." >&2
exit 1
