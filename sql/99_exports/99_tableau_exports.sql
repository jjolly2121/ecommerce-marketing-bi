-- BigQuery GoogleSQL
-- Tableau can connect directly to these flat tables. The SELECT statements also provide
-- a simple Cloud Console path: run one query, then choose Save results > CSV.

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_daily_performance`
ORDER BY session_date, acquisition_channel, device_category;

-- Use this session-grain table for exact COUNTD(user_pseudo_id) across date ranges.
-- It may exceed the Cloud Console's local CSV result limit; direct Tableau-to-BigQuery is preferred.
SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
ORDER BY session_date, session_start_ts;

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_weekly_executive`
ORDER BY week_start;

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_product_performance`
ORDER BY event_date, item_revenue_usd DESC;

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_customer_summary`
ORDER BY observed_revenue_usd DESC;

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_purchase_cohorts`
ORDER BY cohort_month, months_since_first_purchase;

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.mart_conversion_comparisons`
ORDER BY comparison_name;
