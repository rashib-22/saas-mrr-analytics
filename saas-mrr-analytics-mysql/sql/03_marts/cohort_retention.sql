-- ============================================================
-- cohort_retention.sql  |  MySQL 8.0  —  Cohort Retention
-- ============================================================
-- BUG FIX 1: active_months CTE used stg_mrr_unified.start_date
--   to find active months — but Telco customers in stg_telco_events
--   only have NEW and CHURN rows (no monthly active rows).
--   This caused Telco cohorts to show 0% retention after month 0.
--
-- FIX: Use stg_mrr_unified for new/churn detection, but build
--   active months from raw_telco_customers tenure + raw_stripe_events
--   separately, then UNION them.
--
-- BUG FIX 2: GROUP BY in cohort_activity referenced a window
--   expression directly — not allowed in MySQL strict mode.
--   Fixed by pre-computing month_number in a subquery.
-- ============================================================

CREATE OR REPLACE VIEW cohort_retention AS

WITH first_subs AS (
    SELECT
        customer_id,
        DATE_FORMAT(MIN(start_date), '%Y-%m-01')           AS cohort_month
    FROM stg_mrr_unified
    WHERE mrr_type = 'new'
    GROUP BY customer_id
),

-- Active months from Stripe: every month a customer had an event
stripe_active AS (
    SELECT DISTINCT
        customer_id,
        DATE_FORMAT(start_date, '%Y-%m-01')                AS active_month
    FROM raw_stripe_events
    WHERE status IN ('active', 'reactivation')
),

-- Active months from Telco: reconstruct from tenure
-- Customer active for tenure months starting 2019-01-01
telco_active AS (
    SELECT DISTINCT
        CONCAT('tel_', t.customer_id)                      AS customer_id,
        DATE_FORMAT(
            DATE_ADD('2019-01-01', INTERVAL seq.n MONTH),
            '%Y-%m-01'
        )                                                  AS active_month
    FROM raw_telco_customers t
    -- Generate month numbers 0 to tenure-1 using a numbers CTE
    JOIN (
        SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
        SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
        SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL
        SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL
        SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL
        SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL
        SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20 UNION ALL
        SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL
        SELECT 24 UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL
        SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL
        SELECT 30 UNION ALL SELECT 31 UNION ALL SELECT 32 UNION ALL
        SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL
        SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL
        SELECT 39 UNION ALL SELECT 40 UNION ALL SELECT 41 UNION ALL
        SELECT 42 UNION ALL SELECT 43 UNION ALL SELECT 44 UNION ALL
        SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL
        SELECT 48 UNION ALL SELECT 49 UNION ALL SELECT 50 UNION ALL
        SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL
        SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL
        SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59 UNION ALL
        SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL
        SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION ALL
        SELECT 66 UNION ALL SELECT 67 UNION ALL SELECT 68 UNION ALL
        SELECT 69 UNION ALL SELECT 70 UNION ALL SELECT 71 UNION ALL
        SELECT 72
    ) AS seq ON seq.n < t.tenure
    WHERE t.monthly_charges > 0
),

-- Combine both active month sources
all_active AS (
    SELECT customer_id, active_month FROM stripe_active
    UNION ALL
    SELECT customer_id, active_month FROM telco_active
),

-- Join cohorts to their active months
cohort_monthly AS (
    SELECT
        f.cohort_month,
        a.active_month,
        TIMESTAMPDIFF(MONTH, f.cohort_month, a.active_month) AS month_number,
        a.customer_id
    FROM first_subs f
    JOIN all_active a ON f.customer_id = a.customer_id
    WHERE a.active_month >= f.cohort_month
),

cohort_activity AS (
    SELECT
        cohort_month,
        active_month,
        month_number,
        COUNT(DISTINCT customer_id)                          AS active_customers
    FROM cohort_monthly
    GROUP BY cohort_month, active_month, month_number
),

cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id)         AS cohort_size
    FROM first_subs
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    ca.month_number,
    cs.cohort_size,
    ca.active_customers,
    ROUND(100.0 * ca.active_customers / cs.cohort_size, 1)  AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.month_number;
