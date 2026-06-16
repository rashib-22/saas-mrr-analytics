

CREATE OR REPLACE VIEW stg_stripe_mrr_events AS

SELECT
    subscription_id,
    customer_id,
    customer_name,
    plan_name,
    mrr_amount,
    previous_mrr,
    status,
    start_date,
    end_date,
    DATE_FORMAT(start_date, '%Y-%m-01') AS event_month,

    CASE
        WHEN status = 'reactivation' THEN 'reactivation'
        WHEN status = 'cancelled' THEN 'churn'
        WHEN status = 'active' AND previous_mrr IS NULL THEN 'new'
        WHEN status = 'active' AND mrr_amount > previous_mrr THEN 'expansion'
        WHEN status = 'active' AND mrr_amount < previous_mrr THEN 'contraction'
        ELSE 'unchanged'
    END AS mrr_type,

    CASE
        WHEN status = 'reactivation' THEN mrr_amount
        WHEN status = 'cancelled' THEN -previous_mrr
        WHEN status = 'active' AND previous_mrr IS NULL THEN mrr_amount
        WHEN status = 'active' AND mrr_amount <> previous_mrr THEN mrr_amount - previous_mrr
        ELSE 0
    END AS mrr_delta,
    'stripe' AS data_source
FROM raw_stripe_events
WHERE NOT (
    status = 'active'
    AND previous_mrr IS NOT NULL
    AND mrr_amount = previous_mrr
);
