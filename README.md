# Healthcare Data Integration — FHIR + Population Health

End-to-end population health analytics platform integrating FHIR-compliant clinical data with quality measure tracking, care gap identification, and proactive patient outreach.

## Architecture

```
┌─────────────┐    ┌─────────┐    ┌───────────┐    ┌───────────────┐
│ FHIR Bundles│───▶│   S3    │───▶│ Snowpipe  │───▶│   Snowflake   │
│ (EHR/HIE)   │    │ Landing │    │ Auto-Ingest│    │   RAW Schema  │
└─────────────┘    └─────────┘    └───────────┘    └───────┬───────┘
                                                           │
                                                           ▼
                                              ┌────────────────────────┐
                                              │    Dynamic Tables      │
                                              │  • Quality Compliance  │
                                              │  • Patient Risk Scores │
                                              │  • Care Gap ID         │
                                              │  • FHIR Validation     │
                                              └────────────┬───────────┘
                                                           │
                                              ┌────────────▼───────────┐
                                              │   Quality Validation   │
                                              │  5.7% FHIR error rate  │
                                              │  Missing refs/codes    │
                                              └────────────┬───────────┘
                                                           │
                                              ┌────────────▼───────────┐
                                              │  Care Gap Alerts       │
                                              │  High-priority gaps    │
                                              └────────────┬───────────┘
                                                           │
                                                           ▼
                                              ┌────────────────────────┐
                                              │   SNS Notifications    │
                                              │  Care coordinators     │
                                              └────────────────────────┘
```

## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Population Health Director** | Oversees quality programs, identifies at-risk populations, manages care coordinator assignments | "Which quality measures are below target?" "Who needs outreach?" |
| **Chief Medical Officer (CMO)** | Monitors system-wide quality, reviews FHIR compliance, approves pathway changes | "What's our diabetes control rate?" "Are we HEDIS-compliant?" |

## Data Profile

| Entity | Volume | Description |
|--------|--------|-------------|
| Patients | 5,000 | APJ-region names, risk tiers (Critical/High/Medium/Low) |
| Encounters | 53,000 | 50K valid + 3K with deliberate FHIR validation errors |
| Conditions | 30,000 | Diabetes, Hypertension, COPD, Heart Failure, CKD, Asthma |
| Observations | 80,000 | HbA1c, BP, BMI, eGFR — 62% diabetes control rate |
| Care Plans | 10,000 | Active plans linked to patients and conditions |
| Quality Measures | 20 | HEDIS/CMS measures with compliance targets |
| Care Pathway Docs | 100 | Clinical pathways for Cortex Search |

## Key Narrative Metrics

- **Diabetes HbA1c Control**: 62% compliance (target 80%) — 682 patients in gap
- **Readmission Rate**: 15% for diabetes patients (vs 7% overall)
- **FHIR Error Rate**: 5.7% (missing references, invalid codes, bad date sequences)

## Capabilities

| Capability | Implementation |
|------------|---------------|
| FHIR Ingestion | S3 stage + Snowpipe auto-ingest from EHR/HIE bundles |
| Data Quality Validation | Dynamic Table validates missing refs, invalid codes, bad dates (1-min lag) |
| Quality Measures | HEDIS/CMS compliance tracking across 20 measures |
| Care Gap Identification | Patient × measure gap detection with priority scoring |
| Admission Forecasting | Snowflake ML FORECAST by facility (30-day horizon) |
| SNS Alerting | External Access Integration pushes high-priority gaps to care coordinators |
| Cortex Agent | Natural language queries on population health + care pathway search |

## Build

```bash
-- Execute SQL scripts in order against your Snowflake account
snowsql -f snowflake/00_setup.sql
snowsql -f snowflake/01_integrations.sql
snowsql -f snowflake/02_raw_tables.sql
snowsql -f snowflake/03_curated.sql
snowsql -f snowflake/04_search.sql
snowsql -f snowflake/05_ml.sql
snowsql -f snowflake/06_semantic.sql
snowsql -f snowflake/07_agent.sql
snowsql -f snowflake/08_alerts.sql

-- Deploy QuickSight resources
chmod +x quicksight/deploy.sh && ./quicksight/deploy.sh
```

## Tear Down

```bash
-- Remove Snowflake objects
DROP DATABASE IF EXISTS HEALTHCARE_INTEGRATION;

-- Remove AWS resources
chmod +x aws/teardown.sh && ./aws/teardown.sh
```

## License

Apache 2.0
