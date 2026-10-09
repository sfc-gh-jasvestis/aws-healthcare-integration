-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live bundle alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_BUNDLES.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic integration runbooks (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.FEED_SOP_DOCS AS
WITH issues AS (
  SELECT DISTINCT r.ISSUE_TYPE, f.CATEGORY
  FROM RAW.FEED_DAILY r JOIN RAW.FACILITIES f ON f.ID = r.ENTITY_ID
  WHERE r.INCIDENT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ISSUE_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ISSUE_TYPE,
  CATEGORY || ' feed - ' || ISSUE_TYPE || ' incident runbook' AS TITLE,
  'Synthetic demo SOP for FHIR feed operations; not clinical or regulatory guidance. Source type: ' || CATEGORY
  || '. Data quality issue: ' || ISSUE_TYPE || '. '
  || 'Step 1: log the issue in the integration tracker and notify the facility interface contact within 1 business day. '
  || 'Step 2: ' || CASE
       WHEN ISSUE_TYPE = 'Missing reference' THEN 'list rejected bundles whose resource references do not resolve within the bundle or the exchange, and confirm the sending system includes every referenced resource.'
       WHEN ISSUE_TYPE = 'Invalid terminology code' THEN 'compare rejected coded elements with the agreed value sets and ask the facility to correct the code system or version it sends.'
       WHEN ISSUE_TYPE = 'Date sequence error' THEN 'check bundles where an end date precedes a start date or a record is dated in the future, and confirm the source system time zone settings.'
       WHEN ISSUE_TYPE = 'Duplicate identifier' THEN 'review bundles that reuse a business identifier for different resources and confirm the identifier system with the facility.'
       WHEN ISSUE_TYPE = 'Unmapped local code' THEN 'export local codes without a standard mapping, update the terminology map, and replay the affected bundles.'
       WHEN ISSUE_TYPE = 'Schema conformance' THEN 'validate a sample of rejected bundles against the agreed profiles and share the validator output with the facility.'
       ELSE 'review the flagged bundles against the facility profile and escalate if unexplained.'
     END
  || ' Step 3: if more than 6% of coded elements stay unmapped or feed latency stays above 5 hours after follow-up, schedule an interface conformance check. '
  || 'Step 4: record the root cause; if the issue is confirmed as an interface incident, open a remediation ticket for the integration lead to approve.' AS CONTENT
FROM issues;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.FEED_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ISSUE_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ISSUE_TYPE, CONTENT FROM SEARCH.FEED_SOP_DOCS);

-- ---------- Unmapped code rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.UNMAPPED_CODE_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, UNMAPPED_CODE_PCT::FLOAT AS UNMAPPED_CODE
FROM RAW.FEED_DAILY;
CREATE OR REPLACE VIEW ML.UNMAPPED_CODE_TRAIN AS
SELECT * FROM ML.UNMAPPED_CODE_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.UNMAPPED_CODE_SERIES);
CREATE OR REPLACE VIEW ML.UNMAPPED_CODE_DETECT AS
SELECT * FROM ML.UNMAPPED_CODE_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.UNMAPPED_CODE_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.UNMAPPED_CODE_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.UNMAPPED_CODE_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'UNMAPPED_CODE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.UNMAPPED_CODE_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS UNMAPPED_CODE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.UNMAPPED_CODE_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.UNMAPPED_CODE_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'UNMAPPED_CODE'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.HIE_ANALYTICS
  TABLES (
    facilities AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per connected facility (entity), 90-day feed totals',
    risk AS ML.INCIDENT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day interface incident probability per facility',
    issues AS CURATED.ISSUE_SUMMARY PRIMARY KEY (ISSUE_TYPE)
      COMMENT = 'Data quality issues, interface incidents and tickets by issue type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_facility AS risk (ENTITY_ID) REFERENCES facilities)
  FACTS (
    facilities.received_f AS BUNDLES_RECEIVED,
    facilities.accepted_f AS BUNDLES_ACCEPTED,
    facilities.expected_f AS EXPECTED_BUNDLES_90D,
    facilities.issues_f AS ISSUE_COUNT,
    facilities.incidents_f AS INCIDENT_COUNT,
    facilities.tickets_f AS TICKET_COUNT,
    facilities.checks_due_f AS CHECKS_DUE,
    facilities.checks_done_f AS CHECKS_COMPLETED,
    facilities.entity_one_f AS 1,
    risk.incident_prob_f AS INCIDENT_PROB_7D,
    issues.type_issues_f AS ISSUE_COUNT,
    issues.type_incidents_f AS INCIDENT_COUNT,
    issues.type_tickets_f AS TICKET_COUNT,
    daily.day_received_f AS BUNDLES_RECEIVED,
    daily.day_accepted_f AS BUNDLES_ACCEPTED,
    daily.day_issues_f AS ISSUE_COUNT
  )
  DIMENSIONS (
    facilities.facility_id AS ENTITY_ID WITH SYNONYMS = ('facility', 'entity', 'source', 'data source'),
    facilities.facility_name AS ENTITY_NAME,
    facilities.market AS REGION WITH SYNONYMS = ('market', 'country', 'region') COMMENT = 'APJ market where the facility is located',
    facilities.source_type AS CATEGORY WITH SYNONYMS = ('source type', 'facility type', 'sending system type'),
    facilities.integration_tier AS INTEGRATION_TIER COMMENT = 'Integration support tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    issues.issue_type AS ISSUE_TYPE WITH SYNONYMS = ('issue', 'data quality issue', 'validation error type'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    facilities.entity_count AS SUM(facilities.entity_one_f) WITH SYNONYMS = ('entities', 'number of entities', 'facilities', 'number of facilities')
      COMMENT = 'Number of connected facilities (entities)',
    facilities.total_accepted AS SUM(facilities.accepted_f) WITH SYNONYMS = ('accepted bundles', 'bundles accepted'),
    facilities.total_received AS SUM(facilities.received_f) WITH SYNONYMS = ('received bundles', 'bundles received'),
    facilities.feed_completeness_pct AS 100 * SUM(facilities.accepted_f) / NULLIF(SUM(facilities.expected_f), 0)
      COMMENT = 'Bundles accepted / bundles expected for the 90-day window',
    facilities.bundle_rejection_pct AS 100 * (SUM(facilities.received_f) - SUM(facilities.accepted_f)) / NULLIF(SUM(facilities.received_f), 0)
      COMMENT = 'Bundles received but rejected by FHIR validation / bundles received',
    facilities.issue_escalation_pct AS 100 * SUM(facilities.incidents_f) / NULLIF(SUM(facilities.issues_f), 0)
      COMMENT = 'Interface incidents / data quality issues raised',
    facilities.data_quality_issues AS SUM(facilities.issues_f) WITH SYNONYMS = ('issues', 'flags'),
    facilities.interface_incidents AS SUM(facilities.incidents_f) WITH SYNONYMS = ('incidents', 'feed incidents'),
    facilities.tickets_opened AS SUM(facilities.tickets_f) WITH SYNONYMS = ('tickets', 'remediation tickets'),
    facilities.check_compliance_pct AS 100 * SUM(facilities.checks_done_f) / NULLIF(SUM(facilities.checks_due_f), 0)
      COMMENT = 'Conformance checks completed / conformance checks due',
    risk.avg_incident_prob AS AVG(risk.incident_prob_f),
    issues.type_issues AS SUM(issues.type_issues_f),
    issues.type_incidents AS SUM(issues.type_incidents_f),
    issues.type_tickets AS SUM(issues.type_tickets_f),
    issues.type_escalation_pct AS 100 * SUM(issues.type_incidents_f) / NULLIF(SUM(issues.type_issues_f), 0),
    daily.daily_received AS SUM(daily.day_received_f),
    daily.daily_accepted AS SUM(daily.day_accepted_f),
    daily.daily_issues AS SUM(daily.day_issues_f)
  )
  COMMENT = 'Synthetic FHIR feed integration analytics (demo; facility-level aggregates, no patient data)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.HIE_AGENT
  COMMENT = 'Feed operations assistant over a synthetic regional health information exchange'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give facility IDs and numbers with units. Do not give medical or clinical advice; this is integration operations data only."
  orchestration: "Use hie_analyst for bundles received and accepted, feed completeness, rejections, data quality issues, interface incidents, tickets, conformance check compliance, facilities (entities), markets, source types and incident risk. Use sop_search for follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: hie_analyst
      description: "Feed completeness, bundle rejections, data quality issues, interface incidents, tickets, conformance check compliance, issue types and incident risk scores per facility"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic FHIR feed operations SOPs by source type and data quality issue type"
tool_resources:
  hie_analyst:
    semantic_view: __DEMO_DB__.APP.HIE_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.FEED_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live bundle alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), FACILITY_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, LATENCY_MIN FLOAT, UNMAPPED_CODE_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION APJ_HIE_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (FACILITY_ID, EVENT_TS, LATENCY_MIN, UNMAPPED_CODE_PCT, SOP_HINT)
    SELECT v.FACILITY_ID, v.EVENT_TS, v.LATENCY_MIN, v.UNMAPPED_CODE_PCT,
           'Check ' || f.CATEGORY || ' feed runbooks; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_BUNDLES v
    JOIN RAW.FACILITIES f ON f.ID = v.FACILITY_ID
    LEFT JOIN ML.INCIDENT_RISK_SCORES r ON r.ENTITY_ID = v.FACILITY_ID
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.FACILITY_ID = v.FACILITY_ID AND l.EVENT_TS = v.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('APJ_HIE_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] FHIR feed operations alert',
      'New bundle delivery alerts logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_BUNDLE_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_BUNDLES v
    WHERE v.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.FACILITY_ID = v.FACILITY_ID AND l.EVENT_TS = v.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.ISSUE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.INCIDENT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.INCIDENT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.INCIDENT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'INTEGRATION_TIER', INTEGRATION_TIER, 'YEARS_CONNECTED', YEARS_CONNECTED,
             'UNMAPPED_CODE_PCT', UNMAPPED_CODE_PCT, 'FEED_LATENCY_HRS', FEED_LATENCY_HRS,
             'UNMAPPED_CODE_7D', UNMAPPED_CODE_7D, 'INCIDENTS_30D', INCIDENTS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:INCIDENT::FLOAT, 4) AS INCIDENT_PROB_7D,
         CASE WHEN PRED:probability:INCIDENT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:INCIDENT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
