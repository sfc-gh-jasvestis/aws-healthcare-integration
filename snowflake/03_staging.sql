-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.FEED_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.FEED_DAILY observation
    LEFT JOIN RAW.FACILITIES facility ON facility.ID = observation.ENTITY_ID
    WHERE facility.ID IS NULL OR observation.BUNDLES_RECEIVED < 0
       OR observation.BUNDLES_ACCEPTED < 0 OR observation.BUNDLES_ACCEPTED > observation.BUNDLES_RECEIVED
       OR observation.INCIDENT_COUNT < 0 OR observation.INCIDENT_COUNT > observation.ISSUE_COUNT
       OR observation.TICKETS_OPENED > observation.INCIDENT_COUNT
       OR observation.CHECKS_COMPLETED > observation.CHECKS_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
