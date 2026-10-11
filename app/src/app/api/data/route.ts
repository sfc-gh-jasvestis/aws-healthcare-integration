import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, issueTypes, facilities, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; ACCEPTED: number | null; ISSUES: number | null; INCIDENTS: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               BUNDLES_ACCEPTED AS ACCEPTED, ISSUE_COUNT AS ISSUES, INCIDENT_COUNT AS INCIDENTS
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ ISSUE: string; ISSUES: number; INCIDENTS: number }>(`
        SELECT ISSUE_TYPE AS ISSUE, ISSUE_COUNT AS ISSUES, INCIDENT_COUNT AS INCIDENTS
        FROM CURATED.ISSUE_SUMMARY ORDER BY INCIDENT_COUNT DESC, ISSUE_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, INTEGRATION_TIER, EVENT_COUNT, BUNDLES_ACCEPTED, EXPECTED_BUNDLES_90D,
               COMPLETENESS_PCT, REJECTION_PCT, ISSUE_COUNT, INCIDENT_COUNT, TICKET_COUNT, CHECK_COMPLIANCE_PCT
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.FEED_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, INCIDENT_PROB_7D, RISK_BAND
        FROM ML.INCIDENT_RISK_SCORES ORDER BY INCIDENT_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.INCIDENT_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, BUNDLES_ACCEPTED, LOWER_BOUND, UPPER_BOUND
        FROM ML.BUNDLE_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT FACILITY_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(LATENCY_MIN, 1) AS LATENCY_MIN,
               UNMAPPED_CODE_PCT, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_BUNDLES ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'ALERT') AS ALERTS,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_BUNDLES`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(UNMAPPED_CODE, 2) AS UNMAPPED_CODE,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.UNMAPPED_CODE_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT FACILITY_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(LATENCY_MIN, 1) AS LATENCY_MIN,
               UNMAPPED_CODE_PCT, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({
        period: row.PERIOD, accepted: numberOrNull(row.ACCEPTED), issues: numberOrNull(row.ISSUES), incidents: numberOrNull(row.INCIDENTS),
      })),
      categories: issueTypes.map((row) => ({ category: row.ISSUE, issues: numberOrNull(row.ISSUES), incidents: numberOrNull(row.INCIDENTS) })),
      entities: facilities.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.INTEGRATION_TIER,
        accepted: numberOrNull(row.BUNDLES_ACCEPTED), expected: numberOrNull(row.EXPECTED_BUNDLES_90D),
        completeness: numberOrNull(row.COMPLETENESS_PCT), rejection: numberOrNull(row.REJECTION_PCT),
        issues: numberOrNull(row.ISSUE_COUNT), incidents: numberOrNull(row.INCIDENT_COUNT), tickets: numberOrNull(row.TICKET_COUNT),
        checks: numberOrNull(row.CHECK_COMPLIANCE_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      checkRisk: facilities.map((row) => ({
        name: row.ENTITY_NAME, compliance: numberOrNull(row.CHECK_COMPLIANCE_PCT), incidents: numberOrNull(row.INCIDENT_COUNT),
      })).filter((row) => row.compliance !== null && row.incidents !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.INCIDENT_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.BUNDLES_ACCEPTED),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.FACILITY_ID, eventTs: row.EVENT_TS, latency: numberOrNull(row.LATENCY_MIN),
        unmappedCode: numberOrNull(row.UNMAPPED_CODE_PCT), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), alerts: numberOrNull(liveSummary[0]?.ALERTS),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, unmappedCode: numberOrNull(row.UNMAPPED_CODE),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.FACILITY_ID, eventTs: row.EVENT_TS, latency: numberOrNull(row.LATENCY_MIN),
        unmappedCode: numberOrNull(row.UNMAPPED_CODE_PCT), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Feed operations data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
