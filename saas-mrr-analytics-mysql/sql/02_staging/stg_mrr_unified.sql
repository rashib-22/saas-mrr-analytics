-- ============================================================
-- stg_mrr_unified.sql  |  MySQL  —  Unified MRR staging view
-- ============================================================
-- BUG FIX: Previously referenced stg_telco_as_mrr (a view with
-- a broken recursive CTE). Now references stg_telco_events
-- (a physical table loaded by load_stg_telco_events procedure).
-- This makes the unified view fast and reliable.
-- ============================================================

CREATE OR REPLACE VIEW stg_mrr_unified AS

-- Source 1: IBM Telco (real data — physical table)
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

-- Source 2: Stripe-modeled events
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
