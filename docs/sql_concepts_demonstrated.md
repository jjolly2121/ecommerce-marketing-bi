# SQL Concepts Demonstrated

| Concept | Where it appears | Why it matters |
|---|---|---|
| Nested/repeated data | `UNNEST(event_params)`, `UNNEST(items)` | Converts GA4 export records into relational grains |
| Common table expressions | Core facts, marts, validations | Makes multi-stage business logic reviewable |
| Joins | Orders to sessions, cohorts to customer/order facts | Adds governed dimensions without mixing grains |
| Conditional aggregation | `COUNTIF`, `MAX(IF(...))`, `SUM(IF(...))` | Builds session funnel flags and segment metrics |
| Window functions | `ROW_NUMBER`, `LAG`, moving `AVG` | Deduplicates orders, sequences purchases, compares periods |
| Date/time analysis | `TIMESTAMP_MICROS`, `DATE_TRUNC`, `DATE_DIFF` | Supports sessions, weekly trends, cohorts, repeat timing |
| Safe rate math | `SAFE_DIVIDE` | Prevents divide-by-zero failures and fake 0% values |
| Regex/CASE classification | Acquisition channel grouping | Translates raw source/medium values into business categories |
| Physical-design tradeoff | `docs/limitations.md` | Documents why Sandbox tables remain unpartitioned and how production design would differ |
| Reusable tables | `CREATE OR REPLACE TABLE` | Produces governed dashboard-ready reporting assets |
| Validation queries | Reconciliations and `ASSERT` | Prevents publishing materially inconsistent metrics |
| Deterministic deduplication | `ROW_NUMBER()` plus governed order keys | Avoids double-counted orders and revenue |
| Customer segmentation | Order-frequency CASE logic | Creates explainable one-time/repeat/loyal groups |
| Cohort analysis | First observed purchase month | Measures repeat activity while naming censoring limits |
| Statistical estimation | Two-proportion standard errors and 95% intervals | Quantifies effect size and uncertainty while preserving non-causal interpretation |
