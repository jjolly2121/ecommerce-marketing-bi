-- BigQuery GoogleSQL
-- Read-only decision queries. Save output values and filter context in docs/verified_results.md.

-- 1) Governed portfolio scorecard
SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_executive_scorecard`;

-- 2) Ordered same-session funnel. Each stage must occur after the prior stage.
WITH views AS (
  SELECT
    session_key,
    MIN(event_ts) AS view_ts
  FROM `YOUR_PROJECT_ID.marketing_analytics.stg_events`
  WHERE session_key IS NOT NULL
    AND event_name = 'view_item'
  GROUP BY session_key
), carts AS (
  SELECT
    v.session_key,
    v.view_ts,
    MIN(e.event_ts) AS cart_ts
  FROM views AS v
  LEFT JOIN `YOUR_PROJECT_ID.marketing_analytics.stg_events` AS e
    ON e.session_key = v.session_key
   AND e.event_name = 'add_to_cart'
   AND e.event_ts >= v.view_ts
  GROUP BY v.session_key, v.view_ts
), checkouts AS (
  SELECT
    c.session_key,
    c.view_ts,
    c.cart_ts,
    MIN(e.event_ts) AS checkout_ts
  FROM carts AS c
  LEFT JOIN `YOUR_PROJECT_ID.marketing_analytics.stg_events` AS e
    ON e.session_key = c.session_key
   AND e.event_name = 'begin_checkout'
   AND e.event_ts >= c.cart_ts
  GROUP BY c.session_key, c.view_ts, c.cart_ts
), purchases AS (
  SELECT
    c.session_key,
    c.view_ts,
    c.cart_ts,
    c.checkout_ts,
    MIN(e.event_ts) AS purchase_ts
  FROM checkouts AS c
  LEFT JOIN `YOUR_PROJECT_ID.marketing_analytics.stg_events` AS e
    ON e.session_key = c.session_key
   AND e.event_name = 'purchase'
   AND e.event_ts >= c.checkout_ts
  GROUP BY c.session_key, c.view_ts, c.cart_ts, c.checkout_ts
), funnel AS (
  SELECT 1 AS stage_order, 'Product View' AS stage, COUNT(*) AS sessions
  FROM purchases
  UNION ALL
  SELECT 2, 'Add to Cart', COUNTIF(cart_ts IS NOT NULL)
  FROM purchases
  UNION ALL
  SELECT 3, 'Begin Checkout', COUNTIF(checkout_ts IS NOT NULL)
  FROM purchases
  UNION ALL
  SELECT 4, 'Purchase', COUNTIF(purchase_ts IS NOT NULL)
  FROM purchases
), compared AS (
  SELECT
    *,
    LAG(sessions) OVER (ORDER BY stage_order) AS previous_stage_sessions
  FROM funnel
)
SELECT
  stage_order,
  stage,
  sessions,
  previous_stage_sessions - sessions AS step_dropoff_sessions,
  SAFE_DIVIDE(sessions, previous_stage_sessions) AS step_conversion_rate,
  SAFE_DIVIDE(previous_stage_sessions - sessions, previous_stage_sessions) AS step_dropoff_rate
FROM compared
ORDER BY stage_order;

-- 3) Acquisition channel performance. First-user acquisition scope, not session last-click.
SELECT
  acquisition_channel,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_pseudo_id) AS users,
  SUM(has_purchase) AS purchase_sessions,
  SUM(transaction_count) AS transactions,
  SUM(session_revenue_usd) AS revenue_usd,
  SAFE_DIVIDE(SUM(has_purchase), COUNT(*)) AS session_conversion_rate,
  SAFE_DIVIDE(SUM(session_revenue_usd), SUM(transaction_count)) AS average_order_value_usd,
  SAFE_DIVIDE(SUM(session_revenue_usd), COUNT(*)) AS revenue_per_session_usd
FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
GROUP BY acquisition_channel
ORDER BY revenue_usd DESC;

-- 4) Device performance with enough volume context for interpretation
SELECT
  device_category,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_pseudo_id) AS users,
  SUM(has_product_view) AS product_view_sessions,
  SUM(has_add_to_cart) AS add_to_cart_sessions,
  SUM(has_purchase) AS purchase_sessions,
  SUM(session_revenue_usd) AS revenue_usd,
  SAFE_DIVIDE(SUM(has_add_to_cart), SUM(has_product_view)) AS add_to_cart_rate,
  SAFE_DIVIDE(SUM(has_purchase), COUNT(*)) AS session_conversion_rate,
  SAFE_DIVIDE(SUM(session_revenue_usd), COUNT(*)) AS revenue_per_session_usd
FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
GROUP BY device_category
ORDER BY sessions DESC;

-- 5) Governed purchase-item revenue ranking.
-- Item-level view-to-purchase is not promoted because obfuscation weakens identifier continuity.
WITH product_rollup AS (
  SELECT
    REGEXP_REPLACE(TRIM(item_name), r'\s+', ' ') AS item_name,
    ARRAY_AGG(
      REGEXP_REPLACE(TRIM(item_category), r'\s+', ' ')
      IGNORE NULLS ORDER BY event_date DESC LIMIT 1
    )[SAFE_OFFSET(0)] AS item_category,
    SUM(purchase_sessions) AS purchase_sessions,
    SUM(units_purchased) AS units_purchased,
    SUM(item_revenue_usd) AS item_revenue_usd
  FROM `YOUR_PROJECT_ID.marketing_analytics.mart_product_performance`
  WHERE item_name IS NOT NULL AND TRIM(item_name) != ''
  GROUP BY 1
)
SELECT
  *
FROM product_rollup
WHERE item_revenue_usd > 0
ORDER BY item_revenue_usd DESC
LIMIT 25;

-- 6) Observed repeat-purchase behavior
SELECT
  customer_segment,
  COUNT(*) AS purchasers,
  SUM(transaction_count) AS transactions,
  SUM(observed_revenue_usd) AS observed_revenue_usd,
  AVG(average_order_value_usd) AS unweighted_customer_average_order_value_usd,
  APPROX_QUANTILES(days_to_second_observed_purchase, 100)[SAFE_OFFSET(50)]
    AS median_days_to_second_observed_purchase
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_customer_summary`
GROUP BY customer_segment
ORDER BY observed_revenue_usd DESC;

-- 7) Weekly trend with revenue-completeness context.
WITH revenue_quality AS (
  SELECT
    DATE_TRUNC(order_date, WEEK(MONDAY)) AS week_start,
    COUNT(*) AS governed_orders,
    COUNTIF(COALESCE(order_revenue_usd, 0) = 0) AS zero_revenue_orders
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_orders`
  GROUP BY week_start
)
SELECT
  w.week_start,
  w.sessions,
  w.revenue_usd,
  w.session_conversion_rate,
  w.revenue_week_over_week_change,
  w.conversion_week_over_week_point_change,
  q.governed_orders,
  q.zero_revenue_orders,
  SAFE_DIVIDE(q.zero_revenue_orders, q.governed_orders) AS zero_revenue_order_rate
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_weekly_executive` AS w
LEFT JOIN revenue_quality AS q
  USING (week_start)
WHERE w.previous_week_revenue_usd IS NOT NULL
ORDER BY w.week_start;
