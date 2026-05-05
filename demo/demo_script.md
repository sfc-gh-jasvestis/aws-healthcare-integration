# Demo Script: Population Health & Data Integration
## 3.5-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: AWS Summit booth / healthcare payer/provider audience

---

## The Story

A Population Health Director discovers that Diabetes HbA1c compliance has dropped to 62% — well below the 80% target. 682 diabetic patients have uncontrolled blood sugar and are at elevated readmission risk. The platform — powered by Snowflake Dynamic Tables, Cortex AI, Amazon S3, SNS, and QuickSight — catches 5.7% FHIR data errors automatically, identifies care gaps, and alerts coordinators in under 2 minutes end-to-end.

---

## Two Personas

| Persona | Tool | What they care about |
|---|---|---|
| **Population Health Director** | Streamlit in Snowflake | Quality measures, care gaps, patient risk, data quality |
| **Chief Medical Officer** | Amazon QuickSight + Amazon Q | Compliance trends, resource allocation, regulatory reporting |

---

## Narrative Arc: Architecture → Value Discovery → Detailed Insights → AWS Action Loop

---

## Script

### [0:00–0:15] ARCHITECTURE OPENER (Show: README diagram or slide)

> "Here's the full pipeline. FHIR bundles — Patient, Encounter, Observation, Condition resources — land in Amazon S3 from the EHR. Snowpipe auto-ingests within 60 seconds into Snowflake. Four Dynamic Tables handle validation, risk scoring, quality compliance, and care gap identification — all refreshing automatically. When a gap is detected, a Snowflake Alert publishes to Amazon SNS so care coordinators get notified immediately. And for the CMO, Amazon QuickSight with Q gives natural language access to the same governed data. Let me show you what this looks like in action."

### [0:15–0:35] PATIENT RISK (Show: Patients tab)

> "5,000 patients in our value-based care program. 1,008 flagged as high risk. Average risk score across the population: 141. The donut shows 20% high risk, 34% moderate, 46% low. These are the patients most likely to drive cost — readmissions, ED visits, avoidable complications. The Patient Risk Scores Dynamic Table computes this automatically from encounter history, condition count, and observation anomalies."

### [0:35–1:05] QUALITY MEASURES (Show: Quality Measures tab)

> "Five key quality measures — HEDIS and CMS — computed by a Dynamic Table that joins conditions, observations, and care plans in real-time. The red dashed line is our 80% target. Four out of five are below it. CKD eGFR Monitoring at 48%. Hypertension at 50%. COPD at 67%. And the one I'm most concerned about: Diabetes HbA1c Control at 62%. That's 682 patients with uncontrolled blood sugar — every one of them a preventable readmission risk. Only Heart Failure Readmission is meeting target at 95%."

### [1:05–1:30] CARE GAPS (Show: Care Gaps tab)

> "The Care Gap Identification Dynamic Table surfaces every non-compliant patient automatically — no batch jobs, no ETL scheduling. 2,810 active gaps. Sorted by priority and days overdue — some patients are 676 days overdue. Uncontrolled conditions and missed follow-ups. Each one is an outreach opportunity. In production, when a new high-priority gap appears, the Snowflake Alert fires an Amazon SNS notification to the care coordinator's phone — from detection to action in under 2 minutes."

### [1:30–1:55] DATA QUALITY (Show: Data Quality tab)

> "FHIR data quality — the silent killer of population health programs. This validation Dynamic Table processes every encounter within 1 minute of ingestion from S3. 5.7% error rate: missing patient references, non-standard ICD codes, invalid date sequences. Without this layer, those 3,000 bad records would corrupt every downstream metric. The DT catches them before they propagate — and because it's a Dynamic Table, it never goes stale."

### [1:55–2:15] ASK THE DATA (Show: Ask the Data tab)

> "'How many diabetic patients missed their HbA1c?' — Cortex Analyst generates SQL against the Semantic View, returns 682. 'Which measures are below 80% compliance?' — four measures listed with gap counts. Any clinical stakeholder can ask questions in plain English — no SQL, no tickets, no waiting."

### [2:15–2:40] AMAZON Q (Show: Switch to QuickSight dashboard + Q)

> "Same data, different persona. The CMO opens Amazon QuickSight — compliance bar chart, gap breakdown, all powered by the same Snowflake Dynamic Tables via direct query. Amazon Q: 'Which measures are below 80% compliance?' — instant answer, four measures. 'Gap count for diabetes?' — 682. Same answer as the Streamlit app, because it's the same governed data layer. No reconciliation. No data silos."

### [2:40–3:10] CLOSE — THE BETTER TOGETHER STORY (Show: Architecture diagram)

> "Let me bring it all together. Amazon S3 is the data landing zone for FHIR bundles from any EHR or HIE. Snowpipe auto-ingests. Snowflake Dynamic Tables handle validation, risk scoring, compliance, and gap identification — all declarative, all real-time. Cortex AI powers natural language analytics. Amazon SNS closes the loop with care coordinator alerts. Amazon QuickSight gives the executive suite self-service dashboards and Q gives them natural language. End to end: one governed platform, two personas, zero reconciliation. 4 measures below target. 2,810 care gaps identified. 5.7% data quality issues caught automatically. That's Population Health Intelligence — Snowflake and AWS, better together."

---

## Pre-Recording Checklist

- [ ] Open Streamlit: HEALTHCARE_INTEGRATION.APP.INTEGRATION_ANALYTICS_APP
- [ ] Verify Patients tab: 5,000 patients, ~1,008 high risk
- [ ] Verify Quality Measures: Diabetes HbA1c at ~62%, red dashed line visible
- [ ] Verify Care Gaps: ~2,810 gaps, table shows patient IDs
- [ ] Verify Data Quality: ~5.7% error rate in pie chart
- [ ] Test Ask the Data: "How many diabetic patients missed their HbA1c?" (expect 682)
- [ ] Test Ask the Data: "Which measures are below 80% compliance?" (expect 4 measures)
- [ ] Open QuickSight dashboard: https://us-west-2.quicksight.aws.amazon.com/sn/dashboards/hc-integration-dashboard
- [ ] Test Amazon Q: "Which measures are below 80% compliance?" (expect 4 measures)
- [ ] Have README architecture diagram ready (or separate slide) for opener and closer

---

## Key Questions to Anticipate

1. **"Is this real FHIR data?"** — Synthetic data modeled on FHIR R4 resource structure (Patient, Encounter, Observation, Condition). In production, real FHIR bundles land in S3 via API Gateway, HealthLake, or direct EHR integration.

2. **"How does the care gap alert work?"** — Snowflake ALERT monitors the CARE_GAP_IDENTIFICATION DT every hour. When high-priority gaps exceed a threshold, it publishes to SNS → care coordinator gets Slack/email/SMS notification with patient details and recommended action.

3. **"What about data governance?"** — Snowflake Horizon: dynamic masking on PII (DOB, name), row-access policies by care team, full audit logging on all PHI access. Data never leaves the security perimeter. QuickSight queries Snowflake directly — no data copies.

4. **"Can this handle multiple health systems?"** — Yes. Each health system lands data in its own S3 prefix. Snowpipe ingests separately. The Dynamic Tables normalize across systems using standard FHIR resource types — no custom ETL per source.

5. **"What's the refresh latency?"** — FHIR validation: 1 minute. Quality measures, risk scores, care gaps: 5 minutes. End-to-end from S3 landing to actionable gap: under 6 minutes.

---

## AWS Services Referenced

| AWS Service | Role in Architecture | Demo Moment |
|---|---|---|
| **Amazon S3** | FHIR bundle landing zone (data lake) | Architecture opener + data quality section |
| **Amazon SNS** | Care gap alert notifications to coordinators | Care gaps section |
| **Amazon QuickSight** | CMO dashboard (direct query to Snowflake DTs) | QuickSight section |
| **Amazon Q in QuickSight** | Natural language queries for executives | QuickSight section |
| **Snowpipe** | Auto-ingest from S3 within 60s | Architecture opener |
