-- Synthetic facility-day FHIR feed data for a fictional regional health information exchange.
-- Facility-level aggregate counts only: there are no patient records, no patient
-- identifiers and no clinical content. Nothing is seeded as a prediction.
-- Randomness is HASH-seeded, so every rebuild is reproducible: per-facility
-- interface incident propensity, drift between scheduled conformance checks,
-- missed checks, source-type-weighted data quality issues, issues that are not
-- escalated to incidents, and two regional network outages.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.FACILITIES AS
WITH facilities AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS FACILITY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT FACILITY_INDEX,
         MOD(ABS(HASH(FACILITY_INDEX, 'experience')), 1000000) / 1e6 AS U_EXPERIENCE,
         MOD(ABS(HASH(FACILITY_INDEX, 'incident')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(FACILITY_INDEX, 'checks')), 1000000) / 1e6 AS U_CHECKS,
         MOD(ABS(HASH(FACILITY_INDEX, 'discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(FACILITY_INDEX, 'tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(FACILITY_INDEX, 'volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(FACILITY_INDEX, 'expected')), 1000000) / 1e6 AS U_PLAN
  FROM facilities
), sized AS (
  SELECT *,
         -- Deterministic spread (5 and 8 are coprime): every market and
         -- source type is present.
         CASE MOD(FACILITY_INDEX, 5) WHEN 0 THEN 'Singapore' WHEN 1 THEN 'Sydney'
              WHEN 2 THEN 'Seoul' WHEN 3 THEN 'Tokyo' ELSE 'Taipei' END AS REGION,
         CASE MOD(FACILITY_INDEX, 8) WHEN 0 THEN 'Hospital' WHEN 1 THEN 'Hospital' WHEN 2 THEN 'Hospital'
              WHEN 3 THEN 'Primary care' WHEN 4 THEN 'Primary care' WHEN 5 THEN 'Laboratory'
              WHEN 6 THEN 'Pharmacy' ELSE 'Imaging' END AS CATEGORY,
         -- Mean FHIR bundles received per day from the facility.
         40 + U_VOLUME * 160 AS BUNDLE_RATE
  FROM draws
)
SELECT 'FAC-' || LPAD(FACILITY_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic facility ' || LPAD(FACILITY_INDEX::VARCHAR, 4, '0') AS NAME,
       REGION, CATEGORY, FACILITY_INDEX,
       1 + FLOOR(U_TIER * 3) AS INTEGRATION_TIER,
       ROUND(0.2 + U_EXPERIENCE * 5.8, 1) AS YEARS_CONNECTED,
       BUNDLE_RATE,
       -- Expected bundles for the 90-day window (synthetic volume agreement).
       ROUND(BUNDLE_RATE * 90 * (0.95 + 0.15 * U_PLAN)) AS EXPECTED_BUNDLES_90D,
       -- Base daily probability of an interface incident 0.4%-3%;
       -- ~15% of facilities are persistent outliers (x3).
       (0.004 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_INCIDENT_RATE,
       7 * (1 + FLOOR(U_CHECKS * 3)) AS CHECK_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS CHECK_COMPLETION_PROB,
       'Connected' AS STATUS
FROM sized;

CREATE TABLE RAW.FEED_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two regional network outages; every facility in the market raises an issue.
  SELECT * FROM VALUES (27, 'Seoul'), (64, 'Singapore') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT f.ID AS ENTITY_ID, f.FACILITY_INDEX, f.CATEGORY, f.REGION, f.YEARS_CONNECTED, f.BUNDLE_RATE,
         f.BASE_INCIDENT_RATE, f.CHECK_INTERVAL_DAYS, f.CHECK_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + f.FACILITY_INDEX * 5, f.CHECK_INTERVAL_DAYS) AS DAYS_SINCE_CHECK,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'incident')), 1000000) / 1e6 AS U_INC,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'not escalated')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'issue')), 1000000) / 1e6 AS U_ISSUE,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'check')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'received')), 1000000) / 1e6 AS U_RECEIVED,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'accepted')), 1000000) / 1e6 AS U_ACCEPTED,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(f.ID, d.DAY_INDEX, 'ticket')), 1000000) / 1e6 AS U_TICKET,
         e.REGION IS NOT NULL AS REGIONAL_EVENT
  FROM RAW.FACILITIES f CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = f.REGION
), checks AS (
  SELECT *,
         IFF(DAYS_SINCE_CHECK = 0, 1, 0) AS CHECKS_DUE,
         IFF(DAYS_SINCE_CHECK = 0 AND U_DONE < CHECK_COMPLETION_PROB, 1, 0) AS CHECKS_COMPLETED,
         -- Mapping drift rises between conformance checks; weak follow-through carries it over.
         DAYS_SINCE_CHECK / CHECK_INTERVAL_DAYS + (1 - CHECK_COMPLETION_PROB) AS DRIFT
  FROM base
), incidents AS (
  SELECT *,
         CASE WHEN U_INC < LEAST(0.5, BASE_INCIDENT_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + YEARS_CONNECTED))) / 4 THEN 2
              WHEN U_INC < LEAST(0.5, BASE_INCIDENT_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + YEARS_CONNECTED))) THEN 1
              ELSE 0 END AS INCIDENT_EVENTS
  FROM checks
), issues AS (
  SELECT *,
         -- Feed monitoring catches about 85% of interface incidents.
         IFF(REGIONAL_EVENT, 0, IFF(U_DETECT < 0.85, INCIDENT_EVENTS, 0)) AS INCIDENT_COUNT,
         -- Issues resolved without escalation: higher for complex source systems.
         IFF(REGIONAL_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Hospital' THEN 0.14
                                                         WHEN 'Laboratory' THEN 0.10
                                                         WHEN 'Pharmacy' THEN 0.10 ELSE 0.08 END, 1, 0)) AS NON_INCIDENT_COUNT,
         FLOOR(BUNDLE_RATE * (0.4 + 1.2 * U_RECEIVED) + 0.5) AS BUNDLES_RECEIVED
  FROM incidents
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       BUNDLES_RECEIVED,
       -- Bundles that pass FHIR validation; incident days reject more.
       FLOOR(BUNDLES_RECEIVED * (0.90 + 0.09 * U_ACCEPTED) * IFF(INCIDENT_EVENTS > 0, 0.85, 1) + 0.5) AS BUNDLES_ACCEPTED,
       INCIDENT_COUNT + NON_INCIDENT_COUNT AS ISSUE_COUNT,
       INCIDENT_COUNT,
       IFF(INCIDENT_COUNT > 0 AND U_TICKET < 0.6, 1, 0) AS TICKETS_OPENED,
       CASE WHEN INCIDENT_COUNT + NON_INCIDENT_COUNT = 0 THEN 'None'
            WHEN REGIONAL_EVENT THEN 'Regional network outage'
            WHEN CATEGORY = 'Hospital' THEN IFF(U_ISSUE < 0.4, 'Missing reference', IFF(U_ISSUE < 0.75, 'Invalid terminology code', 'Date sequence error'))
            WHEN CATEGORY = 'Primary care' THEN IFF(U_ISSUE < 0.45, 'Date sequence error', IFF(U_ISSUE < 0.8, 'Duplicate identifier', 'Unmapped local code'))
            WHEN CATEGORY = 'Laboratory' THEN IFF(U_ISSUE < 0.55, 'Unmapped local code', 'Invalid terminology code')
            WHEN CATEGORY = 'Pharmacy' THEN IFF(U_ISSUE < 0.45, 'Duplicate identifier', IFF(U_ISSUE < 0.8, 'Date sequence error', 'Missing reference'))
            ELSE IFF(U_ISSUE < 0.5, 'Schema conformance', IFF(U_ISSUE < 0.75, 'Date sequence error', 'Missing reference')) END AS ISSUE_TYPE,
       CHECKS_DUE, CHECKS_COMPLETED,
       -- Coded elements without a standard terminology mapping (%), and feed latency in hours.
       ROUND(1.5 + 2.5 * DRIFT + 4.0 * INCIDENT_EVENTS + U_NOISE * 1.2, 2) AS UNMAPPED_CODE_PCT,
       ROUND(1.0 + 2.0 * DRIFT + 3.0 * INCIDENT_EVENTS + U_NOISE * 1.5, 1) AS FEED_LATENCY_HRS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM issues;

-- FHIR profile conformance per facility (snapshot): profiles required for the
-- facility's main resource type, profiles passing conformance, and pending reviews.
CREATE TABLE RAW.PROFILE_CONFORMANCE AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Hospital' THEN 'Encounter' WHEN 'Primary care' THEN 'Condition'
                     WHEN 'Laboratory' THEN 'Observation'
                     WHEN 'Pharmacy' THEN 'MedicationRequest' ELSE 'DiagnosticReport' END AS RESOURCE_TYPE,
       1 + MOD(ABS(HASH(ID, 'required')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'conformant')), 5) AS CONFORMANT_QTY,
       IFF(MOD(ABS(HASH(ID, 'conformant')), 5) < 1 + MOD(ABS(HASH(ID, 'required')), 4),
           MOD(ABS(HASH(ID, 'pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.FACILITIES;
