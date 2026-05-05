-- Healthcare Data Integration: Semantic View
USE DATABASE HEALTHCARE_INTEGRATION;
USE SCHEMA AI;

CREATE OR REPLACE SEMANTIC VIEW INTEGRATION_SEMANTIC_VIEW
  COMMENT = 'Population health analytics: quality compliance, patient risk, and care gaps'
AS
  TABLES (
    CURATED.QUALITY_MEASURE_COMPLIANCE AS quality_compliance
      COMMENT = 'Quality measure compliance rates by HEDIS/CMS measure'
      PRIMARY KEY (MEASURE_ID)
      WITH COLUMNS (
        MEASURE_ID COMMENT = 'Unique measure identifier',
        MEASURE_CODE COMMENT = 'NQF measure code (e.g. NQF-0059)',
        MEASURE_NAME COMMENT = 'Human-readable measure name',
        CATEGORY COMMENT = 'Measure category: Effectiveness, Prevention, Treatment, Coordination',
        TARGET_PERCENTAGE COMMENT = 'Target compliance percentage',
        ELIGIBLE_PATIENTS COMMENT = 'Number of patients eligible for this measure',
        COMPLIANT_PATIENTS COMMENT = 'Number of patients meeting the measure',
        COMPLIANCE_PERCENTAGE COMMENT = 'Current compliance rate as percentage',
        GAP_COUNT COMMENT = 'Number of patients with care gaps for this measure',
        STATUS COMMENT = 'Met, Near Target, or Below Target'
      ),
    CURATED.PATIENT_RISK_SCORES AS patient_risk
      COMMENT = 'Composite risk scores per patient based on conditions, labs, and utilization'
      PRIMARY KEY (PATIENT_ID)
      WITH COLUMNS (
        PATIENT_ID COMMENT = 'Unique patient identifier',
        FIRST_NAME COMMENT = 'Patient first name',
        LAST_NAME COMMENT = 'Patient last name',
        FACILITY COMMENT = 'Primary care facility',
        RISK_TIER COMMENT = 'Risk tier: Critical, High, Medium, Low',
        PRIMARY_CONDITION COMMENT = 'Primary chronic condition',
        CONDITION_COUNT COMMENT = 'Number of active conditions',
        READMISSION_COUNT COMMENT = 'Number of readmissions',
        AVG_HBA1C COMMENT = 'Average HbA1c value (diabetes patients)',
        AVG_SYSTOLIC_BP COMMENT = 'Average systolic blood pressure',
        COMPOSITE_RISK_SCORE COMMENT = 'Composite risk score (higher = more at risk)'
      ),
    CURATED.CARE_GAP_IDENTIFICATION AS care_gaps
      COMMENT = 'Identified care gaps by patient and quality measure with priority'
      PRIMARY KEY (PATIENT_ID, MEASURE_ID)
      WITH COLUMNS (
        PATIENT_ID COMMENT = 'Patient with identified gap',
        PATIENT_NAME COMMENT = 'Full name of patient',
        FACILITY COMMENT = 'Patient facility',
        RISK_TIER COMMENT = 'Patient risk tier',
        MEASURE_ID COMMENT = 'Quality measure with gap',
        MEASURE_CODE COMMENT = 'NQF code of the measure',
        MEASURE_NAME COMMENT = 'Name of the quality measure',
        PRIORITY COMMENT = 'Gap priority: Urgent, High, Medium, Low',
        LAST_VALUE COMMENT = 'Last recorded value for the measure',
        DAYS_SINCE_LAST COMMENT = 'Days since last measurement'
      )
  )
  RELATIONSHIPS (
    care_gaps.PATIENT_ID REFERENCES patient_risk.PATIENT_ID,
    care_gaps.MEASURE_ID REFERENCES quality_compliance.MEASURE_ID
  );
