# Case Study: E-Commerce Customer Journey and Marketing Performance

## Challenge

Marketing and merchandising leaders needed one reliable view of traffic, product engagement, cart and checkout progression, purchase, and repeat behavior. The analytical challenge was to transform nested GA4 clickstream events into metrics that could support decisions without overstating attribution or customer identity.

## Data and tools

The analysis uses Google's official obfuscated GA4 e-commerce public dataset in BigQuery: 4,295,584 events from 2020-11-01 through 2021-01-31. BigQuery GoogleSQL handles profiling, nested-field extraction, sessionization, order governance, period comparisons, cohorts, statistical comparisons, and validation. Tableau Desktop 2026.2 presents the governed outputs in a packaged executive dashboard.

## Approach

Repeated `event_params` and `items` arrays are converted into event- and item-level staging tables, followed by one-row-per-session and one-row-per-order facts. Session flags prevent repeated events from inflating headline counts. The ordered funnel uses event timestamps so each cart, checkout, and purchase event occurs after the preceding stage in the same session.

Validation identified 883 purchase events with `(not set)` transaction IDs and 23 with missing IDs. Valid transaction IDs are scoped to the pseudonymous customer; unusable IDs fall back to one governed order per purchase session. Repeated purchase events are deterministically deduplicated, retaining the earliest event context and maximum recorded revenue. Ten blocking checks reconcile source rows, keys, dates, sessions, orders, transactions, revenue, and cohort bounds.

## Results

The model contains 360,129 sessions, 270,154 pseudonymous users, 5,279 governed orders, and $338,108 in recorded revenue. Session conversion was 1.35%, and average order value was $64.05.

Returning sessions represented 27.5% of traffic but 66.9% of revenue and converted 4.553 times as often as new sessions. The approximate 95% interval for the absolute conversion difference was +2.308 to +2.534 percentage points. Referral recorded 1.66% conversion and $1.24 revenue per session versus Paid Search at 0.98% and $0.54; spend and incrementality are unavailable.

The ordered same-session funnel showed the largest loss between product view and cart: 19.69% progressed. Of those sessions, 35.71% subsequently reached checkout and 52.33% then purchased. The final week also contained a material measurement issue: 218 of 321 governed orders had zero recorded revenue, so the apparent revenue decline is not decision-grade.

## Recommendations

1. Validate and test product-view-to-cart friction before estimating revenue upside.
2. Run a measured second-purchase lifecycle test; returning sessions concentrate observed value but the relationship is not causal.
3. Repair late-January purchase-value tracking before using the final week for revenue or channel decisions.

## Deliverables

- Reproducible BigQuery SQL pipeline and documented analytical marts
- Data dictionary, KPI definitions, logical model, limitations, and validation results
- Ordered customer-journey funnel and two diagnostic conversion comparisons
- Packaged Tableau executive dashboard and governed CSV snapshots
