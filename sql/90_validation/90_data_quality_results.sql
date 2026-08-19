-- BigQuery GoogleSQL
-- A durable test result table. ERROR failures block publication; WARN failures require interpretation.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.dq_results` AS
WITH checks AS (
  SELECT
    'source_to_stage_event_count' AS check_name,
    'ERROR' AS severity,
    ABS(
      (SELECT COUNT(*) FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
       WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131')
      - (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`)
    ) AS failure_count,
    'Staging must retain every source event in the selected date range.' AS expectation

  UNION ALL
  SELECT
    'session_primary_key_unique',
    'ERROR',
    COUNT(*) - COUNT(DISTINCT session_key),
    'fct_sessions must contain one row per session_key.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`

  UNION ALL
  SELECT
    'order_primary_key_unique',
    'ERROR',
    COUNT(*) - COUNT(DISTINCT order_key),
    'fct_orders must contain one row per governed order_key.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`

  UNION ALL
  SELECT
    'session_dates_in_expected_range',
    'ERROR',
    COUNTIF(session_date NOT BETWEEN DATE '2020-11-01' AND DATE '2021-01-31'),
    'All session dates must fall inside the documented source window.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`

  UNION ALL
  SELECT
    'nonnegative_order_revenue',
    'ERROR',
    COUNTIF(order_revenue_usd < 0),
    'Purchase revenue must not be negative; refunds are separate events.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`

  UNION ALL
  SELECT
    'orders_reconcile_to_governed_order_keys',
    'ERROR',
    ABS(
      (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`)
      - (SELECT COUNT(DISTINCT CASE
           WHEN transaction_id IS NOT NULL THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
           ELSE CONCAT(session_key, '|purchase-session-fallback')
         END)
         FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`
         WHERE event_name = 'purchase' AND session_key IS NOT NULL)
    ),
    'Order count must equal distinct governed customer-transaction or purchase-session fallback keys.'

  UNION ALL
  SELECT
    'daily_mart_sessions_reconcile',
    'ERROR',
    ABS(
      (SELECT SUM(sessions) FROM `YOUR_PROJECT_ID.marketing_analytics.mart_daily_performance`)
      - (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`)
    ),
    'Daily mart session rows must reconcile to fct_sessions.'

  UNION ALL
  SELECT
    'daily_mart_revenue_reconciles_to_orders',
    'ERROR',
    IF(ABS(
      (SELECT SUM(revenue_usd) FROM `YOUR_PROJECT_ID.marketing_analytics.mart_daily_performance`)
      - (SELECT SUM(COALESCE(order_revenue_usd, 0)) FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`)
    ) > 0.01, 1, 0),
    'Daily mart purchase revenue must reconcile to governed orders within one cent.'

  UNION ALL
  SELECT
    'daily_mart_transactions_reconcile_to_orders',
    'ERROR',
    ABS(
      (SELECT SUM(transactions) FROM `YOUR_PROJECT_ID.marketing_analytics.mart_daily_performance`)
      - (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`)
    ),
    'Daily mart governed-order counts must reconcile to fct_orders.'

  UNION ALL
  SELECT
    'cohort_retention_not_above_one',
    'ERROR',
    COUNTIF(observed_purchaser_retention_rate > 1),
    'Cohort active purchasers cannot exceed the cohort size.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.mart_purchase_cohorts`

  UNION ALL
  SELECT
    'events_missing_session_id',
    'WARN',
    COUNTIF(session_key IS NULL),
    'Events without a GA session ID are retained in staging but excluded from session marts.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`

  UNION ALL
  SELECT
    'purchase_events_missing_transaction_id',
    'WARN',
    COUNTIF(event_name = 'purchase' AND transaction_id IS NULL),
    'Purchase events without a usable transaction ID use a disclosed purchase-session fallback.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`

  UNION ALL
  SELECT
    'duplicate_purchase_event_rows',
    'WARN',
    COUNTIF(event_name = 'purchase' AND session_key IS NOT NULL)
      - COUNT(DISTINCT IF(
          event_name = 'purchase' AND session_key IS NOT NULL,
          CASE
            WHEN transaction_id IS NOT NULL THEN CONCAT(user_pseudo_id, '|tx|', transaction_id)
            ELSE CONCAT(session_key, '|purchase-session-fallback')
          END,
          NULL
        )),
    'Repeated governed order keys are deterministically deduplicated in fct_orders.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`

  UNION ALL
  SELECT
    'governed_orders_zero_revenue',
    'WARN',
    COUNTIF(COALESCE(order_revenue_usd, 0) = 0),
    'Zero-revenue orders remain valid for conversion counts but can understate revenue, especially late in the sample.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`

  UNION ALL
  SELECT
    'aggregate_funnel_ordering',
    'WARN',
    IF(
      SUM(has_add_to_cart) > SUM(has_product_view)
      OR SUM(has_begin_checkout) > SUM(has_add_to_cart)
      OR SUM(has_purchase) > SUM(has_begin_checkout),
      1,
      0
    ),
    'Aggregate funnel stages should usually decline; failures can indicate cross-session behavior or tracking gaps.'
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
)
SELECT
  CURRENT_TIMESTAMP() AS tested_at,
  check_name,
  severity,
  failure_count,
  IF(failure_count = 0, 'PASS', IF(severity = 'WARN', 'WARN', 'FAIL')) AS status,
  expectation
FROM checks;
