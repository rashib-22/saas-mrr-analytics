

CREATE TABLE IF NOT EXISTS raw_stripe_events (
    subscription_id   VARCHAR(50)    NOT NULL,
    customer_id       VARCHAR(50)    NOT NULL,
    customer_name     VARCHAR(100)   DEFAULT NULL,
    plan_name         VARCHAR(50)    DEFAULT NULL,
    mrr_amount        DECIMAL(10,2)  NOT NULL,
    previous_mrr      DECIMAL(10,2)  DEFAULT NULL,
    status            VARCHAR(20)    NOT NULL,
    start_date        DATE           NOT NULL,
    end_date          DATE           DEFAULT NULL,
    PRIMARY KEY (subscription_id),
    INDEX idx_stripe_customer   (customer_id),
    INDEX idx_stripe_start_date (start_date),
    INDEX idx_stripe_status     (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
