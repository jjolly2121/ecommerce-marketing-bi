# Tableau Executive Dashboard Specification

Implementation status: the core full-window executive view is implemented in `tableau/Ecommerce_Marketing_Executive_Dashboard.twbx` and was successfully rendered in Tableau Desktop 2026.2. The filter and drill-down sections below define the optional direct-BigQuery enhancement; they are not claims about the current static aggregate package.

## Audience and purpose

One 1,300 × 850 px dashboard for a nontechnical marketing or merchandising executive. The first screen should answer: “Are revenue and conversion healthy, where is the funnel leaking, and which segment needs action?”

## Layout

```text
┌───────────────────────────────────────────────────────────────────────────┐
│ CUSTOMER JOURNEY & MARKETING PERFORMANCE       Date | Channel | Device   │
├──────────────┬──────────────┬──────────────┬──────────────┬──────────────┤
│ Revenue      │ Transactions │ Conversion   │ AOV          │ Sessions     │
├──────────────────────────────────────┬────────────────────────────────────┤
│ Revenue & conversion trend           │ Session conversion funnel          │
│ dual-panel line chart                │ View → Cart → Checkout → Purchase  │
├──────────────────────────────────────┼────────────────────────────────────┤
│ Acquisition channel performance      │ New vs returning sessions          │
│ ranked bars + conversion label       │ traffic, revenue, conversion       │
├──────────────────────────────────────┴────────────────────────────────────┤
│ Executive takeaway: dynamic annotation / three concise recommendations  │
└───────────────────────────────────────────────────────────────────────────┘
```

## Data sources

- `mart_daily_performance`: KPI cards, trend, channel, device
- Ordered funnel query in `sql/40_analysis/40_executive_findings.sql`: timestamp-sequenced funnel
- `fct_sessions`: exact distinct-user calculations across multi-day filter ranges
- `mart_product_performance`: governed purchase-item revenue ranking on a merchandising detail sheet
- `mart_customer_summary`: repeat-purchase panel or tooltip
- `mart_purchase_cohorts`: optional cohort heatmap on a second dashboard
- `mart_executive_scorecard`: audit/reference source for full-window headline totals
- `mart_conversion_comparisons`: optional methodology tooltip/detail sheet for effect sizes and approximate intervals

Prefer a direct BigQuery connection. If using CSV extracts, preserve the four tables as separate logical sources; do not physically join different grains and duplicate revenue.

The `users` measure in `mart_daily_performance` is a daily distinct count and is **not additive across dates**. For an exact multi-day user KPI, use `COUNTD([user_pseudo_id])` from `fct_sessions`.

## Required sheets

1. **KPI cards:** Revenue, transactions, session conversion, AOV, sessions. Show current filtered value plus previous-week percentage change where meaningful.
2. **Trend:** Two aligned panels rather than a misleading dual axis—daily/weekly revenue above, session conversion below. Include a seven-day moving average.
3. **Funnel:** Horizontal bars for the ordered same-session path from product view to later add-to-cart, checkout, and purchase events. Label count, step conversion, and drop-off.
4. **Channel performance:** Revenue bars ranked descending, with a conversion-rate dot on a separate aligned axis or in labels. Show sessions in tooltip to prevent small-sample overreaction.
5. **Customer segment:** New versus returning sessions using session share, revenue share, conversion, and AOV. Avoid calling these new versus returning people.
6. **Executive takeaway:** A text tile populated from the verified findings; one sentence per action plus a visible revenue-completeness warning.

Secondary merchandising sheet: ranked bars for governed item revenue and units purchased. Do not use the obfuscated sample's item-level view-to-purchase rate as an executive KPI because product identifiers are inconsistent across event types.

Keep confidence intervals off the main executive canvas unless the audience requests them. A methodology tooltip or appendix sheet should state that repeated sessions can narrow the normal-approximation interval and that the comparisons are not causal.

## Filters

These filters require the direct BigQuery version or a unified row-grain extract. They are intentionally not included in the portable workbook because its five sources have different aggregate grains.

- Date range (global, default full period)
- Acquisition channel
- Device category
- Country
- User type (new/returning session)
- Product category (secondary merchandising sheet only; visually separated)

## Tableau calculations

Use weighted formulas from additive numerators and denominators, never `AVG()` of precomputed percentages.

```text
Session Conversion Rate = SUM([purchase_sessions]) / SUM([sessions])
Add-to-Cart Stage Ratio = SUM([add_to_cart_sessions]) / SUM([product_view_sessions])
Cart Abandonment Rate = SUM([abandoned_cart_sessions]) / SUM([add_to_cart_sessions])
Checkout Completion Rate = SUM([checkout_and_purchase_sessions]) / SUM([checkout_sessions])
AOV = SUM([revenue_usd]) / SUM([transactions])
```

## Visual design

- White/off-white background, dark navy text, one primary blue, teal for favorable movement, muted coral for drop-off.
- Currency rounded appropriately; rates use one decimal place; counts use K/M abbreviations only when needed.
- Avoid pie charts, gauges, 3D marks, decorative icons, and unexplained dual axes.
- Use verified declarative titles such as “Returning sessions generate 66.9% of revenue from 27.5% of traffic.”
- Mark the week of 2021-01-25 as revenue-incomplete: 218 of 321 governed orders have zero revenue.
- Put definitions and caveats in concise tooltips, not in the visual foreground.

## Screenshot checklist

- Full dashboard at readable resolution
- Funnel close-up with labels visible
- Channel/product view with filter state visible
- Optional cohort dashboard
- No placeholder values, clipped labels, scrollbars, or Tableau authoring chrome
