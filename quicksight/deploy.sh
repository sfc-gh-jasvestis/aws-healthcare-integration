#!/bin/bash
# QuickSight Deployment: Healthcare Data Integration
# Creates datasets and Q topic for population health analytics

set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
QS_USER="arn:aws:quicksight:${REGION}:${ACCOUNT_ID}:user/default/Admin/YOUR_USER"
DATA_SOURCE_ID="healthcare-snowflake-ds"

echo "=== Deploying QuickSight Resources: Healthcare Data Integration ==="

# Dataset: Quality Measures Compliance
echo "Creating dataset: hc-integration-quality..."
aws quicksight create-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-quality" \
  --name "Healthcare Integration - Quality Compliance" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{
    "quality-compliance": {
      "CustomSql": {
        "DataSourceArn": "arn:aws:quicksight:'${REGION}':'${ACCOUNT_ID}':datasource/'${DATA_SOURCE_ID}'",
        "Name": "QualityCompliance",
        "SqlQuery": "SELECT MEASURE_CODE, MEASURE_NAME, CATEGORY, TARGET_PERCENTAGE, COMPLIANCE_PERCENTAGE, GAP_COUNT, STATUS FROM HEALTHCARE_INTEGRATION.CURATED.QUALITY_MEASURE_COMPLIANCE",
        "Columns": [
          {"Name": "MEASURE_CODE", "Type": "STRING"},
          {"Name": "MEASURE_NAME", "Type": "STRING"},
          {"Name": "CATEGORY", "Type": "STRING"},
          {"Name": "TARGET_PERCENTAGE", "Type": "DECIMAL"},
          {"Name": "COMPLIANCE_PERCENTAGE", "Type": "DECIMAL"},
          {"Name": "GAP_COUNT", "Type": "INTEGER"},
          {"Name": "STATUS", "Type": "STRING"}
        ]
      }
    }
  }' \
  --permissions '[{"Principal":"'${QS_USER}'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

# Dataset: Care Gaps
echo "Creating dataset: hc-integration-gaps..."
aws quicksight create-data-set \
  --aws-account-id "$ACCOUNT_ID" \
  --data-set-id "hc-integration-gaps" \
  --name "Healthcare Integration - Care Gaps" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{
    "care-gaps": {
      "CustomSql": {
        "DataSourceArn": "arn:aws:quicksight:'${REGION}':'${ACCOUNT_ID}':datasource/'${DATA_SOURCE_ID}'",
        "Name": "CareGaps",
        "SqlQuery": "SELECT PATIENT_ID, PATIENT_NAME, FACILITY, RISK_TIER, MEASURE_CODE, MEASURE_NAME, PRIORITY, LAST_VALUE, DAYS_SINCE_LAST FROM HEALTHCARE_INTEGRATION.CURATED.CARE_GAP_IDENTIFICATION",
        "Columns": [
          {"Name": "PATIENT_ID", "Type": "STRING"},
          {"Name": "PATIENT_NAME", "Type": "STRING"},
          {"Name": "FACILITY", "Type": "STRING"},
          {"Name": "RISK_TIER", "Type": "STRING"},
          {"Name": "MEASURE_CODE", "Type": "STRING"},
          {"Name": "MEASURE_NAME", "Type": "STRING"},
          {"Name": "PRIORITY", "Type": "STRING"},
          {"Name": "LAST_VALUE", "Type": "DECIMAL"},
          {"Name": "DAYS_SINCE_LAST", "Type": "INTEGER"}
        ]
      }
    }
  }' \
  --permissions '[{"Principal":"'${QS_USER}'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

# Q Topic
echo "Creating Q topic: hc-integration-q..."
aws quicksight create-topic \
  --aws-account-id "$ACCOUNT_ID" \
  --topic-id "hc-integration-q" \
  --topic '{
    "Name": "Healthcare Integration Q",
    "Description": "Natural language queries for population health quality measures and care gaps",
    "DataSets": [
      {
        "DatasetArn": "arn:aws:quicksight:'${REGION}':'${ACCOUNT_ID}':dataset/hc-integration-quality",
        "DatasetName": "Quality Compliance"
      },
      {
        "DatasetArn": "arn:aws:quicksight:'${REGION}':'${ACCOUNT_ID}':dataset/hc-integration-gaps",
        "DatasetName": "Care Gaps"
      }
    ]
  }' \
  --region "$REGION" 2>/dev/null && echo "  Created." || echo "  Already exists."

echo ""
echo "=== QuickSight deployment complete ==="
echo "Datasets: hc-integration-quality, hc-integration-gaps"
echo "Q Topic: hc-integration-q"
