-- BigQuery GoogleSQL
-- Grain: one source GA4 event.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.stg_events` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_ts,
  event_name,
  event_previous_timestamp,
  event_bundle_sequence_id,
  user_pseudo_id,
  (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id')
    AS ga_session_id,
  CASE
    WHEN user_pseudo_id IS NOT NULL
      AND (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
    THEN CONCAT(
      user_pseudo_id,
      '.',
      CAST((SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    )
  END AS session_key,
  (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_number')
    AS ga_session_number,
  COALESCE(
    (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'session_engaged'),
    SAFE_CAST((SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'session_engaged') AS INT64)
  ) AS session_engaged,
  (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')
    AS engagement_time_msec,
  (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'page_location')
    AS page_location,
  (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'page_referrer')
    AS page_referrer,
  platform,
  device.category AS device_category,
  device.operating_system AS operating_system,
  device.web_info.browser AS browser,
  geo.country AS country,
  geo.region AS region,
  traffic_source.source AS acquisition_source,
  traffic_source.medium AS acquisition_medium,
  traffic_source.name AS acquisition_campaign,
  NULLIF(NULLIF(ecommerce.transaction_id, ''), '(not set)') AS transaction_id,
  ecommerce.purchase_revenue_in_usd AS purchase_revenue_usd,
  ecommerce.refund_value_in_usd AS refund_value_usd,
  ecommerce.total_item_quantity AS total_item_quantity,
  ecommerce.unique_items AS unique_items,
  ARRAY_LENGTH(items) AS items_in_event
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';
