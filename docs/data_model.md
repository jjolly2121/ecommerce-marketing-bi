# Logical Data Model

## Model grains

| Model | Grain | Purpose |
|---|---|---|
| `stg_events` | One GA4 event | Flatten repeated parameters and standardize event/session/acquisition/device fields |
| `stg_item_events` | One item nested inside one event | Product/category engagement and item revenue |
| `fct_sessions` | One pseudonymous user + GA session ID | Deduplicated funnel, behavior, and acquisition performance |
| `fct_orders` | One governed order key | Revenue, AOV, purchase sequence, and customer behavior |
| `mart_daily_performance` | Date × acquisition channel × source × medium × device × user type | Executive trends, channel/device comparisons, funnel rates, and period-over-period metrics |
| `mart_product_performance` | Date × item × category | Product demand and progression |
| `mart_customer_summary` | Pseudonymous user | First/second purchase, repeat behavior, revenue, and order frequency |
| `mart_purchase_cohorts` | First-purchase month × months since first purchase | Observed purchaser retention |
| `mart_executive_scorecard` | One row for the full sample | Reconciled portfolio totals and headline rates |
| `mart_conversion_comparisons` | One row per preselected comparison | Approximate conversion differences, rate ratios, and 95% confidence intervals |

## Relationships

- `stg_events.session_key` → `fct_sessions.session_key` (many-to-one)
- `stg_item_events.session_key` → `fct_sessions.session_key` (many-to-one)
- `fct_orders.user_pseudo_id` → `mart_customer_summary.user_pseudo_id` (many-to-one)
- `fct_orders.order_key` is unique after deterministic deduplication

## Important modeling decisions

1. **Session key includes user ID.** GA session IDs are timestamps and are not guaranteed globally unique, so `user_pseudo_id || '.' || ga_session_id` is the key.
2. **Funnel flags are session-level.** Multiple views, cart events, or purchase events in a session become one flag, eliminating event-count inflation.
3. **Order keys are governed.** A valid transaction ID is scoped to `user_pseudo_id` because the obfuscated sample reuses IDs across customers. Missing and `(not set)` IDs fall back to one order per purchase session. Repeated order events are deduplicated, and the maximum recorded revenue/item counts are retained when duplicates conflict.
4. **Acquisition is first-user scoped.** The sample’s stable `traffic_source` record is used and labeled honestly.
5. **Cohorts begin at first observed purchase.** The model does not claim lifetime first purchase before the sample started.
6. **Item purchases are deduplicated separately.** Repeated purchase-item rows are governed by order key plus item offset. View-to-purchase analysis is limited because the obfuscated sample does not consistently preserve item identifiers across event types.
