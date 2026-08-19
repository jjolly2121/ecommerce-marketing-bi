# Data Dictionary

This dictionary documents the curated analytical layer. Refer to Google’s [GA4 BigQuery export schema](https://support.google.com/analytics/answer/7029846) for every raw nested field.

## `stg_events`

| Column | Type | Description |
|---|---|---|
| `event_date` | DATE | GA4 event date parsed from table export field |
| `event_ts` | TIMESTAMP | Event timestamp converted from microseconds |
| `event_name` | STRING | GA4 event name |
| `user_pseudo_id` | STRING | Pseudonymous browser/app identifier |
| `ga_session_id` | INT64 | GA session parameter extracted from `event_params` |
| `session_key` | STRING | User-scoped session key |
| `ga_session_number` | INT64 | Browser-scoped session sequence |
| `session_engaged` | INT64 | GA event parameter, standardized to 0/1 when present |
| `engagement_time_msec` | INT64 | Engagement time attached to event |
| `page_location` | STRING | Page URL attached to event |
| `page_referrer` | STRING | Referrer URL attached to event |
| `platform` | STRING | Web/app platform |
| `device_category` | STRING | Desktop, mobile, or tablet category |
| `operating_system` | STRING | Device operating system |
| `browser` | STRING | Web browser |
| `country` | STRING | Event country |
| `region` | STRING | Event region |
| `acquisition_source` | STRING | First-user source |
| `acquisition_medium` | STRING | First-user medium |
| `acquisition_campaign` | STRING | First-user campaign name |
| `transaction_id` | STRING | Usable GA4 e-commerce transaction ID; blank and `(not set)` values become NULL |
| `purchase_revenue_usd` | FLOAT64 | Event purchase revenue in USD |
| `refund_value_usd` | FLOAT64 | Event refund value in USD |
| `items_in_event` | INT64 | Number of nested item rows |

## `fct_sessions`

| Column | Description |
|---|---|
| `session_key` | Unique row key |
| `user_pseudo_id` | Pseudonymous user |
| `session_date`, `session_start_ts`, `session_end_ts` | Session timing |
| `session_number` | Highest observed GA session number in session |
| `user_type` | New, Returning, or Unknown Session |
| `acquisition_channel` | Rule-based first-user acquisition grouping |
| `acquisition_source`, `acquisition_medium`, `acquisition_campaign` | Acquisition dimensions |
| `device_category`, `operating_system`, `browser`, `country`, `region` | Session dimensions selected from earliest event |
| `event_count` | Events in the session |
| `engagement_time_seconds` | Sum of event engagement time |
| `has_session_start` | 1 when session contains `session_start` |
| `has_product_view` | 1 when session contains `view_item` |
| `has_add_to_cart` | 1 when session contains `add_to_cart` |
| `has_view_cart` | 1 when session contains `view_cart` |
| `has_begin_checkout` | 1 when session contains `begin_checkout` |
| `has_add_shipping_info` | 1 when session contains `add_shipping_info` |
| `has_add_payment_info` | 1 when session contains `add_payment_info` |
| `has_purchase` | 1 when session contains `purchase` |
| `transaction_count` | Governed order keys in session |
| `session_revenue_usd` | Purchase revenue recorded in session |

## `fct_orders`

| Column | Description |
|---|---|
| `order_key` | Unique governed key: customer + valid transaction ID, otherwise purchase-session fallback |
| `order_key_source` | `customer_transaction_id` or `purchase_session_fallback` |
| `transaction_id` | Source transaction ID when usable; otherwise NULL |
| `order_ts`, `order_date` | Purchase timing |
| `user_pseudo_id`, `session_key` | Customer/session identifiers |
| `order_revenue_usd` | Maximum GA4 purchase revenue observed across repeated rows for the governed order key |
| `item_quantity`, `unique_items` | Purchase-event item counts |
| `order_number_observed` | Customer’s transaction sequence within the sample |
| acquisition/device/geography columns | Purchase-session context |

## Tableau marts

The mart names, grains, and relationships are documented in `docs/data_model.md`. Calculated rate columns use `SAFE_DIVIDE` and return `NULL` when a denominator is zero; Tableau should display these as unavailable, not as 0%.

`mart_daily_performance.users` is distinct only within each mart row and must not be summed to represent unique users across multiple dates or segments. Use `COUNTD(user_pseudo_id)` from `fct_sessions` when the dashboard needs an exact filtered user count.

## `mart_conversion_comparisons`

| Column | Description |
|---|---|
| `comparison_name` | Preselected comparison label |
| `population_a`, `population_b` | Compared behavioral/channel populations |
| `sessions_a`, `sessions_b` | Session denominators |
| `purchase_sessions_a`, `purchase_sessions_b` | Converted-session numerators |
| `conversion_rate_a`, `conversion_rate_b` | Session conversion rates |
| `absolute_conversion_difference` | Rate A minus rate B |
| `relative_conversion_ratio` | Rate A divided by rate B |
| `unpooled_standard_error` | Approximate independent-proportions standard error |
| `lower_95_ci_absolute_difference`, `upper_95_ci_absolute_difference` | Approximate 95% bounds for the absolute difference |
| `interpretation_scope`, `confidence_interval_caveat` | Required responsible-use context |
