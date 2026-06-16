
USE saas_mrr;

DROP TABLE IF EXISTS stg_telco_events;

CREATE TABLE stg_telco_events (
    subscription_id  VARCHAR(80)    NOT NULL,
    customer_id      VARCHAR(60)    NOT NULL,
    customer_name    VARCHAR(110)   DEFAULT NULL,
    plan_name        VARCHAR(50)    DEFAULT NULL,
    mrr_amount       DECIMAL(10,2)  NOT NULL,
    previous_mrr     DECIMAL(10,2)  DEFAULT NULL,
    status           VARCHAR(20)    NOT NULL,
    start_date       DATE           NOT NULL,
    end_date         DATE           DEFAULT NULL,
    event_month      DATE           NOT NULL,
    mrr_type         VARCHAR(20)    NOT NULL,
    mrr_delta        DECIMAL(10,2)  NOT NULL,
    data_source      VARCHAR(20)    NOT NULL DEFAULT 'telco',
    PRIMARY KEY (subscription_id),
    INDEX idx_tel_customer (customer_id),
    INDEX idx_tel_month    (event_month),
    INDEX idx_tel_type     (mrr_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO stg_telco_events
SELECT
    CONCAT('t_', TRIM(customer_id), '_m001'),
    CONCAT('tel_', TRIM(customer_id)),
    CONCAT('Telco_', TRIM(customer_id)),
    CASE TRIM(contract)
        WHEN 'Month-to-month' THEN 'starter'
        WHEN 'One year'       THEN 'pro'
        WHEN 'Two year'       THEN 'enterprise'
        ELSE 'starter'
    END,
    monthly_charges,
    NULL,
    'active',
    '2019-01-01',
    NULL,
    '2019-01-01',
    'new',
    monthly_charges,
    'telco'
FROM raw_telco_customers
WHERE monthly_charges > 0;


SELECT 'NEW rows' AS event_type, COUNT(*) AS total FROM stg_telco_events;


INSERT INTO stg_telco_events
SELECT
    CONCAT('t_', TRIM(customer_id), '_churn'),
    CONCAT('tel_', TRIM(customer_id)),
    CONCAT('Telco_', TRIM(customer_id)),
    CASE TRIM(contract)
        WHEN 'Month-to-month' THEN 'starter'
        WHEN 'One year'       THEN 'pro'
        WHEN 'Two year'       THEN 'enterprise'
        ELSE 'starter'
    END,
    monthly_charges,
    monthly_charges,
    'cancelled',
    DATE_ADD('2019-01-01', INTERVAL tenure MONTH),
    DATE_ADD('2019-01-01', INTERVAL tenure MONTH),
    DATE_ADD('2019-01-01', INTERVAL tenure MONTH),
    'churn',
    -monthly_charges,
    'telco'
FROM raw_telco_customers
WHERE TRIM(churn) = 'Yes'
  AND monthly_charges > 0;

SELECT mrr_type, COUNT(*) AS total
FROM stg_telco_events
GROUP BY mrr_type;

CREATE OR REPLACE VIEW stg_mrr_unified AS
SELECT subscription_id, customer_id, customer_name, plan_name,
       mrr_amount, previous_mrr, status, start_date, end_date,
       event_month, mrr_type, mrr_delta, data_source
FROM stg_telco_events
UNION ALL
SELECT subscription_id, customer_id, customer_name, plan_name,
       mrr_amount, previous_mrr, status, start_date, end_date,
       event_month, mrr_type, mrr_delta, data_source
FROM stg_stripe_mrr_events;

SELECT
    data_source,
    COUNT(DISTINCT CASE WHEN mrr_type='new'   THEN customer_id END) AS total_customers,
    COUNT(DISTINCT CASE WHEN mrr_type='churn' THEN customer_id END) AS churned_customers,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN mrr_type='churn' THEN customer_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN mrr_type='new'  THEN customer_id END),0),
    1) AS logo_churn_pct
FROM stg_mrr_unified
GROUP BY data_source;
