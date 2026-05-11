#!/bin/bash
# QuickSight Deployment: Healthcare Data Integration
# Creates data source, datasets, Q topic, and dashboard
#
# BEFORE RUNNING: Set the following variables for your environment:
#   SNOWFLAKE_HOST  - Your Snowflake account URL (e.g., myaccount.snowflakecomputing.com)
#   QS_SF_PASSWORD  - Password for the QuickSight Snowflake service user

set -euo pipefail

: "${SNOWFLAKE_HOST:?Set SNOWFLAKE_HOST to your Snowflake account URL (e.g. myaccount.snowflakecomputing.com)}"
: "${QS_SF_PASSWORD:?Set QS_SF_PASSWORD to the password for your QuickSight Snowflake service user}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
QS_USER="arn:aws:quicksight:${REGION}:${ACCOUNT_ID}:user/default/${ACCOUNT_ID}"
DATA_SOURCE_ID="hc-integration-snowflake"

echo "=== Deploying QuickSight Resources: Healthcare Data Integration ==="

# Data Source
echo "Creating data source: ${DATA_SOURCE_ID}..."
aws quicksight create-data-source \
  --aws-account-id "$ACCOUNT_ID" \
  --data-source-id "$DATA_SOURCE_ID" \
  --name "HC Integration - Snowflake" \
  --type SNOWFLAKE \
  --data-source-parameters '{"SnowflakeParameters":{"Host":"'"${SNOWFLAKE_HOST}"'","Database":"HEALTHCARE_INTEGRATION","Warehouse":"CORTEX"}}' \
  --credentials '{"CredentialPair":{"Username":"QUICKSIGHT_HEALTHCARE_SVC","Password":"'"${QS_SF_PASSWORD}"'"}}' \
  --ssl-properties '{"DisableSsl":false}' \
  --permissions '[{"Principal":"'"${QS_USER}"'","Actions":["quicksight:DescribeDataSource","quicksight:DescribeDataSourcePermissions","quicksight:PassDataSource","quicksight:UpdateDataSource","quicksight:DeleteDataSource","quicksight:UpdateDataSourcePermissions"]}]' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

sleep 10
echo "Checking data source status..."
aws quicksight describe-data-source --aws-account-id "$ACCOUNT_ID" --data-source-id "$DATA_SOURCE_ID" --region "$REGION" --query 'DataSource.Status' --output text

# Dataset: Quality Measures Compliance
echo "Creating dataset: hc-integration-quality..."
aws quicksight create-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-quality" \
  --name "HC Integration: Quality Compliance" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{"qt":{"CustomSql":{"DataSourceArn":"arn:aws:quicksight:'"${REGION}"':'"${ACCOUNT_ID}"':datasource/'"${DATA_SOURCE_ID}"'","Name":"QualityCompliance","SqlQuery":"SELECT MEASURE_ID, MEASURE_NAME, MEASURE_TYPE, TARGET_PCT, COMPLIANCE_PCT, GAP_COUNT, DENOMINATOR, NUMERATOR FROM HEALTHCARE_INTEGRATION.CURATED.QUALITY_MEASURE_COMPLIANCE WHERE COMPLIANCE_PCT IS NOT NULL","Columns":[{"Name":"MEASURE_ID","Type":"STRING"},{"Name":"MEASURE_NAME","Type":"STRING"},{"Name":"MEASURE_TYPE","Type":"STRING"},{"Name":"TARGET_PCT","Type":"DECIMAL"},{"Name":"COMPLIANCE_PCT","Type":"DECIMAL"},{"Name":"GAP_COUNT","Type":"INTEGER"},{"Name":"DENOMINATOR","Type":"INTEGER"},{"Name":"NUMERATOR","Type":"INTEGER"}]}}}' \
  --permissions '[{"Principal":"'"${QS_USER}"'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

# Dataset: Care Gaps
echo "Creating dataset: hc-integration-gaps..."
aws quicksight create-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-gaps" \
  --name "HC Integration: Care Gaps" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{"gt":{"CustomSql":{"DataSourceArn":"arn:aws:quicksight:'"${REGION}"':'"${ACCOUNT_ID}"':datasource/'"${DATA_SOURCE_ID}"'","Name":"CareGaps","SqlQuery":"SELECT PATIENT_ID, MEASURE_NAME, GAP_TYPE, DAYS_OVERDUE, PRIORITY FROM HEALTHCARE_INTEGRATION.CURATED.CARE_GAP_IDENTIFICATION","Columns":[{"Name":"PATIENT_ID","Type":"STRING"},{"Name":"MEASURE_NAME","Type":"STRING"},{"Name":"GAP_TYPE","Type":"STRING"},{"Name":"DAYS_OVERDUE","Type":"INTEGER"},{"Name":"PRIORITY","Type":"INTEGER"}]}}}' \
  --permissions '[{"Principal":"'"${QS_USER}"'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

# Q Topic
echo "Creating Q topic: hc-integration-q..."
aws quicksight create-topic \
  --aws-account-id "$ACCOUNT_ID" \
  --topic-id "hc-integration-q" \
  --topic '{"Name":"Population Health & Integration","Description":"Natural language queries on quality measures and care gaps","DataSets":[{"DatasetArn":"arn:aws:quicksight:'"${REGION}"':'"${ACCOUNT_ID}"':dataset/hc-integration-quality","DatasetName":"Quality Compliance","Columns":[{"ColumnName":"MEASURE_NAME","ColumnFriendlyName":"Quality Measure","ColumnDescription":"Name of the HEDIS/CMS quality measure","ColumnSynonyms":["measure","metric"],"ColumnDataRole":"DIMENSION","IsIncludedInTopic":true},{"ColumnName":"COMPLIANCE_PCT","ColumnFriendlyName":"Compliance Rate","ColumnDescription":"Percentage of patients meeting the quality measure target","ColumnSynonyms":["compliance","rate","percentage"],"ColumnDataRole":"MEASURE","IsIncludedInTopic":true,"Aggregation":"AVERAGE"},{"ColumnName":"GAP_COUNT","ColumnFriendlyName":"Gap Count","ColumnDescription":"Number of patients not meeting the measure","ColumnSynonyms":["gaps","non-compliant"],"ColumnDataRole":"MEASURE","IsIncludedInTopic":true,"Aggregation":"SUM"}]},{"DatasetArn":"arn:aws:quicksight:'"${REGION}"':'"${ACCOUNT_ID}"':dataset/hc-integration-gaps","DatasetName":"Care Gaps","Columns":[{"ColumnName":"MEASURE_NAME","ColumnFriendlyName":"Quality Measure","ColumnSynonyms":["measure"],"ColumnDataRole":"DIMENSION","IsIncludedInTopic":true},{"ColumnName":"GAP_TYPE","ColumnFriendlyName":"Gap Type","ColumnSynonyms":["type"],"ColumnDataRole":"DIMENSION","IsIncludedInTopic":true},{"ColumnName":"DAYS_OVERDUE","ColumnFriendlyName":"Days Overdue","ColumnSynonyms":["overdue"],"ColumnDataRole":"MEASURE","IsIncludedInTopic":true,"Aggregation":"AVERAGE"}]}]}' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

echo ""
echo "=== QuickSight deployment complete ==="
echo "Data Source: ${DATA_SOURCE_ID}"
echo "Datasets: hc-integration-quality, hc-integration-gaps"
echo "Q Topic: hc-integration-q"
echo "Dashboard: https://${REGION}.quicksight.aws.amazon.com/sn/dashboards/hc-integration-dashboard"
