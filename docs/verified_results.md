# Verified Results Log

## Run record

- BigQuery project: `e-commerce-marketing-bi`
- Dataset: `marketing_analytics`
- Execution date: 2026-08-18
- Source: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- Source table suffix range: `20201101`–`20210131`
- Validation status: **PASS — 10 of 10 blocking checks passed**
- Warnings: 906 purchase events without a usable transaction ID; 413 repeated governed order events; 411 governed orders with zero recorded revenue

## Reconciled totals

| Metric | Verified value | Definition / note |
|---|---:|---|
| Source events | 4,295,584 | Exact source-to-stage reconciliation |
| Pseudonymous users | 270,154 | Browser/app identifiers, not cross-device people |
| Sessions | 360,129 | Distinct user + GA session keys |
| Product-view sessions | 77,020 | At least one `view_item` |
| Add-to-cart sessions | 15,188 | At least one `add_to_cart` |
| Checkout sessions | 11,106 | At least one `begin_checkout` |
| Purchase sessions | 4,848 | At least one `purchase` |
| Governed orders | 5,279 | Customer + valid transaction ID, or purchase-session fallback |
| Purchase revenue | $338,108 | Maximum observed revenue retained across repeated order events |
| Average order value | $64.05 | Revenue / governed orders |
| Session conversion | 1.35% | Purchase sessions / sessions |
| Cart abandonment | 81.25% | Cart sessions without a same-session purchase |
| Checkout completion | 43.63% | Checkout sessions with a same-session purchase |
| Purchasers | 4,419 | Pseudonymous users with a governed order |
| Observed repeat purchasers | 520 | At least two governed orders in the sample |
| Observed repeat-purchase rate | 11.77% | Repeat purchasers / purchasers |
| Median days to second observed purchase | 1 day | Repeat purchasers only; same-day repeat orders are possible |

## Funnel

| Stage | Sessions | Step conversion | Step drop-off |
|---|---:|---:|---:|
| Product view | 77,020 | — | — |
| Add to cart after product view | 15,167 | 19.69% | 80.31% |
| Begin checkout after cart | 5,416 | 35.71% | 64.29% |
| Purchase after checkout | 2,834 | 52.33% | 47.67% |

This is an ordered same-session funnel: each event must occur at or after the prior stage timestamp. It is intentionally narrower than the independent stage totals in the scorecard. For example, the separate 43.63% checkout-completion KPI measures purchase co-occurrence among all checkout sessions, regardless of whether the session entered through every earlier ordered stage.

## Findings and recommendations

### 1. Returning sessions are the highest-value behavioral segment

Returning sessions were 98,891 of 360,129 sessions (27.5%) but generated $226,265 of $338,108 revenue (66.9%). Their 3.10% session conversion rate was 4.553 times the 0.68% rate for new sessions. The approximate 95% interval for the absolute conversion difference was +2.308 to +2.534 percentage points.

**Recommendation:** protect lifecycle and remarketing journeys, then test whether high-intent returning visitors can be recognized earlier and routed to recently viewed items, saved carts, or replenishment prompts. This is descriptive evidence, not proof that remarketing caused the difference.

### 2. The largest actionable funnel loss is before cart, with a second checkout opportunity

Only 19.69% of product-view sessions recorded a later add-to-cart event, a loss of 61,853 sessions. Among sessions that followed the complete ordered path through checkout, 52.33% then purchased, leaving 2,582 ordered-path checkout sessions without a later purchase.

**Recommendation:** separate experiments by stage: product-page value/fit/shipping clarity before cart, then form friction, payment, and error instrumentation during checkout. Cart abandonment is a same-session proxy, so persistent-cart behavior must be validated before sizing recovery revenue.

### 3. Referral traffic outperformed paid search on observed efficiency

Referral produced a 1.66% session conversion rate and $1.24 revenue per session, compared with 0.98% and $0.54 for Paid Search. Organic Search generated the most revenue ($97,281) because it had the most sessions (122,841), not because it had the strongest conversion.

The approximate 95% interval for the Referral-minus-Paid-Search conversion difference was +0.499 to +0.866 percentage points. Session dependence and observational channel assignment mean the interval is diagnostic, not causal.

**Recommendation:** audit paid-search query/campaign and landing-page alignment, and investigate which referral partners or placements drive higher-intent visits. Do not reallocate budget from this dataset alone: spend, margin, and incrementality are unavailable, and channel is first-user acquisition rather than session last-click.

### 4. The late-January revenue decline is a measurement warning, not a business conclusion

The week of 2021-01-25 shows $5,178 revenue, down 80.6% week over week, but 218 of 321 governed orders (67.9%) have zero recorded revenue. Conversion was still 1.18%.

**Recommendation:** repair or reconcile purchase-value instrumentation before using that week for revenue decisions. Keep order-count and conversion reporting visually separated from revenue completeness status.

### 5. Repeat purchasers are small in count but material in observed value

Repeat purchasers were 11.77% of purchasers but generated $87,162, or 25.8% of observed revenue, and 1,380 of 5,279 orders (26.1%). November’s first-purchase cohort had 6.40% observed month-one retention; December’s had 2.40%.

**Recommendation:** prioritize a measured second-purchase program, while labeling cohort results as observation-window retention rather than lifetime retention.

## Data-quality results

All ten `ERROR` checks passed: source-to-stage row count, session and order key uniqueness, date range, nonnegative revenue, governed-order reconciliation, daily session reconciliation, daily transaction reconciliation, daily revenue reconciliation, and cohort retention bounds.

| Warning check | Count | Treatment |
|---|---:|---|
| Purchase events without usable transaction ID | 906 | Use one governed order per purchase session; disclose fallback |
| Repeated governed order events | 413 | Keep earliest event context and maximum recorded revenue/item counts |
| Governed orders with zero revenue | 411 | Retain for conversion/order counts; flag revenue incompleteness |
