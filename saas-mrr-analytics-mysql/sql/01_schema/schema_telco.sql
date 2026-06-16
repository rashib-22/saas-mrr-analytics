-- ============================================================
-- schema_telco.sql  |  MySQL  —  Raw IBM Telco customers table
-- ============================================================
-- SOURCE: IBM Telco Customer Churn (Kaggle)
-- URL: kaggle.com/datasets/blastchar/telco-customer-churn
-- FILE: WA_Fn-UseC_-Telco-Customer-Churn.csv  (7,043 rows)
-- ============================================================

CREATE TABLE IF NOT EXISTS raw_telco_customers (
    customer_id        VARCHAR(50)   NOT NULL,
    gender             VARCHAR(10)   DEFAULT NULL,
    senior_citizen     TINYINT       DEFAULT 0,
    partner            VARCHAR(5)    DEFAULT NULL,
    dependents         VARCHAR(5)    DEFAULT NULL,
    tenure             INT           DEFAULT 0,
    phone_service      VARCHAR(5)    DEFAULT NULL,
    multiple_lines     VARCHAR(20)   DEFAULT NULL,
    internet_service   VARCHAR(20)   DEFAULT NULL,
    online_security    VARCHAR(20)   DEFAULT NULL,
    online_backup      VARCHAR(20)   DEFAULT NULL,
    device_protection  VARCHAR(20)   DEFAULT NULL,
    tech_support       VARCHAR(20)   DEFAULT NULL,
    streaming_tv       VARCHAR(20)   DEFAULT NULL,
    streaming_movies   VARCHAR(20)   DEFAULT NULL,
    contract           VARCHAR(20)   DEFAULT NULL,
    paperless_billing  VARCHAR(5)    DEFAULT NULL,
    payment_method     VARCHAR(40)   DEFAULT NULL,
    monthly_charges    DECIMAL(8,2)  DEFAULT NULL,
    total_charges      VARCHAR(20)   DEFAULT NULL,
    churn              VARCHAR(5)    DEFAULT NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_telco_tenure (tenure),
    INDEX idx_telco_churn  (churn)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
