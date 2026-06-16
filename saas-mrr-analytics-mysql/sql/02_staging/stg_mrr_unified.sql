

CREATE OR REPLACE VIEW stg_mrr_unified AS
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
    event_month,
    mrr_type,
    mrr_delta,
    data_source
FROM stg_telco_events

UNION ALL

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
    event_month,
    mrr_type,
    mrr_delta,
    data_source
FROM stg_stripe_mrr_events;
