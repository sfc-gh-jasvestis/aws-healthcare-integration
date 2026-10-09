-- ============================================================================
-- 08_native_bundles.sql - Snowflake-only build: live FHIR bundle feed without AWS.
-- Creates RAW.LIVE_BUNDLES (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_BUNDLES(N), which inserts synthetic
-- FHIR bundle delivery events (facility-level, no patient identifiers) with the same value ranges
-- and ~10% ALERT rate as aws/publish_bundles.py. Rows are inserted directly;
-- this simulates an interface engine feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_BUNDLES).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_BUNDLES (
  FACILITY_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, LATENCY_MIN FLOAT, UNMAPPED_CODE_PCT FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_BUNDLES(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_BUNDLES (FACILITY_ID, EVENT_TS, LATENCY_MIN, UNMAPPED_CODE_PCT, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'FAC-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS FACILITY_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_ALERT,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the alert offset is added outside it.
    SELECT FACILITY_ID, TS,
           ROUND(IFF(IS_ALERT, 120, 18) * EXP(NORMAL(0, 0.5, RANDOM())), 1),
           ROUND(GREATEST(0, IFF(IS_ALERT, 9.5, 2.5) + NORMAL(0, 1.0, RANDOM())), 2),
           IFF(IS_ALERT, 'ALERT', 'OK'), TS, 'APP.SIMULATE_BUNDLES'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_BUNDLES
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_BUNDLES(5);
