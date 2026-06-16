-- ============================================================
-- arr_forecast.sql  |  MySQL 8.0  —  ARR & 90-Day Forecast
-- ============================================================
-- BUG FIX: Previous version read from raw_stripe_events only.
-- Should read from stg_mrr_unified to include Telco MRR in
-- current_mrr and monthly_net calculations.
--
-- Also fixed: current_mrr used end_date IS NULL filter which
-- is correct for Stripe but Telco rows have NULL end_dates too
-- for active customers — no change needed there, but added
-- a comment for clarity.
-- ============================================================

CREATE OR REPLACE VIEW arr_forecast AS

WITH current_mrr AS (
    -- Sum MRR across ALL active subscriptions (both sources)
    SELECT SUM(mrr_amount) AS total_mrr
    FROM stg_mrr_unified
    WHERE status IN ('active', 'reactivation')
      AND end_date IS NULL
),

monthly_net AS (
    -- Net-new MRR per month across both sources
    SELECT
        event_month                                        AS month,
        SUM(mrr_delta)                                     AS net_new_mrr
    FROM stg_mrr_unified
    GROUP BY event_month
),

trailing_avg AS (
    -- 6-month trailing average — more stable than 3-month
    SELECT ROUND(AVG(net_new_mrr), 2)                      AS avg_monthly_growth
    FROM (
        SELECT net_new_mrr
        FROM monthly_net
        ORDER BY month DESC
        LIMIT 6
    ) AS last_six
)

SELECT
    ROUND(c.total_mrr, 2)                                  AS current_mrr,
    ROUND(c.total_mrr * 12, 2)                             AS current_arr,
    t.avg_monthly_growth,
    ROUND((c.total_mrr + t.avg_monthly_growth * 3) * 12, 2)
                                                           AS projected_arr_90d,
    ROUND(
        100.0 * (t.avg_monthly_growth * 12)
        / NULLIF(c.total_mrr * 12, 0),
    1)                                                     AS implied_annual_growth_pct
FROM current_mrr c
CROSS JOIN trailing_avg t;
