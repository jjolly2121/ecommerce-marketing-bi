#!/usr/bin/env python3
"""Build or verify integrity metadata for checked-in portfolio CSV snapshots."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPORTS = ROOT / "exports"
MANIFEST = EXPORTS / "manifest.json"

SOURCE_SQL = {
    "portfolio_channel_performance.csv": "sql/40_analysis/40_executive_findings.sql",
    "portfolio_conversion_comparisons.csv": "sql/50_statistics/50_conversion_comparisons.sql",
    "portfolio_customer_segments.csv": "sql/40_analysis/40_executive_findings.sql",
    "portfolio_data_quality.csv": "sql/90_validation/91_publish_validation.sql",
    "portfolio_device_performance.csv": "sql/40_analysis/40_executive_findings.sql",
    "portfolio_executive_scorecard.csv": "sql/30_marts/35_mart_executive_scorecard.sql",
    "portfolio_funnel.csv": "sql/40_analysis/40_executive_findings.sql",
    "portfolio_purchase_cohorts.csv": "sql/30_marts/34_mart_purchase_cohorts.sql",
    "portfolio_top_products.csv": "sql/40_analysis/40_executive_findings.sql",
    "portfolio_user_type.csv": "sql/20_core/20_fct_sessions.sql",
    "portfolio_weekly_trend.csv": "sql/40_analysis/40_executive_findings.sql",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def row_count(path: Path) -> int:
    with path.open(newline="", encoding="utf-8") as handle:
        return sum(1 for _ in csv.DictReader(handle))


def expected_manifest() -> dict:
    files = []
    for name, source_sql in sorted(SOURCE_SQL.items()):
        path = EXPORTS / name
        files.append(
            {
                "file": name,
                "rows": row_count(path),
                "sha256": sha256(path),
                "source_sql": source_sql,
            }
        )
    return {
        "project": "e-commerce-marketing-bi",
        "dataset": "marketing_analytics",
        "source_table_suffix_range": "20201101-20210131",
        "verified_on": "2026-08-18",
        "snapshot_note": (
            "Checked-in executive snapshots captured from verified BigQuery results; "
            "use direct BigQuery marts for refreshable Tableau filtering."
        ),
        "files": files,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify manifest without rewriting it")
    args = parser.parse_args()
    expected = expected_manifest()

    if args.check:
        actual = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if actual != expected:
            raise SystemExit("extract manifest is stale; run scripts/build_extract_manifest.py")
        print(f"Extract manifest verified: {len(expected['files'])} CSV snapshots.")
        return 0

    MANIFEST.write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    print(MANIFEST)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
