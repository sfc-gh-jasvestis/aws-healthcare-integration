#!/bin/bash
# AWS Teardown: Healthcare Data Integration
# Destroys QuickSight resources, SNS topic, and clears secrets

set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
SNS_TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:healthcare-care-gap-alerts"

echo "=== Tearing Down AWS Resources: Healthcare Data Integration ==="

# Delete QuickSight Q Topic
echo "Deleting Q topic: hc-integration-q..."
aws quicksight delete-topic \
  --aws-account-id "$ACCOUNT_ID" \
  --topic-id "hc-integration-q" \
  --region "$REGION" 2>/dev/null && echo "  Deleted." || echo "  Not found or already deleted."

# Delete QuickSight Datasets
echo "Deleting dataset: hc-integration-quality..."
aws quicksight delete-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-quality" \
  --region "$REGION" 2>/dev/null && echo "  Deleted." || echo "  Not found or already deleted."

echo "Deleting dataset: hc-integration-gaps..."
aws quicksight delete-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-gaps" \
  --region "$REGION" 2>/dev/null && echo "  Deleted." || echo "  Not found or already deleted."

# Delete SNS Topic
echo "Deleting SNS topic: healthcare-care-gap-alerts..."
aws sns delete-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$REGION" 2>/dev/null && echo "  Deleted." || echo "  Not found or already deleted."

# Clear secrets (Snowflake-side — informational)
echo ""
echo "=== Manual Cleanup Required ==="
echo "Run in Snowflake:"
echo "  DROP SECRET IF EXISTS HEALTHCARE_INTEGRATION.RAW.SNS_CARE_GAP_SECRET;"
echo "  DROP DATABASE IF EXISTS HEALTHCARE_INTEGRATION;"

echo ""
echo "=== AWS teardown complete ==="
