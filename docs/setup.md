# Setup and Execution

## Recommended path: BigQuery Sandbox / free tier

The source is already hosted by Google, so no raw-data download or ingestion is required. Google documents that a Cloud project with BigQuery enabled is required and that Sandbox/free-tier access is sufficient for sample exploration.

1. Sign in to [Google Cloud Console](https://console.cloud.google.com/bigquery).
2. Create or select a Google Cloud project.
3. Enable the BigQuery API if prompted. Billing is not required for BigQuery Sandbox; if billing is enabled, keep normal cost controls in place.
4. Confirm that this read-only query runs:

```sql
SELECT
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNT(DISTINCT event_date) AS day_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';
```

5. Execute the project SQL in numeric folder/file order. Replace `YOUR_PROJECT_ID` with the selected project ID.
6. Query `YOUR_PROJECT_ID.marketing_analytics.dq_results`. All `ERROR` checks must pass; warnings must be interpreted and disclosed.

## CLI path

Install and authenticate the Google Cloud CLI, then run:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
./scripts/run_bigquery.sh YOUR_PROJECT_ID
```

The runner:

- uses GoogleSQL, not legacy SQL;
- stops on the first error;
- sets the processing location to US;
- caps each query at 25 GB billed bytes as a safety guardrail;
- leaves export queries manual because local CSV result limits and Tableau connection choices vary.

Verification note: the SQL models were executed and validated through the authenticated BigQuery Cloud Console. The shell runner has passed syntax checks but was not executed end to end in this workspace because the `bq` CLI was unavailable. Run it against a clean dataset before claiming CLI-based orchestration.

## Tableau connection

### Open the included portable workbook

1. Open `tableau/Ecommerce_Marketing_Executive_Dashboard.twbx` in Tableau Desktop or Tableau Public.
2. The package includes five governed CSV sources, so BigQuery credentials are not required for this static portfolio demonstration.
3. If the source extracts change, regenerate the package with:

```bash
python3 scripts/build_tableau_workbook.py
```

The packaged workbook was successfully loaded and rendered in Tableau Desktop 2026.2 on 2026-08-18. Its separate aggregate sources support a portable full-window dashboard but not global cross-source filtering.

### Direct BigQuery enhancement

1. Tableau → Connect → Google BigQuery.
2. Authenticate to the project that owns `marketing_analytics`.
3. Add each table as a separate Tableau data source. Do not physically join marts with different grains.
4. Use an extract for responsive portfolio demos, or Live for a warehouse-centric demonstration.
5. Follow `docs/dashboard_spec.md`.

### Manual CSV refresh

1. Run one `SELECT` at a time from `sql/99_exports/99_tableau_exports.sql`.
2. In the Cloud Console, select **Save results → CSV**.
3. Save files into `exports/`; generated CSV files are intentionally gitignored.

Google limits local CSV downloads of query results, so the session-grain extract may require a direct Tableau connection, a narrower date range, or Cloud Storage export.

## Verification checklist

- Source profile returns the documented 2020-11-01 to 2021-01-31 range.
- `dq_results` contains no `FAIL` rows.
- Warning counts are recorded in `docs/verified_results.md`.
- Revenue and transactions reconcile between daily mart and order fact.
- Dashboard rate calculations use summed numerators/denominators, not averages of row-level rates.
- Three findings are reproducible from saved SQL/filter context.
- The two statistical comparisons reproduce `docs/statistical_analysis.md` and retain their non-causal caveats.
- Screenshots show the same totals recorded in the verified-results log.
