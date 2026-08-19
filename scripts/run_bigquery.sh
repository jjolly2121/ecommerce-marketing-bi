#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 YOUR_PROJECT_ID" >&2
  exit 64
fi

if ! command -v bq >/dev/null 2>&1; then
  echo "Error: bq CLI is not installed or is not on PATH." >&2
  exit 69
fi

project_id="$1"
if [[ ! "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  echo "Error: '$project_id' does not look like a valid Google Cloud project ID." >&2
  exit 65
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"

sql_files=(
  "$repo_dir/sql/00_setup/00_create_dataset.sql"
  "$repo_dir/sql/01_profiling/01_source_profile.sql"
  "$repo_dir/sql/10_staging/10_stg_events.sql"
  "$repo_dir/sql/10_staging/11_stg_item_events.sql"
  "$repo_dir/sql/20_core/20_fct_sessions.sql"
  "$repo_dir/sql/20_core/21_fct_orders.sql"
  "$repo_dir/sql/30_marts/30_mart_daily_performance.sql"
  "$repo_dir/sql/30_marts/31_mart_weekly_executive.sql"
  "$repo_dir/sql/30_marts/32_mart_product_performance.sql"
  "$repo_dir/sql/30_marts/33_mart_customer_summary.sql"
  "$repo_dir/sql/30_marts/34_mart_purchase_cohorts.sql"
  "$repo_dir/sql/30_marts/35_mart_executive_scorecard.sql"
  "$repo_dir/sql/50_statistics/50_conversion_comparisons.sql"
  "$repo_dir/sql/90_validation/90_data_quality_results.sql"
  "$repo_dir/sql/90_validation/91_publish_validation.sql"
  "$repo_dir/sql/40_analysis/40_executive_findings.sql"
)

for sql_file in "${sql_files[@]}"; do
  rendered_file="$(mktemp)"
  sed "s/YOUR_PROJECT_ID/$project_id/g" "$sql_file" > "$rendered_file"
  echo "Running ${sql_file#"$repo_dir/"}"
  bq query \
    --project_id="$project_id" \
    --location=US \
    --maximum_bytes_billed=25000000000 \
    --use_legacy_sql=false < "$rendered_file"
  rm -f "$rendered_file"
done

echo "Build complete. Review $project_id:marketing_analytics.dq_results before publishing."
