-- Healthcare Data Integration: External Integrations
USE DATABASE HEALTHCARE_INTEGRATION;
USE SCHEMA RAW;

-- S3 Stage for FHIR bundle ingestion
CREATE OR REPLACE STAGE INTEGRATION_S3_STAGE
    STORAGE_INTEGRATION = HEALTHCARE_DEMOS_S3_INTEGRATION
    URL = 's3://sg-healthcare-demos-2026/integration/'
    FILE_FORMAT = (TYPE = JSON);

-- Snowpipe for auto-ingesting FHIR bundles from S3
CREATE OR REPLACE PIPE FHIR_BUNDLE_PIPE
    AUTO_INGEST = TRUE
    AS
    COPY INTO RAW.FHIR_INGEST_RAW
    FROM @INTEGRATION_S3_STAGE/fhir-bundles/
    FILE_FORMAT = (TYPE = JSON)
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- SNS External Access Integration for care gap alerts
CREATE OR REPLACE NETWORK RULE SNS_CARE_GAP_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('sns.us-west-2.amazonaws.com');

CREATE OR REPLACE SECRET SNS_CARE_GAP_SECRET
    TYPE = GENERIC_STRING
    SECRET_STRING = '{"aws_access_key_id":"REPLACE_ME","aws_secret_access_key":"REPLACE_ME"}';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SNS_CARE_GAP_EAI
    ALLOWED_NETWORK_RULES = (SNS_CARE_GAP_NETWORK_RULE)
    ALLOWED_AUTHENTICATION_SECRETS = (SNS_CARE_GAP_SECRET)
    ENABLED = TRUE;

-- UDF to publish SNS alerts for care gaps
CREATE OR REPLACE FUNCTION RAW.PUBLISH_SNS_ALERT(
    TOPIC_ARN VARCHAR,
    SUBJECT VARCHAR,
    MESSAGE VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'publish_alert'
EXTERNAL_ACCESS_INTEGRATIONS = (SNS_CARE_GAP_EAI)
SECRETS = ('aws_creds' = SNS_CARE_GAP_SECRET)
PACKAGES = ('boto3')
AS
$$
import boto3
import json
import _snowflake

def publish_alert(topic_arn, subject, message):
    creds = json.loads(_snowflake.get_generic_secret_string('aws_creds'))
    client = boto3.client(
        'sns',
        region_name='us-west-2',
        aws_access_key_id=creds['aws_access_key_id'],
        aws_secret_access_key=creds['aws_secret_access_key']
    )
    response = client.publish(
        TopicArn=topic_arn,
        Subject=subject,
        Message=message
    )
    return response['MessageId']
$$;
