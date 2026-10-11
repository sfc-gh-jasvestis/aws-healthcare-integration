# FHIR Feed Integration Operations

**Singapore - Harbourlink Health Exchange (fictional)**
Use case: FHIR feed quality and interface incident triage

> Feed operations for 40 facilities connected to Harbourlink Health Exchange, a fictional Singapore health information exchange, across 5 planning areas: dynamic tables, a holdout-evaluated interface incident classifier, an accepted-bundle forecast and grounded AI answers. Synthetic, facility-level data only; no patient records.

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

Planning areas: Novena, Outram, Jurong East, Tampines, Woodlands (8 facilities each).
Source types: Hospital, Primary care, Laboratory, Pharmacy, Imaging.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Feed Completeness | 91.2% |
| Bundles Accepted | 394,621 |
| Bundle Rejection Rate | 6.2% |
| Issue Escalation Rate | 34.5% |
| Data Quality Issues | 621 |
| Interface Incidents | 214 |
| Tickets Opened | 111 |
| Conformance Check Compliance | 75.6% |
| Facilities Connected | 40 |
| Profile Conformance | 64.3% |
| Profile Reviews Pending | 14 |

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

- The exchange is at 91.2% of its expected 90-day bundle volume, and 20 of 40 facilities are below 90% of their expected volume. Jurong East is the lowest planning area at 88.9%.
- About one data quality issue in three is escalated as an interface incident (34.5%). Missing references produce the most incidents (54), just ahead of date sequence errors and invalid terminology codes (53 each). Regional network outage issues hit every facility in one planning area at once (Jurong East and Woodlands) and are never escalated.
- Tampines has the most interface incidents (64); Woodlands has the fewest (9).
- The risk model is evaluated on a time-based holdout: precision 0.73 and recall 0.49 at 0.5, against a 0.28 base rate. Present it as triage for interface operations effort, not a verdict on a facility.
- Regional network outages are excluded from model training, because they are not facility-driven.
- This is integration operations data only. It makes no clinical, medical or regulatory claims and contains no patient records.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
