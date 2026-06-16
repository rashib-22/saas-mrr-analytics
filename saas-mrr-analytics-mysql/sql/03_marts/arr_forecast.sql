
CREATE OR REPLACE VIEW arr_forecast AS

WITH current_mrr AS (
    SELECT SUM(mrr_amount) AS total_mrr
    FROM stg_mrr_unified
    WHERE status IN ('active', 'reactivation')
      AND end_date IS NULL
),

monthly_net AS (
    SELECT
        event_month AS month,
        SUM(mrr_delta) AS net_new_mrr
    FROM stg_mrr_unified
    GROUP BY event_month
),

trailing_avg AS (
    SELECT ROUND(AVG(net_new_mrr), 2) AS avg_monthly_growth
    FROM (
        SELECT net_new_mrr
        FROM monthly_net
        ORDER BY month DESC
        LIMIT 6
    ) AS last_six
)

SELECT
    ROUND(c.total_mrr, 2) AS current_mrr,
    ROUND(c.total_mrr * 12, 2) AS current_arr,
    t.avg_monthly_growth,
    ROUND((c.total_mrr + t.avg_monthly_growth * 3) * 12, 2) AS projected_arr_90d,
    ROUND(
        100.0 * (t.avg_monthly_growth * 12)
        / NULLIF(c.total_mrr * 12, 0),
    1) AS implied_annual_growth_pct
FROM current_mrr c
CROSS JOIN trailing_avg t;
