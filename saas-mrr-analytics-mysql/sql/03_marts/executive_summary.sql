-- ============================================================
-- executive_summary.sql  |  MySQL  —  Executive mart view
-- ============================================================
-- MySQL changes:
--   • DATE_FORMAT instead of DATE_TRUNC for month flooring
--   • Window functions: fully supported MySQL 8.0+ ✅
--   • GROUP BY must list all non-aggregated columns explicitly
--     (MySQL strict mode — no implicit grouping)
-- ============================================================

CREATE OR REPLACE VIEW executive_mrr_summary AS

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
    ROUND(new_mrr, 2)                                                AS new_mrr,
    ROUND(expansion_mrr, 2)                                          AS expansion_mrr,
    ROUND(reactivation_mrr, 2)                                       AS reactivation_mrr,
    ROUND(contraction_mrr, 2)                                        AS contraction_mrr,
    ROUND(churned_mrr, 2)                                            AS churned_mrr,
    ROUND(net_new_mrr, 2)                                            AS net_new_mrr,

    ROUND(SUM(net_new_mrr) OVER (
        ORDER BY event_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                                                            AS cumulative_mrr,

    ROUND(SUM(net_new_mrr) OVER (
        ORDER BY event_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) * 12, 2)                                                       AS arr_run_rate,

    new_customers,
    churned_customers,

    ROUND(
        100.0 * net_new_mrr
        / NULLIF(
            SUM(net_new_mrr) OVER (
                ORDER BY event_month
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0
        ), 1
    )                                                                AS mrr_growth_pct,

    ROUND(
        100.0 * expansion_mrr
        / NULLIF(
            SUM(net_new_mrr) OVER (
                ORDER BY event_month
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0
        ), 1
    )                                                                AS expansion_rate_pct

FROM monthly
ORDER BY event_month;
