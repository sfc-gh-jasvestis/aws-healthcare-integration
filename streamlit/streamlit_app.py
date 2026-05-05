import streamlit as st
import pandas as pd
import json
import plotly.express as px
import _snowflake
from snowflake.snowpark.context import get_active_session

session = get_active_session()
st.set_page_config(page_title="Population Health", layout="wide", page_icon="🏥")
st.title("Population Health & Data Integration")
st.caption("FHIR Integration | Quality Measures | Care Gap Identification | Data Quality Monitoring")

tab1, tab2, tab3, tab4, tab5 = st.tabs(["Patients", "Quality Measures", "Care Gaps", "Data Quality", "Ask the Data"])

with tab1:
    risk = session.sql("SELECT RISK_TIER, COUNT(*) AS CNT, ROUND(AVG(READMISSION_RISK_SCORE),1)::FLOAT AS AVG_SCORE FROM HEALTHCARE_INTEGRATION.CURATED.PATIENT_RISK_SCORES GROUP BY RISK_TIER ORDER BY AVG_SCORE DESC").to_pandas()
    if not risk.empty:
        risk["CNT"] = pd.to_numeric(risk["CNT"], errors="coerce")
        risk["AVG_SCORE"] = pd.to_numeric(risk["AVG_SCORE"], errors="coerce")
        c1, c2, c3 = st.columns(3)
        c1.metric("Total Patients", f"{risk['CNT'].sum():,.0f}")
        c2.metric("High Risk", f"{risk[risk['RISK_TIER']=='HIGH']['CNT'].sum():,.0f}")
        c3.metric("Avg Risk Score", f"{risk['AVG_SCORE'].mean():.1f}")
        fig = px.pie(risk, values="CNT", names="RISK_TIER", title="Patient Risk Tier Distribution", hole=0.4)
        fig.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

with tab2:
    qm = session.sql("SELECT MEASURE_NAME, COMPLIANCE_PCT::FLOAT AS COMPLIANCE, GAP_COUNT::INT AS GAPS FROM HEALTHCARE_INTEGRATION.CURATED.QUALITY_MEASURE_COMPLIANCE ORDER BY COMPLIANCE").to_pandas()
    if not qm.empty:
        qm["COMPLIANCE"] = pd.to_numeric(qm["COMPLIANCE"], errors="coerce")
        qm["GAPS"] = pd.to_numeric(qm["GAPS"], errors="coerce")
        fig = px.bar(qm, x="COMPLIANCE", y="MEASURE_NAME", orientation="h", color="COMPLIANCE",
                     color_continuous_scale="RdYlGn", title="Quality Measure Compliance (%)")
        fig.add_vline(x=80, line_dash="dash", line_color="red", annotation_text="80% Target")
        fig.update_layout(height=500, margin=dict(t=40, b=10, l=200))
        st.plotly_chart(fig, use_container_width=True)
        below = qm[qm["COMPLIANCE"] < 80]
        if not below.empty:
            st.warning(f"{len(below)} measures below 80% target — {below['GAPS'].sum():,.0f} total care gaps")

with tab3:
    gaps = session.sql("SELECT PATIENT_ID, MEASURE_NAME, GAP_TYPE, DAYS_OVERDUE::INT AS DAYS_OVERDUE, PRIORITY FROM HEALTHCARE_INTEGRATION.CURATED.CARE_GAP_IDENTIFICATION ORDER BY PRIORITY DESC, DAYS_OVERDUE DESC LIMIT 50").to_pandas()
    if not gaps.empty:
        gaps["DAYS_OVERDUE"] = pd.to_numeric(gaps["DAYS_OVERDUE"], errors="coerce")
        st.metric("Active Care Gaps", f"{len(gaps)}+ (showing top 50)")
        gap_dist = gaps.groupby("GAP_TYPE").size().reset_index(name="COUNT")
        fig = px.pie(gap_dist, values="COUNT", names="GAP_TYPE", title="Gap Type Distribution")
        fig.update_layout(height=300, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)
        st.dataframe(gaps, use_container_width=True)

with tab4:
    st.subheader("FHIR Data Quality Monitoring")
    fhir = session.sql("SELECT VALIDATION_STATUS, COUNT(*) AS CNT FROM HEALTHCARE_INTEGRATION.CURATED.FHIR_VALIDATION_RESULTS GROUP BY VALIDATION_STATUS ORDER BY CNT DESC").to_pandas()
    if not fhir.empty:
        fhir["CNT"] = pd.to_numeric(fhir["CNT"], errors="coerce")
        total = fhir["CNT"].sum()
        valid = fhir[fhir["VALIDATION_STATUS"]=="VALID"]["CNT"].sum()
        error_pct = (1 - valid/total) * 100 if total > 0 else 0
        c1, c2, c3 = st.columns(3)
        c1.metric("Total Records", f"{total:,.0f}")
        c2.metric("Valid", f"{valid:,.0f}")
        c3.metric("Error Rate", f"{error_pct:.1f}%")
        fig = px.pie(fhir, values="CNT", names="VALIDATION_STATUS", title="Validation Status Distribution",
                     color_discrete_map={"VALID": "#00C851", "MISSING_REF": "#FF4B4B", "INVALID_CODE": "#FF8C00", "INVALID_DATE_SEQUENCE": "#FFA500"})
        fig.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

with tab5:
    st.subheader("Ask the Data")
    samples = ["How many diabetic patients missed their HbA1c?", "What is the readmission rate by condition?", "Which measures are below 80% compliance?"]
    sel = st.selectbox("Sample questions:", [""] + samples)
    user_q = st.text_input("Or type your question:") or sel
    if user_q:
        with st.spinner("Cortex Analyst..."):
            try:
                request_body = {"messages": [{"role": "user", "content": [{"type": "text", "text": user_q}]}], "semantic_view": "HEALTHCARE_INTEGRATION.AI.INTEGRATION_SEMANTIC_VIEW"}
                resp = _snowflake.send_snow_api_request("POST", "/api/v2/cortex/analyst/message", {}, {}, request_body, None, 30000)
                parsed = json.loads(resp["content"])
                if resp["status"] < 400:
                    for block in parsed.get("message", {}).get("content", []):
                        if block.get("type") == "text": st.markdown(block.get("text", ""))
                        elif block.get("type") == "sql":
                            sql = block.get("statement", "")
                            st.code(sql, language="sql")
                            try: st.dataframe(session.sql(sql).to_pandas(), use_container_width=True)
                            except: pass
            except Exception as e:
                st.error(f"Error: {e}")
