-- ============================================================
-- mrr_waterfall.sql  |  MySQL  —  MRR Waterfall mart
-- ============================================================
-- MySQL change: window function SUM() OVER () is supported
-- in MySQL 8.0+. No changes needed to window syntax.
-- DATE_FORMAT already applied in stg_mrr_unified so
-- event_month is already a DATE string '2019-01-01' format.
-- ============================================================

CREATE OR REPLACE VIEW mrr_waterfall AS

WITH monthly AS (
    SELECT
        event_month,
        SUM(CASE WHEN mrr_type = 'new'          THEN mrr_delta ELSE 0 END)  AS new_mrr,
        SUM(CASE WHEN mrr_type = 'expansion'    THEN mrr_delta ELSE 0 END)  AS expansion_mrr,
        SUM(CASE WHEN mrr_type = 'reactivation' THEN mrr_delta ELSE 0 END)  AS reactivation_mrr,
        SUM(CASE WHEN mrr_type = 'contraction'  THEN mrr_delta ELSE 0 END)  AS contraction_mrr,
        SUM(CASE WHEN mrr_type = 'churn'        THEN mrr_delta ELSE 0 END)  AS churned_mrr,
        SUM(mrr_delta)                                                        AS net_new_mrr,
        COUNT(DISTINCT CASE WHEN mrr_type = 'new'   THEN customer_id END)   AS new_customers,
        COUNT(DISTINCT CASE WHEN mrr_type = 'churn' THEN customer_id END)   AS churned_customers
    FROM stg_mrr_unified
    GROUP BY event_month
)

SELECT
    event_month,
    new_mrr,
    expansion_mrr,
    reactivation_mrr,
    contraction_mrr,
    churned_mrr,
    net_new_mrr,

    -- Window functions: supported in MySQL 8.0+ ✅
    SUM(net_new_mrr) OVER (
        ORDER BY event_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                                         AS cumulative_mrr,

    new_customers,
    churned_customers,

    ROUND(
        100.0 * churned_customers
        / NULLIF(
            SUM(new_customers) OVER (
                ORDER BY event_month
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0
        ), 2
    )                                                                         AS logo_churn_pct

FROM monthly
ORDER BY event_month;
