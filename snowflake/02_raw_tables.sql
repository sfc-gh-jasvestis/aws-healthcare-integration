-- Healthcare Data Integration: Raw Tables with Synthetic Data
USE DATABASE HEALTHCARE_INTEGRATION;
USE SCHEMA RAW;

-- FHIR ingest landing table (for Snowpipe)
CREATE OR REPLACE TABLE FHIR_INGEST_RAW (
    RAW_DATA VARIANT,
    FILENAME VARCHAR,
    FILE_ROW_NUMBER INT,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

------------------------------------------------------------
-- PATIENTS (5,000 — APJ region names, risk tiers)
------------------------------------------------------------
CREATE OR REPLACE TABLE PATIENTS (
    PATIENT_ID VARCHAR(20),
    FIRST_NAME VARCHAR(50),
    LAST_NAME VARCHAR(50),
    DATE_OF_BIRTH DATE,
    GENDER VARCHAR(10),
    ETHNICITY VARCHAR(30),
    FACILITY VARCHAR(50),
    RISK_TIER VARCHAR(20),
    PRIMARY_CONDITION VARCHAR(50),
    INSURANCE_TYPE VARCHAR(30),
    CREATED_AT TIMESTAMP_NTZ
);

INSERT INTO PATIENTS
SELECT
    'PAT-I-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS PATIENT_ID,
    CASE MOD(SEQ4(), 40)
        WHEN 0 THEN 'Hiroshi' WHEN 1 THEN 'Yuki' WHEN 2 THEN 'Kenji' WHEN 3 THEN 'Sakura'
        WHEN 4 THEN 'Takeshi' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Riku' WHEN 7 THEN 'Aiko'
        WHEN 8 THEN 'Wei' WHEN 9 THEN 'Jing' WHEN 10 THEN 'Priya' WHEN 11 THEN 'Arjun'
        WHEN 12 THEN 'Suki' WHEN 13 THEN 'Haruto' WHEN 14 THEN 'Ananya' WHEN 15 THEN 'Raj'
        WHEN 16 THEN 'Yuna' WHEN 17 THEN 'Daiki' WHEN 18 THEN 'Sora' WHEN 19 THEN 'Hana'
        WHEN 20 THEN 'Jin' WHEN 21 THEN 'Mika' WHEN 22 THEN 'Chen' WHEN 23 THEN 'Lin'
        WHEN 24 THEN 'Kira' WHEN 25 THEN 'Taro' WHEN 26 THEN 'Niko' WHEN 27 THEN 'Ava'
        WHEN 28 THEN 'Kai' WHEN 29 THEN 'Ren' WHEN 30 THEN 'Zara' WHEN 31 THEN 'Arun'
        WHEN 32 THEN 'Devi' WHEN 33 THEN 'Omar' WHEN 34 THEN 'Noor' WHEN 35 THEN 'Isla'
        WHEN 36 THEN 'Akira' WHEN 37 THEN 'Liam' WHEN 38 THEN 'Mia' ELSE 'Sato'
    END AS FIRST_NAME,
    CASE MOD(HASH(SEQ4()), 30)
        WHEN 0 THEN 'Tanaka' WHEN 1 THEN 'Suzuki' WHEN 2 THEN 'Watanabe' WHEN 3 THEN 'Takahashi'
        WHEN 4 THEN 'Kim' WHEN 5 THEN 'Park' WHEN 6 THEN 'Lee' WHEN 7 THEN 'Chen'
        WHEN 8 THEN 'Wang' WHEN 9 THEN 'Zhang' WHEN 10 THEN 'Patel' WHEN 11 THEN 'Singh'
        WHEN 12 THEN 'Kumar' WHEN 13 THEN 'Sharma' WHEN 14 THEN 'Nguyen' WHEN 15 THEN 'Tran'
        WHEN 16 THEN 'Yamamoto' WHEN 17 THEN 'Nakamura' WHEN 18 THEN 'Kobayashi' WHEN 19 THEN 'Ito'
        WHEN 20 THEN 'Sato' WHEN 21 THEN 'Wu' WHEN 22 THEN 'Liu' WHEN 23 THEN 'Huang'
        WHEN 24 THEN 'Johnson' WHEN 25 THEN 'Smith' WHEN 26 THEN 'Brown' WHEN 27 THEN 'Wilson'
        WHEN 28 THEN 'Garcia' ELSE 'Martinez'
    END AS LAST_NAME,
    DATEADD(DAY, -UNIFORM(6570, 32850, RANDOM()), CURRENT_DATE()) AS DATE_OF_BIRTH,
    CASE WHEN MOD(SEQ4(), 2) = 0 THEN 'Male' ELSE 'Female' END AS GENDER,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Japanese' WHEN 1 THEN 'Chinese' WHEN 2 THEN 'Indian'
        WHEN 3 THEN 'Korean' ELSE 'Southeast Asian'
    END AS ETHNICITY,
    CASE MOD(SEQ4(), 15)
        WHEN 0 THEN 'Singapore General Hospital' WHEN 1 THEN 'National University Hospital'
        WHEN 2 THEN 'Tan Tock Seng Hospital' WHEN 3 THEN 'Changi General Hospital'
        WHEN 4 THEN 'Khoo Teck Puat Hospital' WHEN 5 THEN 'Ng Teng Fong Hospital'
        WHEN 6 THEN 'Sengkang General Hospital' WHEN 7 THEN 'Alexandra Hospital'
        WHEN 8 THEN 'Mount Elizabeth Hospital' WHEN 9 THEN 'Gleneagles Hospital'
        WHEN 10 THEN 'Raffles Hospital' WHEN 11 THEN 'Thomson Medical Centre'
        WHEN 12 THEN 'Parkway East Hospital' WHEN 13 THEN 'Mount Alvernia Hospital'
        ELSE 'Farrer Park Hospital'
    END AS FACILITY,
    CASE
        WHEN MOD(HASH(SEQ4()), 100) < 10 THEN 'Critical'
        WHEN MOD(HASH(SEQ4()), 100) < 30 THEN 'High'
        WHEN MOD(HASH(SEQ4()), 100) < 60 THEN 'Medium'
        ELSE 'Low'
    END AS RISK_TIER,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Type 2 Diabetes' WHEN 1 THEN 'Hypertension'
        WHEN 2 THEN 'COPD' WHEN 3 THEN 'Heart Failure'
        WHEN 4 THEN 'Chronic Kidney Disease' ELSE 'Asthma'
    END AS PRIMARY_CONDITION,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'MediShield Life' WHEN 1 THEN 'Integrated Shield'
        WHEN 2 THEN 'MediSave' ELSE 'Private'
    END AS INSURANCE_TYPE,
    DATEADD(DAY, -UNIFORM(0, 730, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 5000));

------------------------------------------------------------
-- ENCOUNTERS (50K valid + 3K invalid for FHIR validation)
------------------------------------------------------------
CREATE OR REPLACE TABLE ENCOUNTERS (
    ENCOUNTER_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    ENCOUNTER_TYPE VARCHAR(30),
    FACILITY VARCHAR(50),
    ADMISSION_DATE DATE,
    DISCHARGE_DATE DATE,
    STATUS VARCHAR(20),
    PROVIDER_ID VARCHAR(20),
    DIAGNOSIS_CODE VARCHAR(10),
    IS_READMISSION BOOLEAN,
    FHIR_RESOURCE_TYPE VARCHAR(30) DEFAULT 'Encounter',
    FHIR_REFERENCE VARCHAR(100)
);

-- 50K valid encounters
INSERT INTO ENCOUNTERS
SELECT
    'ENC-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS ENCOUNTER_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Inpatient' WHEN 1 THEN 'Outpatient' WHEN 2 THEN 'Emergency'
        WHEN 3 THEN 'Observation' ELSE 'Telehealth'
    END AS ENCOUNTER_TYPE,
    CASE MOD(SEQ4(), 15)
        WHEN 0 THEN 'Singapore General Hospital' WHEN 1 THEN 'National University Hospital'
        WHEN 2 THEN 'Tan Tock Seng Hospital' WHEN 3 THEN 'Changi General Hospital'
        WHEN 4 THEN 'Khoo Teck Puat Hospital' WHEN 5 THEN 'Ng Teng Fong Hospital'
        WHEN 6 THEN 'Sengkang General Hospital' WHEN 7 THEN 'Alexandra Hospital'
        WHEN 8 THEN 'Mount Elizabeth Hospital' WHEN 9 THEN 'Gleneagles Hospital'
        WHEN 10 THEN 'Raffles Hospital' WHEN 11 THEN 'Thomson Medical Centre'
        WHEN 12 THEN 'Parkway East Hospital' WHEN 13 THEN 'Mount Alvernia Hospital'
        ELSE 'Farrer Park Hospital'
    END AS FACILITY,
    DATEADD(DAY, -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS ADMISSION_DATE,
    DATEADD(DAY, -UNIFORM(0, 360, RANDOM()), CURRENT_DATE()) AS DISCHARGE_DATE,
    'finished' AS STATUS,
    'PROV-' || LPAD(MOD(SEQ4(), 200)::VARCHAR, 4, '0') AS PROVIDER_ID,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'E11.9' WHEN 1 THEN 'I10' WHEN 2 THEN 'J44.1'
        WHEN 3 THEN 'I50.9' WHEN 4 THEN 'N18.3' WHEN 5 THEN 'J45.20'
        WHEN 6 THEN 'E11.65' ELSE 'I25.10'
    END AS DIAGNOSIS_CODE,
    CASE WHEN MOD(HASH(SEQ4()), 100) < 7 THEN TRUE ELSE FALSE END AS IS_READMISSION,
    'Encounter' AS FHIR_RESOURCE_TYPE,
    'Patient/PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS FHIR_REFERENCE
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- 3K invalid encounters (for FHIR validation testing)
INSERT INTO ENCOUNTERS
SELECT
    'ENC-' || LPAD((50000 + SEQ4())::VARCHAR, 6, '0') AS ENCOUNTER_ID,
    CASE WHEN MOD(SEQ4(), 3) = 0 THEN 'PAT-INVALID-' || SEQ4()::VARCHAR
         ELSE 'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0')
    END AS PATIENT_ID,
    'Inpatient' AS ENCOUNTER_TYPE,
    'Singapore General Hospital' AS FACILITY,
    CASE WHEN MOD(SEQ4(), 3) = 2
        THEN DATEADD(DAY, 5, CURRENT_DATE())
        ELSE DATEADD(DAY, -UNIFORM(1, 365, RANDOM()), CURRENT_DATE())
    END AS ADMISSION_DATE,
    CASE WHEN MOD(SEQ4(), 3) = 2
        THEN DATEADD(DAY, -10, CURRENT_DATE())
        ELSE DATEADD(DAY, -UNIFORM(0, 360, RANDOM()), CURRENT_DATE())
    END AS DISCHARGE_DATE,
    'finished' AS STATUS,
    'PROV-0001' AS PROVIDER_ID,
    CASE WHEN MOD(SEQ4(), 3) = 1 THEN 'INVALID_CODE' ELSE 'E11.9' END AS DIAGNOSIS_CODE,
    FALSE AS IS_READMISSION,
    'Encounter' AS FHIR_RESOURCE_TYPE,
    CASE WHEN MOD(SEQ4(), 3) = 0 THEN 'Patient/PAT-INVALID-' || SEQ4()::VARCHAR
         ELSE 'Patient/PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0')
    END AS FHIR_REFERENCE
FROM TABLE(GENERATOR(ROWCOUNT => 3000));

------------------------------------------------------------
-- CONDITIONS (30K)
------------------------------------------------------------
CREATE OR REPLACE TABLE CONDITIONS (
    CONDITION_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    CONDITION_CODE VARCHAR(10),
    CONDITION_NAME VARCHAR(100),
    CATEGORY VARCHAR(30),
    CLINICAL_STATUS VARCHAR(20),
    ONSET_DATE DATE,
    SEVERITY VARCHAR(20)
);

INSERT INTO CONDITIONS
SELECT
    'COND-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS CONDITION_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'E11.9' WHEN 1 THEN 'E11.65' WHEN 2 THEN 'I10'
        WHEN 3 THEN 'I11.9' WHEN 4 THEN 'J44.1' WHEN 5 THEN 'J44.0'
        WHEN 6 THEN 'I50.9' WHEN 7 THEN 'I50.22' WHEN 8 THEN 'N18.3'
        ELSE 'J45.20'
    END AS CONDITION_CODE,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Type 2 Diabetes Mellitus' WHEN 1 THEN 'Type 2 Diabetes with Hyperglycemia'
        WHEN 2 THEN 'Essential Hypertension' WHEN 3 THEN 'Hypertensive Heart Disease'
        WHEN 4 THEN 'COPD with Acute Exacerbation' WHEN 5 THEN 'COPD with Acute Lower Resp Infection'
        WHEN 6 THEN 'Heart Failure, Unspecified' WHEN 7 THEN 'Chronic Systolic Heart Failure'
        WHEN 8 THEN 'Chronic Kidney Disease Stage 3' ELSE 'Mild Persistent Asthma'
    END AS CONDITION_NAME,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Endocrine' WHEN 1 THEN 'Endocrine' WHEN 2 THEN 'Cardiovascular'
        WHEN 3 THEN 'Cardiovascular' WHEN 4 THEN 'Respiratory' WHEN 5 THEN 'Respiratory'
        WHEN 6 THEN 'Cardiovascular' WHEN 7 THEN 'Cardiovascular' WHEN 8 THEN 'Renal'
        ELSE 'Respiratory'
    END AS CATEGORY,
    CASE WHEN MOD(HASH(SEQ4()), 100) < 80 THEN 'active' ELSE 'resolved' END AS CLINICAL_STATUS,
    DATEADD(DAY, -UNIFORM(30, 1825, RANDOM()), CURRENT_DATE()) AS ONSET_DATE,
    CASE
        WHEN MOD(HASH(SEQ4()), 100) < 20 THEN 'Severe'
        WHEN MOD(HASH(SEQ4()), 100) < 50 THEN 'Moderate'
        ELSE 'Mild'
    END AS SEVERITY
FROM TABLE(GENERATOR(ROWCOUNT => 30000));

------------------------------------------------------------
-- OBSERVATIONS (80K — HbA1c, BP, BMI, eGFR)
-- Deliberate: diabetes patients have 62% HbA1c control
------------------------------------------------------------
CREATE OR REPLACE TABLE OBSERVATIONS (
    OBSERVATION_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    OBSERVATION_CODE VARCHAR(20),
    OBSERVATION_NAME VARCHAR(50),
    VALUE_NUMERIC FLOAT,
    VALUE_UNIT VARCHAR(20),
    EFFECTIVE_DATE DATE,
    STATUS VARCHAR(20),
    CATEGORY VARCHAR(30)
);

-- HbA1c observations (20K): 62% in control (<7.0), 38% out of control
INSERT INTO OBSERVATIONS
SELECT
    'OBS-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS OBSERVATION_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    '4548-4' AS OBSERVATION_CODE,
    'Hemoglobin A1c' AS OBSERVATION_NAME,
    CASE
        WHEN MOD(HASH(SEQ4()), 100) < 62 THEN ROUND(UNIFORM(5.0, 6.9, RANDOM())::FLOAT, 1)
        ELSE ROUND(UNIFORM(7.1, 12.5, RANDOM())::FLOAT, 1)
    END AS VALUE_NUMERIC,
    '%' AS VALUE_UNIT,
    DATEADD(DAY, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS EFFECTIVE_DATE,
    'final' AS STATUS,
    'laboratory' AS CATEGORY
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

-- BP observations (20K)
INSERT INTO OBSERVATIONS
SELECT
    'OBS-' || LPAD((20000 + SEQ4())::VARCHAR, 6, '0') AS OBSERVATION_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    '85354-9' AS OBSERVATION_CODE,
    'Blood Pressure Systolic' AS OBSERVATION_NAME,
    CASE
        WHEN MOD(HASH(SEQ4()), 100) < 55 THEN ROUND(UNIFORM(90, 139, RANDOM())::FLOAT, 0)
        ELSE ROUND(UNIFORM(140, 200, RANDOM())::FLOAT, 0)
    END AS VALUE_NUMERIC,
    'mmHg' AS VALUE_UNIT,
    DATEADD(DAY, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS EFFECTIVE_DATE,
    'final' AS STATUS,
    'vital-signs' AS CATEGORY
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

-- BMI observations (20K)
INSERT INTO OBSERVATIONS
SELECT
    'OBS-' || LPAD((40000 + SEQ4())::VARCHAR, 6, '0') AS OBSERVATION_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    '39156-5' AS OBSERVATION_CODE,
    'Body Mass Index' AS OBSERVATION_NAME,
    ROUND(UNIFORM(18.5, 42.0, RANDOM())::FLOAT, 1) AS VALUE_NUMERIC,
    'kg/m2' AS VALUE_UNIT,
    DATEADD(DAY, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS EFFECTIVE_DATE,
    'final' AS STATUS,
    'vital-signs' AS CATEGORY
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

-- eGFR observations (20K+)
INSERT INTO OBSERVATIONS
SELECT
    'OBS-' || LPAD((60000 + SEQ4())::VARCHAR, 6, '0') AS OBSERVATION_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    '33914-3' AS OBSERVATION_CODE,
    'Estimated GFR' AS OBSERVATION_NAME,
    ROUND(UNIFORM(15, 120, RANDOM())::FLOAT, 0) AS VALUE_NUMERIC,
    'mL/min/1.73m2' AS VALUE_UNIT,
    DATEADD(DAY, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS EFFECTIVE_DATE,
    'final' AS STATUS,
    'laboratory' AS CATEGORY
FROM TABLE(GENERATOR(ROWCOUNT => 20260));

------------------------------------------------------------
-- CARE_PLANS (10K)
------------------------------------------------------------
CREATE OR REPLACE TABLE CARE_PLANS (
    CARE_PLAN_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    TITLE VARCHAR(100),
    STATUS VARCHAR(20),
    INTENT VARCHAR(20),
    CATEGORY VARCHAR(30),
    START_DATE DATE,
    END_DATE DATE,
    GOALS VARCHAR(500)
);

INSERT INTO CARE_PLANS
SELECT
    'CP-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS CARE_PLAN_ID,
    'PAT-I-' || LPAD(MOD(SEQ4(), 5000)::VARCHAR, 5, '0') AS PATIENT_ID,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Diabetes Management Plan' WHEN 1 THEN 'Hypertension Control Plan'
        WHEN 2 THEN 'COPD Action Plan' WHEN 3 THEN 'Heart Failure Management'
        WHEN 4 THEN 'CKD Progression Prevention' WHEN 5 THEN 'Asthma Control Plan'
        WHEN 6 THEN 'Weight Management Program' ELSE 'Cardiac Rehabilitation'
    END AS TITLE,
    CASE WHEN MOD(HASH(SEQ4()), 100) < 70 THEN 'active' ELSE 'completed' END AS STATUS,
    'plan' AS INTENT,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Endocrine' WHEN 1 THEN 'Cardiovascular' WHEN 2 THEN 'Respiratory'
        WHEN 3 THEN 'Cardiovascular' WHEN 4 THEN 'Renal' WHEN 5 THEN 'Respiratory'
        WHEN 6 THEN 'Lifestyle' ELSE 'Cardiovascular'
    END AS CATEGORY,
    DATEADD(DAY, -UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) AS START_DATE,
    DATEADD(DAY, UNIFORM(30, 180, RANDOM()), CURRENT_DATE()) AS END_DATE,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Target HbA1c < 7.0%, daily glucose monitoring, quarterly labs'
        WHEN 1 THEN 'Target BP < 130/80, daily monitoring, medication adherence > 90%'
        WHEN 2 THEN 'Reduce exacerbations by 50%, inhaler technique review quarterly'
        WHEN 3 THEN 'NYHA class improvement, daily weight, fluid restriction < 2L'
        WHEN 4 THEN 'Slow eGFR decline to < 3 mL/min/year, protein restriction'
        WHEN 5 THEN 'Zero ER visits for asthma, peak flow > 80% predicted'
        WHEN 6 THEN 'BMI reduction of 5%, 150 min exercise/week, nutritionist visits'
        ELSE '6-minute walk > 400m, cardiac rehab 3x/week for 12 weeks'
    END AS GOALS
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

------------------------------------------------------------
-- QUALITY_MEASURES (20 — HEDIS/CMS)
------------------------------------------------------------
CREATE OR REPLACE TABLE QUALITY_MEASURES (
    MEASURE_ID VARCHAR(20),
    MEASURE_CODE VARCHAR(20),
    MEASURE_NAME VARCHAR(100),
    CATEGORY VARCHAR(30),
    TARGET_PERCENTAGE FLOAT,
    REPORTING_YEAR INT,
    SOURCE VARCHAR(20),
    DESCRIPTION VARCHAR(500)
);

INSERT INTO QUALITY_MEASURES VALUES
('QM-001', 'NQF-0059', 'Diabetes HbA1c Control (<8%)', 'Effectiveness', 80.0, 2026, 'HEDIS', 'Percentage of diabetic patients with most recent HbA1c < 8.0%'),
('QM-002', 'NQF-0018', 'Hypertension BP Control (<140/90)', 'Effectiveness', 75.0, 2026, 'HEDIS', 'Percentage of hypertensive patients with BP < 140/90'),
('QM-003', 'NQF-0421', 'Adult BMI Assessment', 'Prevention', 90.0, 2026, 'HEDIS', 'Percentage of patients with documented BMI in past 12 months'),
('QM-004', 'NQF-0403', 'COPD Spirometry Assessment', 'Effectiveness', 70.0, 2026, 'CMS', 'COPD patients with spirometry in past 12 months'),
('QM-005', 'NQF-0081', 'Heart Failure ACE/ARB Therapy', 'Treatment', 85.0, 2026, 'CMS', 'HF patients prescribed ACE inhibitor or ARB'),
('QM-006', 'NQF-0062', 'Diabetes Eye Exam', 'Prevention', 67.0, 2026, 'HEDIS', 'Diabetic patients with retinal exam in past 12 months'),
('QM-007', 'NQF-0055', 'Diabetes Foot Exam', 'Prevention', 80.0, 2026, 'HEDIS', 'Diabetic patients with foot exam in past 12 months'),
('QM-008', 'NQF-0064', 'Diabetes LDL Screening', 'Prevention', 75.0, 2026, 'HEDIS', 'Diabetic patients with LDL-C test in past 12 months'),
('QM-009', 'NQF-0075', 'IVD LDL Control (<100)', 'Effectiveness', 60.0, 2026, 'HEDIS', 'IVD patients with LDL-C < 100 mg/dL'),
('QM-010', 'NQF-0004', 'Alcohol Screening', 'Prevention', 85.0, 2026, 'CMS', 'Patients screened for unhealthy alcohol use'),
('QM-011', 'NQF-0028', 'Tobacco Screening & Cessation', 'Prevention', 90.0, 2026, 'CMS', 'Patients screened for tobacco use with cessation offered'),
('QM-012', 'NQF-0034', 'Colorectal Cancer Screening', 'Prevention', 72.0, 2026, 'HEDIS', 'Adults 45-75 with appropriate CRC screening'),
('QM-013', 'NQF-2372', 'Breast Cancer Screening', 'Prevention', 77.0, 2026, 'HEDIS', 'Women 50-74 with mammogram in past 2 years'),
('QM-014', 'NQF-0043', 'Pneumonia Vaccination', 'Prevention', 80.0, 2026, 'CMS', 'Adults 65+ with pneumococcal vaccine'),
('QM-015', 'NQF-0038', 'Childhood Immunization', 'Prevention', 85.0, 2026, 'HEDIS', 'Children with recommended immunizations by age 2'),
('QM-016', 'NQF-0105', 'Antidepressant Medication Mgmt', 'Treatment', 65.0, 2026, 'HEDIS', 'Patients on antidepressant for acute phase (12 weeks)'),
('QM-017', 'NQF-1768', 'Statin Therapy for CVD', 'Treatment', 80.0, 2026, 'CMS', 'CVD patients prescribed statin therapy'),
('QM-018', 'NQF-0024', 'Well-Child Visits (3-6 years)', 'Prevention', 75.0, 2026, 'HEDIS', 'Children aged 3-6 with annual well-child visit'),
('QM-019', 'NQF-0032', 'Cervical Cancer Screening', 'Prevention', 77.0, 2026, 'HEDIS', 'Women 21-64 with appropriate cervical screening'),
('QM-020', 'NQF-0002', 'Follow-Up After Hospitalization', 'Coordination', 70.0, 2026, 'CMS', 'Patients with follow-up within 7 days of discharge');

------------------------------------------------------------
-- CARE_PATHWAY_DOCS (100 — for Cortex Search)
------------------------------------------------------------
CREATE OR REPLACE TABLE CARE_PATHWAY_DOCS (
    DOC_ID VARCHAR(20),
    TITLE VARCHAR(200),
    CATEGORY VARCHAR(50),
    CONTENT VARCHAR(5000),
    LAST_UPDATED DATE,
    VERSION VARCHAR(10),
    APPROVED_BY VARCHAR(50)
);

INSERT INTO CARE_PATHWAY_DOCS
SELECT
    'DOC-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS DOC_ID,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'Type 2 Diabetes Management Pathway' WHEN 1 THEN 'Hypertension Treatment Algorithm'
        WHEN 2 THEN 'COPD Exacerbation Protocol' WHEN 3 THEN 'Heart Failure Decompensation Pathway'
        WHEN 4 THEN 'CKD Stage 3-4 Management' WHEN 5 THEN 'Asthma Stepwise Therapy'
        WHEN 6 THEN 'Diabetes Foot Care Protocol' WHEN 7 THEN 'Cardiac Rehabilitation Pathway'
        WHEN 8 THEN 'Anticoagulation Management' WHEN 9 THEN 'Chronic Pain Management'
        WHEN 10 THEN 'Depression Screening & Treatment' WHEN 11 THEN 'Obesity Management Pathway'
        WHEN 12 THEN 'Smoking Cessation Protocol' WHEN 13 THEN 'Medication Reconciliation Process'
        WHEN 14 THEN 'Transitional Care Protocol' WHEN 15 THEN 'Palliative Care Referral Criteria'
        WHEN 16 THEN 'Diabetes Insulin Titration' WHEN 17 THEN 'Hypertension Resistant Protocol'
        WHEN 18 THEN 'COPD Pulmonary Rehab Pathway' ELSE 'HF Device Therapy Criteria'
    END || ' (v' || (MOD(SEQ4(), 5) + 1)::VARCHAR || '.' || MOD(SEQ4(), 3)::VARCHAR || ')' AS TITLE,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Diabetes' WHEN 1 THEN 'Cardiovascular' WHEN 2 THEN 'Respiratory'
        WHEN 3 THEN 'Heart Failure' WHEN 4 THEN 'Renal' WHEN 5 THEN 'Respiratory'
        WHEN 6 THEN 'Diabetes' WHEN 7 THEN 'Cardiovascular' WHEN 8 THEN 'Hematology'
        ELSE 'Pain Management'
    END AS CATEGORY,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'Clinical pathway for Type 2 Diabetes management. Initial assessment includes HbA1c, fasting glucose, lipid panel, renal function, and foot examination. If HbA1c > 7.0%, initiate metformin 500mg BD and lifestyle modification. Reassess at 3 months. If HbA1c remains > 7.5%, add second agent (SGLT2i preferred for CVD/CKD risk, GLP-1 RA for obesity). Targets: HbA1c < 7.0%, FPG < 7.2 mmol/L, BP < 130/80. Annual screening: retinopathy, nephropathy, neuropathy. Refer to endocrinology if HbA1c > 9.0% or recurrent hypoglycemia.'
        WHEN 1 THEN 'Hypertension treatment algorithm based on ACC/AHA 2024 guidelines. Stage 1 (130-139/80-89): lifestyle modification for 3-6 months, then pharmacotherapy if 10-year ASCVD risk > 10%. Stage 2 (>=140/90): immediate pharmacotherapy. First-line: ACEi/ARB for DM/CKD, CCB or thiazide for others. Target: < 130/80 for most, < 120/80 for high CVD risk. Follow-up: 1 month after initiation, then quarterly. Resistant hypertension: add spironolactone 25mg, confirm adherence, exclude secondary causes.'
        WHEN 2 THEN 'COPD exacerbation management protocol. Severity classification: Mild (increased dyspnea, managed with short-acting bronchodilators), Moderate (requires systemic corticosteroids and/or antibiotics), Severe (requires hospitalization or ER visit). Acute management: Salbutamol 2.5mg nebulized q20min x3, ipratropium 500mcg nebulized, prednisolone 40mg daily x5 days, antibiotics if purulent sputum. Discharge criteria: SpO2 > 92% on room air, able to manage at home, follow-up within 48 hours.'
        WHEN 3 THEN 'Heart failure decompensation pathway. Immediate assessment: BNP/NT-proBNP, electrolytes, renal function, troponin, CXR, ECG. Classification: wet-warm (most common), wet-cold (cardiogenic shock), dry-cold (low output). Diuresis: IV furosemide 40-80mg (2.5x home dose), target 1-2L negative daily. Monitor weight, I/O, electrolytes BID. If inadequate response: double dose q6h, add metolazone 2.5mg. Vasodilators for SBP > 110. Inotropes only for wet-cold with end-organ dysfunction.'
        WHEN 4 THEN 'CKD Stage 3-4 management pathway. Goals: slow progression, manage complications, prepare for RRT if needed. Key interventions: ACEi/ARB titrated to maximum tolerated dose, SGLT2i (dapagliflozin 10mg) if eGFR > 20, BP target < 130/80, protein restriction 0.8g/kg/day. Monitoring frequency: eGFR + uACR q3-6 months, electrolytes q3 months, PTH + calcium + phosphate q6 months. Referral to nephrology: eGFR < 30, rapid decline (> 5 mL/min/year), refractory hyperkalemia, anemia requiring ESA.'
        ELSE 'Clinical care pathway for chronic disease management. Includes assessment protocols, treatment algorithms, monitoring schedules, and referral criteria. Evidence-based approach incorporating latest clinical guidelines and quality measures. Patient engagement strategies include shared decision-making, self-management education, and care coordinator involvement. Outcome measures tracked include clinical endpoints, patient-reported outcomes, and process metrics. Regular pathway review and update cycle: annual evidence review, biannual clinical advisory input, quarterly outcome assessment.'
    END AS CONTENT,
    DATEADD(DAY, -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS LAST_UPDATED,
    (MOD(SEQ4(), 5) + 1)::VARCHAR || '.' || MOD(SEQ4(), 3)::VARCHAR AS VERSION,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Dr. Tanaka' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Patel'
        WHEN 3 THEN 'Dr. Kim' ELSE 'Dr. Singh'
    END AS APPROVED_BY
FROM TABLE(GENERATOR(ROWCOUNT => 100));
