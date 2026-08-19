-- BigQuery GoogleSQL
-- Grain: pseudonymous user with at least one valid observed transaction.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_customer_summary` AS
WITH customer_rollup AS (
  SELECT
    user_pseudo_id,
    MIN(order_date) AS first_observed_purchase_date,
    MAX(order_date) AS last_observed_purchase_date,
    COUNT(*) AS transaction_count,
    SUM(COALESCE(order_revenue_usd, 0)) AS observed_revenue_usd,
    AVG(order_revenue_usd) AS average_order_value_usd,
    ARRAY_AGG(order_date ORDER BY order_ts, order_key)[SAFE_OFFSET(1)] AS second_observed_purchase_date,
    COUNT(DISTINCT DATE_TRUNC(order_date, MONTH)) AS active_purchase_months
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`
  GROUP BY user_pseudo_id
)
SELECT
  *,
  transaction_count >= 2 AS is_repeat_purchaser,
  DATE_DIFF(second_observed_purchase_date, first_observed_purchase_date, DAY)
    AS days_to_second_observed_purchase,
  DATE_DIFF(last_observed_purchase_date, first_observed_purchase_date, DAY)
    AS observed_customer_span_days,
  CASE
    WHEN transaction_count = 1 THEN 'One-time Purchaser'
    WHEN transaction_count BETWEEN 2 AND 3 THEN 'Repeat Purchaser (2-3)'
    WHEN transaction_count >= 4 THEN 'Loyal Purchaser (4+)'
  END AS customer_segment
FROM customer_rollup;
