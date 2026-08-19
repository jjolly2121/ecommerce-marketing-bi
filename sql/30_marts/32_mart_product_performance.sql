-- BigQuery GoogleSQL
-- Grain: date x item x category.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_product_performance` AS
WITH item_events AS (
  SELECT
    *,
    CASE
      WHEN transaction_id IS NOT NULL
        THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
      ELSE CONCAT(session_key, '|purchase-session-fallback')
    END AS order_key
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_item_events`
), ranked_item_events AS (
  SELECT
    *,
    MAX(IF(event_name = 'purchase', quantity, NULL)) OVER (
      PARTITION BY order_key, item_offset
    ) AS governed_purchase_quantity,
    MAX(IF(event_name = 'purchase', item_revenue_in_usd, NULL)) OVER (
      PARTITION BY order_key, item_offset
    ) AS governed_item_revenue_usd,
    ROW_NUMBER() OVER (
      PARTITION BY order_key, item_offset, event_name
      ORDER BY event_ts, user_pseudo_id, session_key
    ) AS event_row_number
  FROM item_events
), governed_item_events AS (
  SELECT
    * REPLACE (
      IF(event_name = 'purchase', governed_purchase_quantity, quantity) AS quantity,
      IF(event_name = 'purchase', governed_item_revenue_usd, item_revenue_in_usd) AS item_revenue_in_usd
    )
  FROM ranked_item_events
  WHERE event_name != 'purchase' OR event_row_number = 1
), product_daily AS (
  SELECT
    event_date,
    COALESCE(NULLIF(item_id, ''), '(not set)') AS item_id,
    COALESCE(NULLIF(item_name, ''), '(not set)') AS item_name,
    COALESCE(NULLIF(item_brand, ''), '(not set)') AS item_brand,
    COALESCE(NULLIF(item_category, ''), '(not set)') AS item_category,
    COALESCE(NULLIF(item_category2, ''), '(not set)') AS item_category2,
    COUNTIF(event_name = 'view_item') AS product_view_events,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events,
    COUNTIF(event_name = 'purchase') AS purchase_item_events,
    COUNT(DISTINCT IF(event_name = 'view_item', session_key, NULL)) AS product_view_sessions,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', session_key, NULL)) AS add_to_cart_sessions,
    COUNT(DISTINCT IF(event_name = 'purchase', session_key, NULL)) AS purchase_sessions,
    COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL)) AS product_view_users,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS add_to_cart_users,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchasing_users,
    SUM(IF(event_name = 'purchase', quantity, 0)) AS units_purchased,
    SUM(IF(event_name = 'purchase', COALESCE(item_revenue_in_usd, 0), 0)) AS item_revenue_usd
  FROM governed_item_events
  GROUP BY event_date, item_id, item_name, item_brand, item_category, item_category2
)
SELECT
  *,
  SAFE_DIVIDE(add_to_cart_sessions, product_view_sessions) AS view_to_cart_rate,
  SAFE_DIVIDE(purchase_sessions, product_view_sessions) AS view_to_purchase_rate,
  SAFE_DIVIDE(purchase_sessions, add_to_cart_sessions) AS cart_to_purchase_rate,
  SAFE_DIVIDE(item_revenue_usd, purchase_sessions) AS revenue_per_purchasing_session_usd
FROM product_daily;
