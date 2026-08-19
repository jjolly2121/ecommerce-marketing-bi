-- BigQuery GoogleSQL
-- Grain: one pseudonymous user + GA session ID.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.fct_sessions` AS
WITH session_rollup AS (
  SELECT
    session_key,
    user_pseudo_id,
    MIN(event_date) AS session_date,
    MIN(event_ts) AS session_start_ts,
    MAX(event_ts) AS session_end_ts,
    MAX(ga_session_number) AS session_number,
    ARRAY_AGG(
      STRUCT(
        acquisition_source,
        acquisition_medium,
        acquisition_campaign,
        device_category,
        operating_system,
        browser,
        country,
        region
      )
      ORDER BY event_ts
      LIMIT 1
    )[OFFSET(0)] AS first_event,
    COUNT(*) AS event_count,
    SUM(COALESCE(engagement_time_msec, 0)) / 1000.0 AS engagement_time_seconds,
    MAX(IF(session_engaged = 1, 1, 0)) AS is_engaged_session,
    MAX(IF(event_name = 'session_start', 1, 0)) AS has_session_start,
    MAX(IF(event_name = 'view_item', 1, 0)) AS has_product_view,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS has_add_to_cart,
    MAX(IF(event_name = 'view_cart', 1, 0)) AS has_view_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS has_begin_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS has_add_shipping_info,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS has_add_payment_info,
    MAX(IF(event_name = 'purchase', 1, 0)) AS has_purchase,
    COUNTIF(event_name = 'page_view') AS page_view_count,
    COUNTIF(event_name = 'view_item') AS product_view_event_count,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_event_count
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`
  WHERE session_key IS NOT NULL
  GROUP BY session_key, user_pseudo_id
), purchase_events AS (
  SELECT
    session_key,
    user_pseudo_id,
    transaction_id,
    purchase_revenue_usd,
    event_ts,
    CASE
      WHEN transaction_id IS NOT NULL
        THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
      ELSE CONCAT(session_key, '|purchase-session-fallback')
    END AS order_key
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`
  WHERE event_name = 'purchase'
    AND session_key IS NOT NULL
), ranked_purchase_events AS (
  SELECT
    *,
    MAX(purchase_revenue_usd) OVER (PARTITION BY order_key) AS governed_order_revenue_usd,
    ROW_NUMBER() OVER (
      PARTITION BY order_key
      ORDER BY event_ts, user_pseudo_id, session_key
    ) AS order_row_number
  FROM purchase_events
), deduplicated_orders AS (
  SELECT
    session_key,
    order_key,
    governed_order_revenue_usd AS purchase_revenue_usd
  FROM ranked_purchase_events
  WHERE order_row_number = 1
), orders_by_session AS (
  SELECT
    session_key,
    COUNT(*) AS transaction_count,
    SUM(COALESCE(purchase_revenue_usd, 0)) AS session_revenue_usd
  FROM deduplicated_orders
  GROUP BY session_key
), labeled AS (
  SELECT
    s.* EXCEPT(first_event),
    COALESCE(o.transaction_count, 0) AS transaction_count,
    COALESCE(o.session_revenue_usd, 0) AS session_revenue_usd,
    CASE
      WHEN session_number = 1 THEN 'New Session'
      WHEN session_number > 1 THEN 'Returning Session'
      ELSE 'Unknown Session'
    END AS user_type,
    COALESCE(NULLIF(first_event.acquisition_source, ''), '(not set)') AS acquisition_source,
    COALESCE(NULLIF(first_event.acquisition_medium, ''), '(not set)') AS acquisition_medium,
    COALESCE(NULLIF(first_event.acquisition_campaign, ''), '(not set)') AS acquisition_campaign,
    COALESCE(NULLIF(first_event.device_category, ''), '(not set)') AS device_category,
    COALESCE(NULLIF(first_event.operating_system, ''), '(not set)') AS operating_system,
    COALESCE(NULLIF(first_event.browser, ''), '(not set)') AS browser,
    COALESCE(NULLIF(first_event.country, ''), '(not set)') AS country,
    COALESCE(NULLIF(first_event.region, ''), '(not set)') AS region
  FROM session_rollup AS s
  LEFT JOIN orders_by_session AS o
    USING (session_key)
)
SELECT
  *,
  CASE
    WHEN LOWER(acquisition_source) = '(direct)'
      OR LOWER(acquisition_medium) = '(none)' THEN 'Direct'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'email|e-mail|e_mail') THEN 'Email'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'cpc|ppc|paidsearch|paid_search') THEN 'Paid Search'
    WHEN LOWER(acquisition_medium) = 'organic' THEN 'Organic Search'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'paid_social|paidsocial|social_paid') THEN 'Paid Social'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'social|social-network|social-media|sm') THEN 'Organic Social'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'display|cpm|banner') THEN 'Display'
    WHEN LOWER(acquisition_medium) = 'referral' THEN 'Referral'
    WHEN REGEXP_CONTAINS(LOWER(acquisition_medium), r'affiliate') THEN 'Affiliates'
    ELSE 'Other'
  END AS acquisition_channel
FROM labeled;
