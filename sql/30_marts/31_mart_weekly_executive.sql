-- BigQuery GoogleSQL
-- Grain: calendar week. Demonstrates reusable period-over-period reporting.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_weekly_executive` AS
WITH weekly AS (
  SELECT
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,
    COUNT(*) AS sessions,
    COUNT(DISTINCT user_pseudo_id) AS users,
    SUM(has_product_view) AS product_view_sessions,
    SUM(has_add_to_cart) AS add_to_cart_sessions,
    SUM(has_begin_checkout) AS checkout_sessions,
    SUM(has_purchase) AS purchase_sessions,
    SUM(transaction_count) AS transactions,
    SUM(session_revenue_usd) AS revenue_usd
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
  GROUP BY week_start
), with_rates AS (
  SELECT
    *,
    SAFE_DIVIDE(purchase_sessions, sessions) AS session_conversion_rate,
    SAFE_DIVIDE(revenue_usd, transactions) AS average_order_value_usd
  FROM weekly
)
SELECT
  *,
  LAG(sessions) OVER (ORDER BY week_start) AS previous_week_sessions,
  LAG(revenue_usd) OVER (ORDER BY week_start) AS previous_week_revenue_usd,
  LAG(session_conversion_rate) OVER (ORDER BY week_start) AS previous_week_conversion_rate,
  SAFE_DIVIDE(
    revenue_usd - LAG(revenue_usd) OVER (ORDER BY week_start),
    LAG(revenue_usd) OVER (ORDER BY week_start)
  ) AS revenue_week_over_week_change,
  session_conversion_rate
    - LAG(session_conversion_rate) OVER (ORDER BY week_start) AS conversion_week_over_week_point_change,
  AVG(revenue_usd) OVER (
    ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
  ) AS revenue_four_week_moving_average
FROM with_rates;

