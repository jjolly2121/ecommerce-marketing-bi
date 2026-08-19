-- BigQuery GoogleSQL
-- Grain: one row for the full documented sample window.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_executive_scorecard` AS
WITH session_kpis AS (
  SELECT
    MIN(session_date) AS min_session_date,
    MAX(session_date) AS max_session_date,
    COUNT(*) AS sessions,
    COUNT(DISTINCT user_pseudo_id) AS users,
    SUM(has_product_view) AS product_view_sessions,
    SUM(has_add_to_cart) AS add_to_cart_sessions,
    SUM(has_begin_checkout) AS checkout_sessions,
    SUM(has_purchase) AS purchase_sessions,
    SUM(IF(has_add_to_cart = 1 AND has_purchase = 0, 1, 0)) AS abandoned_cart_sessions,
    SUM(IF(has_begin_checkout = 1 AND has_purchase = 1, 1, 0)) AS checkout_and_purchase_sessions,
    SUM(transaction_count) AS transactions,
    SUM(session_revenue_usd) AS revenue_usd
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
), customer_kpis AS (
  SELECT
    COUNT(*) AS purchasers,
    COUNTIF(is_repeat_purchaser) AS repeat_purchasers,
    APPROX_QUANTILES(days_to_second_observed_purchase, 100)[SAFE_OFFSET(50)]
      AS median_days_to_second_observed_purchase
  FROM `YOUR_PROJECT_ID.marketing_analytics.mart_customer_summary`
)
SELECT
  s.*,
  c.*,
  SAFE_DIVIDE(s.product_view_sessions, s.sessions) AS product_view_rate,
  SAFE_DIVIDE(s.add_to_cart_sessions, s.product_view_sessions) AS add_to_cart_rate,
  SAFE_DIVIDE(s.abandoned_cart_sessions, s.add_to_cart_sessions) AS cart_abandonment_rate,
  SAFE_DIVIDE(s.checkout_and_purchase_sessions, s.checkout_sessions) AS checkout_completion_rate,
  SAFE_DIVIDE(s.purchase_sessions, s.sessions) AS session_conversion_rate,
  SAFE_DIVIDE(s.revenue_usd, s.transactions) AS average_order_value_usd,
  SAFE_DIVIDE(c.repeat_purchasers, c.purchasers) AS observed_repeat_purchase_rate
FROM session_kpis AS s
CROSS JOIN customer_kpis AS c;

