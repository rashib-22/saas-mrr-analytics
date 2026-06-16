
-- Test 1: No customer should have two 'new' events
SELECT customer_id, COUNT(*) AS new_count
FROM stg_mrr_unified
WHERE mrr_type = 'new'
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Test 2: Churned MRR delta should always be negative
SELECT * FROM stg_mrr_unified
WHERE mrr_type = 'churn' AND mrr_delta >= 0;

-- Test 3: New events should never have previous_mrr
SELECT * FROM stg_mrr_unified
WHERE mrr_type = 'new' AND previous_mrr IS NOT NULL;

-- Test 4: No negative MRR amounts
SELECT * FROM stg_mrr_unified
WHERE mrr_amount <= 0;

-- Test 5: Expansion delta must be positive
SELECT * FROM stg_mrr_unified
WHERE mrr_type = 'expansion' AND mrr_delta <= 0;

-- Test 6: Cancelled rows must have an end_date
SELECT * FROM stg_mrr_unified
WHERE status = 'cancelled' AND end_date IS NULL;

-- Test 7: No duplicate subscription IDs
SELECT subscription_id, COUNT(*) AS cnt
FROM stg_mrr_unified
GROUP BY subscription_id
HAVING COUNT(*) > 1;
