
-- Data quality check 
SELECT 'total_events'    AS metric, COUNT(*) AS value FROM stg_mrr_unified
UNION ALL SELECT 'telco_events',    COUNT(*) FROM stg_mrr_unified WHERE data_source = 'telco'
UNION ALL SELECT 'stripe_events',   COUNT(*) FROM stg_mrr_unified WHERE data_source = 'stripe'
UNION ALL SELECT 'new_subs',        COUNT(*) FROM stg_mrr_unified WHERE mrr_type = 'new'
UNION ALL SELECT 'expansions',      COUNT(*) FROM stg_mrr_unified WHERE mrr_type = 'expansion'
UNION ALL SELECT 'contractions',    COUNT(*) FROM stg_mrr_unified WHERE mrr_type = 'contraction'
UNION ALL SELECT 'churns',          COUNT(*) FROM stg_mrr_unified WHERE mrr_type = 'churn'
UNION ALL SELECT 'reactivations',   COUNT(*) FROM stg_mrr_unified WHERE mrr_type = 'reactivation'
UNION ALL SELECT 'null_mrr_deltas', COUNT(*) FROM stg_mrr_unified WHERE mrr_delta IS NULL;


--  1. MRR contribution by source 
SELECT
    data_source,
    COUNT(DISTINCT customer_id)  AS unique_customers,
    COUNT(*) AS total_events,
    ROUND(SUM(CASE WHEN mrr_type='new'   THEN mrr_delta ELSE 0 END), 2) AS new_mrr,
    ROUND(SUM(CASE WHEN mrr_type='churn' THEN mrr_delta ELSE 0 END), 2) AS churned_mrr,
    ROUND(SUM(mrr_delta), 2) AS net_mrr_contribution
FROM stg_mrr_unified
GROUP BY data_source;


--  2. Full MRR waterfall 
SELECT * FROM mrr_waterfall ORDER BY event_month;


--  3. Revenue mix by plan and source 
SELECT
    plan_name,
    data_source,
    COUNT(DISTINCT customer_id)  AS customers,
    ROUND(AVG(mrr_amount), 2) AS avg_mrr,
    ROUND(SUM(CASE WHEN mrr_type='new' THEN mrr_delta ELSE 0 END), 2) AS total_new_mrr
FROM stg_mrr_unified
WHERE mrr_type = 'new'
GROUP BY plan_name, data_source
ORDER BY total_new_mrr DESC;


--  4. Churn comparison: Telco vs Stripe 
SELECT
    src.data_source,
    src.total_customers,
    src.churned_customers,
    ROUND(100.0 * src.churned_customers
          / NULLIF(src.total_customers, 0), 1)  AS logo_churn_pct,
    ROUND(ABS(src.churned_mrr), 2)                               AS total_churned_mrr
FROM (
    SELECT
        data_source,
        COUNT(DISTINCT CASE WHEN mrr_type = 'new'   THEN customer_id END) AS total_customers,
        COUNT(DISTINCT CASE WHEN mrr_type = 'churn' THEN customer_id END) AS churned_customers,
        SUM(CASE WHEN mrr_type = 'churn' THEN mrr_delta ELSE 0 END)  AS churned_mrr
    FROM stg_mrr_unified
    GROUP BY data_source
) AS src
ORDER BY data_source;


--  5. Contract type analysis 
SELECT
    contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn='Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 1)  AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2) AS avg_monthly_charges,
    ROUND(AVG(tenure), 1) AS avg_tenure_months
FROM raw_telco_customers
WHERE monthly_charges > 0
GROUP BY contract
ORDER BY churn_rate_pct DESC;


-- 6. NRR monthly -- 
WITH monthly_snapshot AS (
    SELECT
        event_month,
        SUM(net_new_mrr) OVER (
            ORDER BY event_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS end_of_month_mrr
    FROM (
        SELECT event_month, SUM(mrr_delta) AS net_new_mrr
        FROM stg_mrr_unified
        GROUP BY event_month
    ) AS monthly
),
nrr_calc AS (
    SELECT
        cur.event_month,
        LAG(cur.end_of_month_mrr) OVER (ORDER BY cur.event_month)  AS starting_mrr,

        SUM(CASE WHEN u.mrr_type='expansion'   THEN u.mrr_delta ELSE 0 END)  AS expansion,
												
        SUM(CASE WHEN u.mrr_type='contraction' THEN u.mrr_delta ELSE 0 END) AS contraction,
                                                  
        SUM(CASE WHEN u.mrr_type='churn' THEN u.mrr_delta ELSE 0 END)  AS churn
    FROM monthly_snapshot cur
    JOIN stg_mrr_unified u ON DATE_FORMAT(u.start_date,'%Y-%m-01') = cur.event_month
    GROUP BY cur.event_month, cur.end_of_month_mrr
)
SELECT
    event_month,
    ROUND(starting_mrr, 2) AS starting_mrr,
    ROUND(expansion, 2) AS expansion_mrr,
    ROUND(contraction, 2) AS contraction_mrr,
    ROUND(churn, 2) AS churn_mrr,
    ROUND(
        100.0 * (starting_mrr + expansion + contraction + churn)
        / NULLIF(starting_mrr, 0),
    1)                                             AS nrr_pct
FROM nrr_calc
WHERE starting_mrr IS NOT NULL
ORDER BY event_month;


--  7. Upgrade paths 
SELECT
    CASE
        WHEN previous_mrr =  99  THEN 'starter'
        WHEN previous_mrr = 299  THEN 'pro'
        WHEN previous_mrr = 499  THEN 'growth'
        WHEN previous_mrr = 799  THEN 'enterprise'
        ELSE 'other'
    END  AS from_plan,
    plan_name  AS to_plan,
    COUNT(*) AS upgrade_count,
    ROUND(AVG(mrr_amount - previous_mrr), 2) AS avg_mrr_uplift
FROM stg_mrr_unified
WHERE mrr_type = 'expansion'
  AND data_source = 'stripe'
GROUP BY from_plan, plan_name
ORDER BY upgrade_count DESC;


-- 8. Churn timing 
WITH first_seen AS (
    SELECT customer_id, MIN(start_date) AS first_date
    FROM stg_mrr_unified
    WHERE mrr_type = 'new'
    GROUP BY customer_id
),
churn_evts AS (
    SELECT
        u.customer_id,
        TIMESTAMPDIFF(MONTH, f.first_date, u.start_date) AS months_to_churn
    FROM stg_mrr_unified u
    JOIN first_seen f ON u.customer_id = f.customer_id
    WHERE u.mrr_type = 'churn'
)
SELECT
    CASE
        WHEN months_to_churn <= 3  THEN '0-3 months'
        WHEN months_to_churn <= 6  THEN '4-6 months'
        WHEN months_to_churn <= 12 THEN '7-12 months'
        ELSE '12+ months'
    END AS tenure_at_churn,
    COUNT(*) AS churned_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all_churned
FROM churn_evts
GROUP BY tenure_at_churn
ORDER BY MIN(months_to_churn);


-- 9. ARR forecast 
SELECT * FROM arr_forecast;


--  10. Cohort retention (2022 onwards) 
SELECT * FROM cohort_retention
WHERE cohort_month >= '2022-01-01'
ORDER BY cohort_month, month_number;
