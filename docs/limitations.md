# Limitations and Responsible Interpretation

1. **Obfuscation:** Google warns that placeholder values and limited internal consistency are expected. Findings apply to the sample, not to current Google Store operations.
2. **Historical window:** The data covers only 2020-11-01 through 2021-01-31, a holiday-heavy period. It is not a current market benchmark.
3. **Pseudonymous identity:** `user_pseudo_id` represents a browser/app instance, not a deduplicated person across devices.
4. **Acquisition scope:** Channel reporting is based on first-user acquisition, not session last-click, media cost, or incremental attribution.
5. **No ad spend:** ROAS, CAC, and profit cannot be calculated because spend and margin are absent.
6. **Session funnel:** Cart abandonment and checkout completion are same-session behavioral proxies. Persistent carts and cross-session purchases can break apparent step order.
7. **Cohort censoring:** First purchase means first observed purchase. Early cohorts have more time to repeat, and purchases before/after the window are unknown.
8. **Revenue:** GA4 revenue is reported telemetry, not reconciled finance data. Refund coverage must be profiled before using net revenue.
9. **Descriptive analysis:** Associations do not prove causal effects. Recommendations should be validated through instrumentation review or controlled experiments.
10. **Sandbox physical design:** In the verified Sandbox execution, partitioned CTAS probes produced empty destinations, so the analytical tables are unpartitioned. At this sample size the marts remain practical; a production deployment should validate date partitioning and high-selectivity clustering in a billed test environment.
11. **Order identifiers:** 906 purchase events have no usable transaction ID after treating `(not set)` as missing. They use a disclosed one-order-per-purchase-session fallback. This is reasonable for the sample but should be replaced by commerce-platform order IDs in production.
12. **Zero-revenue orders:** 411 governed orders have zero recorded revenue; 218 occur in the week of 2021-01-25. That week’s revenue trend is not decision-grade even though its conversion count remains usable.
13. **Product lineage:** Item identifiers/names are not consistently stable between engagement and purchase events. Product revenue rankings are usable after purchase-item deduplication, but item-level view-to-purchase claims are not promoted to executive findings.

## Proposed next steps

- Join ad-platform spend to calculate CAC and ROAS at a governed channel grain.
- Add authenticated customer IDs with consent-safe identity rules.
- Create session-scoped attribution from the modern GA4 session traffic-source record when available.
- Validate transactions and refunds against an order-management system.
- Run controlled experiments on the largest funnel opportunity.
- Add refresh orchestration, freshness alerts, and semantic-layer tests before production deployment.
- Reintroduce and benchmark date partitioning plus channel/user clustering in a production-capable BigQuery environment.
