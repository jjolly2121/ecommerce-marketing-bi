-- BigQuery GoogleSQL
-- Grain: one item nested within one GA4 event.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.stg_item_events` AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_ts,
  event_name,
  user_pseudo_id,
  CASE
    WHEN user_pseudo_id IS NOT NULL
      AND (SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
    THEN CONCAT(
      user_pseudo_id,
      '.',
      CAST((SELECT ANY_VALUE(value.int_value) FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    )
  END AS session_key,
  NULLIF(NULLIF(ecommerce.transaction_id, ''), '(not set)') AS transaction_id,
  item_offset,
  item.item_id,
  item.item_name,
  item.item_brand,
  item.item_variant,
  item.item_category,
  item.item_category2,
  item.item_category3,
  item.item_category4,
  item.item_category5,
  item.price_in_usd,
  item.price,
  COALESCE(item.quantity, 1) AS quantity,
  item.item_revenue_in_usd,
  item.item_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(items) AS item WITH OFFSET AS item_offset
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';
