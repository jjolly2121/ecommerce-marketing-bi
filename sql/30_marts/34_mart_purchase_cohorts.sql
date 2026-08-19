-- BigQuery GoogleSQL
-- Grain: first-observed-purchase cohort month x months since first observed purchase.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_purchase_cohorts` AS
WITH customer_cohort AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(first_observed_purchase_date, MONTH) AS cohort_month
  FROM `YOUR_PROJECT_ID.marketing_analytics.mart_customer_summary`
), cohort_size AS (
  SELECT
    cohort_month,
    COUNT(*) AS cohort_purchasers
  FROM customer_cohort
  GROUP BY cohort_month
), activity AS (
  SELECT
    c.cohort_month,
    DATE_TRUNC(o.order_date, MONTH) AS purchase_month,
    DATE_DIFF(DATE_TRUNC(o.order_date, MONTH), c.cohort_month, MONTH) AS months_since_first_purchase,
    COUNT(DISTINCT o.user_pseudo_id) AS active_purchasers,
    COUNT(DISTINCT o.order_key) AS transactions,
    SUM(COALESCE(o.order_revenue_usd, 0)) AS revenue_usd
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders` AS o
  JOIN customer_cohort AS c
    USING (user_pseudo_id)
  GROUP BY cohort_month, purchase_month, months_since_first_purchase
)
SELECT
  a.*,
  s.cohort_purchasers,
  SAFE_DIVIDE(a.active_purchasers, s.cohort_purchasers) AS observed_purchaser_retention_rate,
  SAFE_DIVIDE(a.revenue_usd, a.active_purchasers) AS revenue_per_active_purchaser_usd
FROM activity AS a
JOIN cohort_size AS s
  USING (cohort_month);
