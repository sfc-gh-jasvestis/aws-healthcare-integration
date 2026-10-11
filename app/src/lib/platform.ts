// Build option, set in the SPCS spec (snowflake/07_deploy_app.sql):
// 'snowflake' = Snowflake-only build (native FHIR bundle simulator, Cortex AI_COMPLETE memo);
// 'aws' = AWS + Snowflake build (S3/Snowpipe bundle feed, Bedrock memo, QuickSight).
export type DemoPlatform = 'snowflake' | 'aws';

export const demoPlatform = (): DemoPlatform => (process.env.DEMO_PLATFORM === 'snowflake' ? 'snowflake' : 'aws');
