# BigQuery Performance and Physical-Design Notes

## Verified processing evidence

BigQuery job metadata for the final unpartitioned `stg_events` build reported 3,029,771,696 bytes processed (about 3.03 GB decimal / 2.82 GiB) and 167,927 slot milliseconds. The repository runner caps an individual query at 25 GB billed bytes.

Curated table storage measured on 2026-08-18:

| Table | Rows | Stored size |
|---|---:|---:|
| `stg_events` | 4,295,584 | 1,183.96 MiB |
| `stg_item_events` | 3,982,732 | 884.59 MiB |
| `fct_sessions` | 360,129 | 108.41 MiB |
| `mart_product_performance` | 159,582 | 29.42 MiB |
| `mart_daily_performance` | 78,365 | 18.70 MiB |
| `fct_orders` | 5,279 | 1.39 MiB |

Smaller customer, cohort, weekly, scorecard, statistical, and quality tables each use less than 0.5 MiB.

## Production design proposal

The verified Sandbox build remains unpartitioned because partitioned CTAS probes produced empty destination tables during validation. A production-capable test should benchmark:

| Table | Proposed partition | Proposed clustering |
|---|---|---|
| `stg_events` | `event_date` | `event_name`, `user_pseudo_id` |
| `stg_item_events` | `event_date` | `event_name`, `item_id` |
| `fct_sessions` | `session_date` | `acquisition_channel`, `device_category`, `user_pseudo_id` |
| `fct_orders` | `order_date` | `acquisition_channel`, `user_pseudo_id` |
| Daily/product marts | reporting date | highest-use dashboard filter dimensions |

Validation should compare bytes processed, latency, row counts, and reconciliation results before adopting the design.
