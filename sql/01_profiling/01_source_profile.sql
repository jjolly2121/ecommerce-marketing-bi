-- BigQuery GoogleSQL
-- Read-only profiling of the official GA4 obfuscated sample.

-- 1) Coverage, volume, and identity
SELECT
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS min_event_date,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS max_event_date,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS pseudonymous_users,
  COUNT(DISTINCT CONCAT(
    user_pseudo_id,
    '.',
    CAST((SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
  )) AS sessions_with_id
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';

-- 2) Event taxonomy
SELECT
  event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY event_count DESC;

-- 3) Event-parameter inventory. This is the evidence for fields extracted in staging.
SELECT
  event_param.key AS parameter_name,
  COUNT(*) AS parameter_occurrences,
  COUNT(DISTINCT event_name) AS event_names_using_parameter
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(event_params) AS event_param
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY parameter_name
ORDER BY parameter_occurrences DESC;

-- 4) Acquisition, device, and geography completeness
SELECT
  COUNT(*) AS event_count,
  COUNTIF(user_pseudo_id IS NULL) AS events_missing_user_pseudo_id,
  COUNTIF((SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NULL)
    AS events_missing_ga_session_id,
  COUNTIF(traffic_source.source IS NULL OR traffic_source.source = '') AS events_missing_acquisition_source,
  COUNTIF(traffic_source.medium IS NULL OR traffic_source.medium = '') AS events_missing_acquisition_medium,
  COUNTIF(device.category IS NULL OR device.category = '') AS events_missing_device_category,
  COUNTIF(geo.country IS NULL OR geo.country = '') AS events_missing_country
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';

-- 5) Purchase telemetry and duplicate transaction IDs
WITH purchases AS (
  SELECT
    user_pseudo_id,
    CONCAT(
      user_pseudo_id,
      '.',
      CAST((SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ) AS session_key,
    NULLIF(NULLIF(ecommerce.transaction_id, ''), '(not set)') AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS purchase_revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  COUNT(*) AS purchase_event_count,
  COUNTIF(transaction_id IS NULL) AS purchases_without_usable_transaction_id,
  COUNT(DISTINCT IF(transaction_id IS NOT NULL, CONCAT(user_pseudo_id, '|tx|', transaction_id), NULL))
    AS distinct_customer_transaction_ids,
  COUNT(DISTINCT CASE
    WHEN transaction_id IS NOT NULL THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
    ELSE CONCAT(session_key, '|purchase-session-fallback')
  END) AS governed_order_keys,
  SUM(COALESCE(purchase_revenue_usd, 0)) AS purchase_event_revenue_usd,
  COUNTIF(purchase_revenue_usd IS NULL) AS purchases_missing_revenue,
  COUNTIF(purchase_revenue_usd < 0) AS purchases_with_negative_revenue,
  COUNT(*) - COUNT(DISTINCT CASE
    WHEN transaction_id IS NOT NULL THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
    ELSE CONCAT(session_key, '|purchase-session-fallback')
  END) AS duplicate_purchase_event_rows
FROM purchases;

-- 6) Funnel event coverage by day, useful for spotting instrumentation outages.
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  COUNTIF(event_name = 'view_item') AS view_item_events,
  COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events,
  COUNTIF(event_name = 'begin_checkout') AS begin_checkout_events,
  COUNTIF(event_name = 'purchase') AS purchase_events
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_date
ORDER BY event_date;
