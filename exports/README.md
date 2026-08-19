# Verified Portfolio Extracts

These small CSVs are checked-in snapshots captured from verified BigQuery query results on 2026-08-18 and reconcile to `docs/verified_results.md`. `manifest.json` records their row counts, SHA-256 hashes, and source SQL lineage. For refreshable filters and exact multi-day distinct users, connect Tableau directly to `e-commerce-marketing-bi.marketing_analytics`.

Do not physically join files with different grains. Relate or use separate Tableau data sources.

`portfolio_weekly_trend.csv` starts on 2020-11-02 so every displayed week is Monday–Sunday. It intentionally omits the one-day opening partial week (2020-11-01; $718 recorded revenue). Headline totals retain the full source window.

Regenerate integrity metadata after a verified extract update:

```bash
python3 scripts/build_extract_manifest.py
python3 scripts/build_extract_manifest.py --check
```
