-- BigQuery GoogleSQL
-- Grain: date x acquisition x device x geography x user type.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_daily_performance` AS
WITH daily AS (
  SELECT
    session_date,
    acquisition_channel,
    acquisition_source,
    acquisition_medium,
    acquisition_campaign,
    device_category,
    country,
    user_type,
    COUNT(*) AS sessions,
    COUNT(DISTINCT user_pseudo_id) AS users,
    SUM(is_engaged_session) AS engaged_sessions,
    SUM(has_product_view) AS product_view_sessions,
    SUM(has_add_to_cart) AS add_to_cart_sessions,
    SUM(has_begin_checkout) AS checkout_sessions,
    SUM(has_purchase) AS purchase_sessions,
    SUM(IF(has_add_to_cart = 1 AND has_purchase = 0, 1, 0)) AS abandoned_cart_sessions,
    SUM(IF(has_add_to_cart = 1 AND has_purchase = 1, 1, 0)) AS cart_and_purchase_sessions,
    SUM(IF(has_begin_checkout = 1 AND has_purchase = 1, 1, 0)) AS checkout_and_purchase_sessions,
    SUM(transaction_count) AS transactions,
    SUM(session_revenue_usd) AS revenue_usd,
    SUM(event_count) AS events,
    SUM(page_view_count) AS page_views,
    SUM(engagement_time_seconds) AS engagement_time_seconds
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
  GROUP BY
    session_date,
    acquisition_channel,
    acquisition_source,
    acquisition_medium,
    acquisition_campaign,
    device_category,
    country,
    user_type
)
SELECT
  *,
  SAFE_DIVIDE(engaged_sessions, sessions) AS engagement_rate,
  SAFE_DIVIDE(product_view_sessions, sessions) AS product_view_rate,
  SAFE_DIVIDE(add_to_cart_sessions, product_view_sessions) AS add_to_cart_rate,
  SAFE_DIVIDE(abandoned_cart_sessions, add_to_cart_sessions) AS cart_abandonment_rate,
  SAFE_DIVIDE(checkout_and_purchase_sessions, checkout_sessions) AS checkout_completion_rate,
  SAFE_DIVIDE(purchase_sessions, sessions) AS session_conversion_rate,
  SAFE_DIVIDE(revenue_usd, transactions) AS average_order_value_usd,
  SAFE_DIVIDE(revenue_usd, sessions) AS revenue_per_session_usd,
  SAFE_DIVIDE(engagement_time_seconds, sessions) AS avg_engagement_seconds_per_session
FROM daily;
