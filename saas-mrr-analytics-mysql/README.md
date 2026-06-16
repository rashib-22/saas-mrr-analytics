# SaaS MRR Analytics

I wanted to practice building a proper MRR dashboard — the kind finance teams actually use — but couldn't find a dataset that worked. Everything on Kaggle is either a customer snapshot with no billing events, or completely synthetic with no real-world grounding.

So I did both.

I took the IBM Telco churn dataset (7,043 real customers, real monthly charges, real cancellations) and combined it with a Stripe-style event log I generated in Python. The result is a MySQL pipeline with 17,000 rows, a proper 5-component MRR waterfall, cohort retention, NRR calculation, and a Power BI dashboard.


## What it does

Takes raw subscription data from two sources and turns it into the metrics a SaaS CFO looks at every Monday morning:

- MRR waterfall — new, expansion, contraction, churn, reactivation broken out by month
- Cohort retention — what % of customers from month X are still active in month X+N
- NRR — Net Revenue Retention, the metric investors care about at Series A/B
- ARR forecast — current run rate + 90-day projection based on trailing 6-month growth
- Churn analysis — when customers leave, which contract types churn most, source comparison


## The data

**Source 1 — IBM Telco Customer Churn**
Real data. 7,043 customers. Has tenure, monthly charges, contract type (month-to-month / one year / two year), and a churn flag. What it doesn't have: any plan changes. Every customer pays the same amount every month — no upgrades, no downgrades. That's a real limitation of this dataset and worth knowing upfront.

Download it here → [kaggle.com/datasets/blastchar/telco-customer-churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)

**Source 2 — Stripe-style events (synthetic)**
8,196 billing events I generated using Python. Covers 2,491 customers across 74 months (Jan 2019 – Feb 2025) with realistic churn and expansion probability curves per plan tier. Five plans: Starter ($99), Pro ($299), Growth ($499), Enterprise ($799), Enterprise Plus ($999).

The generator script is in `data/generate_mrr_data.py` if you want to tweak the parameters and regenerate.

## Project structure

```
saas-mrr-analytics-mysql/
│

├── data/
│   ├── subscriptions_large.csv          
│   ├── generate_mrr_data.py          
│   └── WA_Fn-UseC_-Telco-Customer-Churn.csv   
│
├── sql/
│   ├── 01_schema/              
│   ├── 02_staging/             
│   ├── 03_marts/               
│   ├── 04_analysis/            
│   └── 05_tests/               
│



## What I found

**Contract type is the biggest churn lever — by a lot**
This came from the real Telco data, not the synthetic stuff. Month-to-month customers churn at 42.7%. One-year contract customers churn at 11.3%. Two-year contract customers churn at 2.8%. Same product, same price range, 15× difference. That's not a product problem. That's a commitment and expectation-setting problem that customer success can actually fix.

**Most churn happens early**
60% of churned customers across both sources left within the first 3 months. After month 3, the curve flattens significantly. This tells you the problem is onboarding and activation, not long-term value. The customers who make it to month 4 tend to stay.

**Expansion revenue matters more than new logos by Year 4**
By 2023 in the modeled data, about 35% of net-new MRR was coming from existing customers upgrading — not from new signups. That ratio is what separates a business that needs to constantly acquire to survive from one that can grow from its existing base.

**NRR crossed 100% from mid-2022**
NRR above 100% means existing customers are growing your revenue faster than other customers are churning. It's the metric that tells investors the business model works independent of sales. Getting it above 100% in the model required expansion rates to outpace contraction and churn combined — which the Stripe data shows happening gradually from 2021 onward.

**Telco and Stripe churn rates are almost identical**
Telco: 26.6%, Stripe-modeled: 26.4%. Not planned — the Python generator was calibrated to realistic SaaS benchmarks and landed close to the real dataset independently. Useful validation that the synthetic data isn't wildly off.


