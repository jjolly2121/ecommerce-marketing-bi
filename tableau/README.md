# Tableau Build Folder

The native executive dashboard was successfully loaded and rendered in Tableau Desktop 2026.2 on 2026-08-18. Its headline values reconcile to the verified BigQuery exports.

## Files

- `Ecommerce_Marketing_Executive_Dashboard.twbx`: primary portable workbook; open this file in Tableau
- `Ecommerce_Marketing_Executive_Dashboard.twb`: unpackaged XML workbook source
- `Data/`: the five governed CSV sources packaged in the workbook
- `executive_dashboard.png`: presentation image of the executive dashboard
- `../scripts/build_tableau_workbook.py`: reproducibly regenerates the `.twb` and `.twbx`

## Implemented workbook

The 1,300 × 850 dashboard contains ten native worksheets: four KPI cards, two weekly trend views, a four-step conversion funnel, acquisition-channel performance, new-versus-returning session performance, and an executive recommendation tile. The package is self-contained and does not require BigQuery credentials to open.

The portable version uses separate aggregate snapshots and therefore does not provide global cross-source filters. For a refreshable, filterable version, connect Tableau directly to `mart_daily_performance` and the documented detail marts using `docs/dashboard_spec.md`.
