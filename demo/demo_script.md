# Demo Script: Population Health & Data Integration
## 3.5-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: AWS Summit booth / healthcare payer/provider audience

---

## The Story

A Population Health Director discovers that Diabetes HbA1c compliance has dropped to 62% — well below the 80% target. 682 diabetic patients have uncontrolled blood sugar, and their readmission rate is 18% (vs 7% overall). The FHIR data quality layer catches 5.7% errors automatically. Using the platform, they identify care gaps, prioritize outreach, and alert care coordinators.

---

## Two Personas

| Persona | Tool | What they care about |
|---|---|---|
| **Population Health Director** | Streamlit in Snowflake | Quality measures, care gaps, patient risk, data quality |
| **Chief Medical Officer** | Amazon QuickSight + Amazon Q | Compliance trends, resource allocation, regulatory reporting |

---

## Narrative Arc: Compliance Gap → Root Cause → Patient Identification → Data Quality → Action

---

## Script

### [0:00–0:15] PATIENT RISK (Show: Patients tab)

> "5,000 patients in our value-based care program. 1,008 flagged as high risk. Average risk score: 141. The donut shows 20% high risk, 34% moderate, 46% low. These are the patients most likely to drive cost — readmissions, ED visits, avoidable complications."

### [0:15–0:45] QUALITY MEASURES (Show: Quality Measures tab)

> "20 quality measures — HEDIS and CMS. The red dashed line is our 80% target. Five measures are below it. CKD eGFR Monitoring at 47%. Hypertension BP Control at 50%. And the one I'm most concerned about: Diabetes HbA1c Control at 62%. That's 682 diabetic patients with uncontrolled blood sugar. Their readmission rate is 18% — nearly triple the overall rate of 7%. Every uncontrolled patient is a preventable readmission."

### [0:45–1:10] CARE GAPS (Show: Care Gaps tab)

> "The Care Gap Identification Dynamic Table surfaces every non-compliant patient automatically. 2,810 active gaps. Sorted by priority and days overdue — some patients are 729 days overdue for their screening. The pie chart shows gap types: uncontrolled, overdue screening, missed follow-up. Each one is an actionable outreach opportunity for the care coordination team."

### [1:10–1:35] DATA QUALITY (Show: Data Quality tab)

> "FHIR data quality — the silent killer of population health programs. Our validation Dynamic Table processes every record within 1 minute and flags errors automatically. 5.7% error rate: missing patient references, non-standard codes, invalid date sequences. Without this layer, those 5.7% would corrupt downstream analytics. The DT catches them before they propagate."

### [1:35–2:00] ASK THE DATA (Show: Ask the Data tab)

> "'How many diabetic patients missed their HbA1c?' — Cortex Analyst generates SQL against the Semantic View, returns the count. 'What is the readmission rate by condition?' — ranked table shows diabetes at the top. Any stakeholder can ask, no SQL knowledge required."

### [2:00–2:25] AMAZON Q (Show: Switch to QuickSight)

> "The CMO opens Amazon Q: 'Which measures are below 80% compliance?' — instant answer with the five measures listed. Follow-up: 'What is the gap count for diabetes?' — 682. The same answer the Streamlit app showed, because it's the same governed data in Snowflake. No reconciliation needed."

### [2:25–2:50] THE INTEGRATION STORY (Voiceover with architecture)

> "Let me show you how the data gets here. FHIR bundles — Patient, Encounter, Observation, Condition resources — land in Amazon S3. Snowpipe auto-ingests within 60 seconds. A validation Dynamic Table checks quality in real-time. Clean records flow to the curated layer. When a care gap is detected, a Snowflake Alert fires an SNS notification to the care coordinator's phone. End to end — from EHR to action — in under 2 minutes."

### [2:50–3:10] CLOSE (Show: Data Quality tab with the 5.7% pie)

> "4 measures below target. 2,810 active care gaps identified automatically. 5.7% data quality issues caught before they corrupt analytics. 18% diabetes readmission rate — now visible, now actionable. That's Population Health Intelligence on Snowflake and AWS. FHIR integration, quality monitoring, gap identification, and executive analytics — one governed platform."

---

## Pre-Recording Checklist

- [ ] Open Streamlit: HEALTHCARE_INTEGRATION.APP.INTEGRATION_ANALYTICS_APP
- [ ] Verify Patients tab: 5,000 patients, ~1,008 high risk
- [ ] Verify Quality Measures: Diabetes HbA1c at ~62%, red dashed line visible
- [ ] Verify Care Gaps: ~2,810 gaps, table shows patient IDs
- [ ] Verify Data Quality: ~5.7% error rate in pie chart
- [ ] Test Ask the Data: "How many diabetic patients missed their HbA1c?"
- [ ] Open QuickSight, test Q: "Which measures are below 80% compliance?"

---

## Key Questions to Anticipate

1. **"Is this real FHIR data?"** — Synthetic data modeled on FHIR resource structure (Patient, Encounter, Observation, Condition). In production, real FHIR bundles land in S3 via API Gateway or direct EHR integration.

2. **"How does the care gap alert work?"** — Snowflake ALERT monitors the CARE_GAP_IDENTIFICATION DT. When a new high-priority gap appears, it publishes to SNS → care coordinator gets Slack/email notification with patient details.

3. **"What about data governance?"** — Snowflake Horizon: masking policies on PII, row-access policies by care team, audit logging on all PHI access. Data never leaves the security perimeter.

4. **"Can this handle multiple health systems?"** — Yes. Each health system lands data in its own S3 prefix. Snowpipe ingests separately. The Dynamic Tables normalize across systems using standard FHIR resource types.
