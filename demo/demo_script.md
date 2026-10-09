# FHIR Feed Integration Operations

**APJ - Regional Health Information Exchange**
Use case: FHIR feed quality and interface incident triage

> Feed operations for 40 connected facilities in a fictional regional health information exchange across 5 APJ markets: dynamic tables, a holdout-evaluated interface incident classifier, an accepted-bundle forecast and grounded AI answers. Synthetic, facility-level data only; no patient records.

## Why Snowflake

- **Dynamic tables** reconcile feed completeness, bundle rejections, data quality issues, interface incidents and conformance check compliance from RAW facility data, with checks in `run_core.py`
- **Interface incident classification** gives a holdout-evaluated next-7-day probability per facility
- **Accepted-bundle forecast** projects 14 days of network volume with prediction intervals, for capacity planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live bundle events**: a native simulator (Snowflake only) or S3 PutObject and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.FACILITIES` (40 rows) |
| Fact table | `RAW.FEED_DAILY` (3,600 facility-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `ISSUE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.INCIDENT_RISK_SCORES`, `ML.INCIDENT_RISK_HOLDOUT_METRICS`, `ML.BUNDLE_FORECAST`, `ML.UNMAPPED_CODE_ANOMALIES` |

Markets: Singapore, Sydney, Seoul, Tokyo, Taipei.
Source types: Hospital, Primary care, Laboratory, Pharmacy, Imaging.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Feed Completeness | 93.0% |
| Bundles Accepted | 464,274 |
| Bundle Rejection Rate | 6.1% |
| Issue Escalation Rate | 30.4% |
| Data Quality Issues | 573 |
| Interface Incidents | 174 |
| Tickets Opened | 71 |
| Conformance Check Compliance | 82.2% |
| Facilities Connected | 40 |
| Profile Conformance | 58.0% |
| Profile Reviews Pending | 24 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily data quality issues against interface incidents, issues and incidents by issue type, facility table
2. Predictive: holdout metrics, risk bands, 14-day accepted-bundle forecast, unmapped code rate anomalies
3. Conformance: check compliance, FHIR profile conformance and pending reviews, check compliance against interface incidents, then generate the action memo
4. Live Bundles: run `CALL APP.SIMULATE_BUNDLES(20)` (Snowflake only) or `python aws/publish_bundles.py --account <AWS_ACCOUNT_ID> --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_BUNDLE_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- The network is at 93.0% of its expected 90-day bundle volume, and 11 facilities are below 90% of their expected volume.
- About three data quality issues in ten are escalated as interface incidents (30.4%). Date sequence errors produce the most incidents. Regional network outage issues hit every facility in a market at once and are never escalated.
- The risk model is evaluated on a time-based holdout: precision 0.36 and recall 0.20 at 0.5, against a 0.25 base rate. Present it as triage for interface operations effort, not a verdict on a facility.
- Regional network outages are excluded from model training, because they are not facility-driven.
- This is integration operations data only. It makes no clinical or medical claims and contains no patient records.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
