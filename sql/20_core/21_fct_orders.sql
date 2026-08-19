-- BigQuery GoogleSQL
-- Grain: one governed order key. Valid transaction IDs are scoped to the pseudonymous user;
-- missing IDs fall back to one order per purchase session.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.fct_orders` AS
WITH purchase_events AS (
  SELECT
    CASE
      WHEN transaction_id IS NOT NULL
        THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
      ELSE CONCAT(session_key, '|purchase-session-fallback')
    END AS order_key,
    IF(transaction_id IS NULL, 'purchase_session_fallback', 'customer_transaction_id') AS order_key_source,
    transaction_id,
    event_ts AS order_ts,
    event_date AS order_date,
    user_pseudo_id,
    session_key,
    purchase_revenue_usd AS order_revenue_usd,
    total_item_quantity AS item_quantity,
    unique_items
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`
  WHERE event_name = 'purchase'
    AND session_key IS NOT NULL
), ranked_purchase_events AS (
  SELECT
    *,
    MAX(order_revenue_usd) OVER (PARTITION BY order_key) AS governed_order_revenue_usd,
    MAX(item_quantity) OVER (PARTITION BY order_key) AS governed_item_quantity,
    MAX(unique_items) OVER (PARTITION BY order_key) AS governed_unique_items,
    ROW_NUMBER() OVER (
      PARTITION BY order_key
      ORDER BY order_ts, user_pseudo_id, session_key
    ) AS transaction_row_number
  FROM purchase_events
), deduplicated AS (
  SELECT
    * EXCEPT(
      transaction_row_number,
      order_revenue_usd,
      item_quantity,
      unique_items,
      governed_order_revenue_usd,
      governed_item_quantity,
      governed_unique_items
    ),
    governed_order_revenue_usd AS order_revenue_usd,
    governed_item_quantity AS item_quantity,
    governed_unique_items AS unique_items
  FROM ranked_purchase_events
  WHERE transaction_row_number = 1
), sequenced AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id
      ORDER BY order_ts, order_key
    ) AS order_number_observed,
    LAG(order_date) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY order_ts, order_key
    ) AS previous_order_date
  FROM deduplicated
)
SELECT
  o.*,
  DATE_DIFF(o.order_date, o.previous_order_date, DAY) AS days_since_previous_order,
  s.acquisition_channel,
  s.acquisition_source,
  s.acquisition_medium,
  s.acquisition_campaign,
  s.device_category,
  s.operating_system,
  s.browser,
  s.country,
  s.region,
  s.user_type
FROM sequenced AS o
LEFT JOIN `YOUR_PROJECT_ID.marketing_analytics.fct_sessions` AS s
  USING (session_key);
