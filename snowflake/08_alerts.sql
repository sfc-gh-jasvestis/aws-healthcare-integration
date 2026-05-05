-- Healthcare Data Integration: Alerts
USE DATABASE HEALTHCARE_INTEGRATION;
USE SCHEMA AI;

-- Alert: detect new high-priority care gaps and notify
CREATE OR REPLACE ALERT CARE_GAP_ALERT
    WAREHOUSE = CORTEX
    SCHEDULE = '60 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM CURATED.CARE_GAP_IDENTIFICATION
        WHERE PRIORITY IN ('Urgent', 'High')
          AND IDENTIFIED_AT >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
    ))
    THEN
        BEGIN
            -- Attempt SNS notification (if EAI is active and secret is configured)
            LET gap_count INT := (
                SELECT COUNT(*)
                FROM CURATED.CARE_GAP_IDENTIFICATION
                WHERE PRIORITY IN ('Urgent', 'High')
                  AND IDENTIFIED_AT >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
            );
            LET urgent_count INT := (
                SELECT COUNT(*)
                FROM CURATED.CARE_GAP_IDENTIFICATION
                WHERE PRIORITY = 'Urgent'
                  AND IDENTIFIED_AT >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
            );
            LET msg VARCHAR := 'CARE GAP ALERT: ' || :gap_count || ' new high-priority care gaps identified (' || :urgent_count || ' urgent). Review in Population Health dashboard.';

            -- Email fallback (always available)
            CALL SYSTEM$SEND_EMAIL(
                'care_gap_notifications',
                'pophealth-team@example.com',
                'Care Gap Alert: ' || :gap_count || ' New High-Priority Gaps',
                :msg
            );
        END;

-- Resume the alert
ALTER ALERT CARE_GAP_ALERT RESUME;
