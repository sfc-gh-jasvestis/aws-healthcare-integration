-- Healthcare Data Integration: Cortex Agent
USE DATABASE HEALTHCARE_INTEGRATION;
USE SCHEMA AI;

CREATE OR REPLACE CORTEX AGENT INTEGRATION_AGENT
  COMMENT = 'Population Health Intelligence — answers questions about quality measures, patient risk, care gaps, and clinical pathways'
  DISPLAY_NAME = 'Population Health Intelligence'
  COLOR = 'teal'
  TOOLS = (
    'HEALTHCARE_INTEGRATION.AI.INTEGRATION_SEMANTIC_VIEW'::SEMANTIC VIEW AS PopHealthAnalyst
      COMMENT = 'Analyzes quality measure compliance, patient risk scores, and care gaps using structured population health data',
    'HEALTHCARE_INTEGRATION.SEARCH.CARE_PATHWAY_SEARCH'::CORTEX SEARCH AS CarePathwaySearch
      COMMENT = 'Searches clinical care pathway documents for treatment protocols, guidelines, and referral criteria'
  );
