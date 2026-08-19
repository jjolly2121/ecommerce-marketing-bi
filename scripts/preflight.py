#!/usr/bin/env python3
"""Repository-only checks that do not claim to validate BigQuery execution."""

from pathlib import Path
import csv
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile


REPO = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "README.md",
    "CASE_STUDY.md",
    "LICENSE",
    "docs/business_context.md",
    "docs/data_dictionary.md",
    "docs/data_model.md",
    "docs/dashboard_spec.md",
    "docs/kpi_definitions.md",
    "docs/limitations.md",
    "docs/setup.md",
    "docs/source_attribution.md",
    "docs/verified_results.md",
    "docs/executive_summary.md",
    "docs/statistical_analysis.md",
    "docs/performance_notes.md",
    "scripts/build_extract_manifest.py",
    "scripts/build_tableau_workbook.py",
    "tableau/executive_dashboard.png",
    "tableau/Ecommerce_Marketing_Executive_Dashboard.twb",
    "tableau/Ecommerce_Marketing_Executive_Dashboard.twbx",
    "exports/portfolio_executive_scorecard.csv",
    "exports/portfolio_funnel.csv",
    "exports/portfolio_channel_performance.csv",
    "exports/portfolio_device_performance.csv",
    "exports/portfolio_user_type.csv",
    "exports/portfolio_customer_segments.csv",
    "exports/portfolio_weekly_trend.csv",
    "exports/portfolio_purchase_cohorts.csv",
    "exports/portfolio_top_products.csv",
    "exports/portfolio_data_quality.csv",
    "exports/portfolio_conversion_comparisons.csv",
    "exports/manifest.json",
    "sql/10_staging/10_stg_events.sql",
    "sql/10_staging/11_stg_item_events.sql",
    "sql/20_core/20_fct_sessions.sql",
    "sql/20_core/21_fct_orders.sql",
    "sql/30_marts/30_mart_daily_performance.sql",
    "sql/30_marts/31_mart_weekly_executive.sql",
    "sql/30_marts/32_mart_product_performance.sql",
    "sql/30_marts/33_mart_customer_summary.sql",
    "sql/30_marts/34_mart_purchase_cohorts.sql",
    "sql/30_marts/35_mart_executive_scorecard.sql",
    "sql/40_analysis/40_executive_findings.sql",
    "sql/50_statistics/50_conversion_comparisons.sql",
    "sql/90_validation/90_data_quality_results.sql",
    "sql/90_validation/91_publish_validation.sql",
]

REQUIRED_SQL_PATTERNS = {
    r"\bJOIN\b": "join",
    r"\bWITH\b": "common table expression",
    r"\bROW_NUMBER\s*\(": "window function",
    r"\bLAG\s*\(": "period comparison",
    r"\bCOUNTIF\s*\(": "conditional aggregation",
    r"\bSAFE_DIVIDE\s*\(": "safe rate calculation",
    r"\bUNNEST\s*\(": "nested data handling",
    r"\bASSERT\b": "blocking validation",
}


def main() -> int:
    failures: list[str] = []

    for relative_path in REQUIRED_FILES:
        if not (REPO / relative_path).is_file():
            failures.append(f"missing required file: {relative_path}")

    sql_text = "\n".join(
        path.read_text(encoding="utf-8") for path in sorted((REPO / "sql").rglob("*.sql"))
    )

    for pattern, label in REQUIRED_SQL_PATTERNS.items():
        if not re.search(pattern, sql_text, flags=re.IGNORECASE):
            failures.append(f"SQL portfolio concept not found: {label}")

    if re.search(r",\s*\n\s*FROM\b", sql_text, flags=re.IGNORECASE):
        failures.append("possible trailing comma immediately before FROM")

    readme = (REPO / "README.md").read_text(encoding="utf-8")
    if "Verified build" not in readme:
        failures.append("README must state the verified BigQuery build status")
    if "Tableau Desktop 2026.2" not in readme:
        failures.append("README must state the verified Tableau Desktop build status")
    if "All ten blocking data-quality checks passed" not in readme:
        failures.append("README must state the verified ten-check publication gate")
    public_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in [REPO / "README.md", *sorted((REPO / "docs").glob("*.md")), REPO / "CASE_STUDY.md"]
        if path.exists()
    )
    for pattern, label in [
        (r"(?i)\bTODO\b|\bFIXME\b|\bTBD\b|lorem ipsum", "unfinished placeholder"),
        (r"/Users/", "local filesystem path"),
        (r"(?i)truthfulness rule|essential weekend scope|interview-safe", "public process language"),
    ]:
        if re.search(pattern, public_text):
            failures.append(f"public documentation contains {label}")

    def csv_rows(relative_path: str) -> list[dict[str, str]]:
        with (REPO / relative_path).open(newline="", encoding="utf-8") as handle:
            return list(csv.DictReader(handle))

    scorecard = csv_rows("exports/portfolio_executive_scorecard.csv")[0]
    expected_revenue = float(scorecard["revenue_usd"])
    expected_sessions = int(scorecard["sessions"])
    expected_orders = int(scorecard["governed_orders"])

    for relative_path, revenue_field in [
        ("exports/portfolio_channel_performance.csv", "revenue_usd"),
        ("exports/portfolio_device_performance.csv", "revenue_usd"),
        ("exports/portfolio_user_type.csv", "revenue_usd"),
        ("exports/portfolio_customer_segments.csv", "observed_revenue_usd"),
    ]:
        observed = sum(float(row[revenue_field]) for row in csv_rows(relative_path))
        if abs(observed - expected_revenue) > 0.01:
            failures.append(f"extract revenue does not reconcile: {relative_path}")

    channel_rows = csv_rows("exports/portfolio_channel_performance.csv")
    if sum(int(row["sessions"]) for row in channel_rows) != expected_sessions:
        failures.append("channel extract sessions do not reconcile to scorecard")
    if sum(int(row["transactions"]) for row in channel_rows) != expected_orders:
        failures.append("channel extract orders do not reconcile to scorecard")

    funnel_rows = csv_rows("exports/portfolio_funnel.csv")
    funnel_sessions = [int(row["sessions"]) for row in funnel_rows]
    if funnel_sessions[0] != int(scorecard["product_view_sessions"]):
        failures.append("ordered funnel entry sessions do not reconcile to scorecard product views")
    if funnel_sessions != sorted(funnel_sessions, reverse=True):
        failures.append("ordered funnel stages must be monotonically decreasing")
    for previous, row in zip(funnel_sessions, funnel_rows[1:]):
        current = int(row["sessions"])
        observed_rate = float(row["step_conversion_rate"])
        if abs(observed_rate - current / previous) > 1e-9:
            failures.append(f"ordered funnel rate does not reconcile: {row['stage']}")

    quality_rows = csv_rows("exports/portfolio_data_quality.csv")
    error_rows = [row for row in quality_rows if row["severity"] == "ERROR"]
    if len(error_rows) != 10 or any(row["status"] != "PASS" for row in error_rows):
        failures.append("quality extract must contain ten passing ERROR checks")

    comparison_rows = csv_rows("exports/portfolio_conversion_comparisons.csv")
    if len(comparison_rows) != 2:
        failures.append("statistical extract must contain the two preselected comparisons")
    for row in comparison_rows:
        lower = float(row["lower_95_ci_absolute_difference"])
        upper = float(row["upper_95_ci_absolute_difference"])
        estimate = float(row["absolute_conversion_difference"])
        if not lower <= estimate <= upper:
            failures.append(f"statistical estimate falls outside its interval: {row['comparison_name']}")

    manifest = json.loads((REPO / "exports/manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        path = REPO / "exports" / entry["file"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry["sha256"]:
            failures.append(f"extract manifest hash mismatch: {entry['file']}")
        if len(csv_rows(f"exports/{entry['file']}")) != entry["rows"]:
            failures.append(f"extract manifest row-count mismatch: {entry['file']}")

    twb_path = REPO / "tableau/Ecommerce_Marketing_Executive_Dashboard.twb"
    try:
        workbook_root = ET.parse(twb_path).getroot()
        worksheet_names = {node.attrib.get("name") for node in workbook_root.findall("./worksheets/worksheet")}
        dashboard_names = {node.attrib.get("name") for node in workbook_root.findall("./dashboards/dashboard")}
        if len(worksheet_names) != 10:
            failures.append("Tableau workbook must contain ten native worksheets")
        if "Executive Dashboard" not in dashboard_names:
            failures.append("Tableau workbook is missing the executive dashboard")
    except ET.ParseError as exc:
        failures.append(f"Tableau TWB is not well-formed XML: {exc}")

    required_package_entries = {
        twb_path.name,
        *{f"Data/{spec}" for spec in [
            "portfolio_channel_performance.csv",
            "portfolio_executive_scorecard.csv",
            "portfolio_funnel.csv",
            "portfolio_user_type.csv",
            "portfolio_weekly_trend.csv",
        ]},
    }
    with zipfile.ZipFile(REPO / "tableau/Ecommerce_Marketing_Executive_Dashboard.twbx") as package:
        package_names = set(package.namelist())
        if not required_package_entries.issubset(package_names):
            failures.append("Tableau packaged workbook is missing a required local extract")
        if any(name.startswith("Data/Data/") for name in package_names):
            failures.append("Tableau package contains incorrectly nested Data/Data sources")
        if package.testzip() is not None:
            failures.append("Tableau packaged workbook contains a corrupt archive entry")
        packaged_twb = package.read(twb_path.name).decode("utf-8")
        if re.search(r"machine-id|author-id|/Users/", packaged_twb):
            failures.append("Tableau package contains local machine or author metadata")

    if failures:
        print("Preflight failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"Preflight passed: {len(REQUIRED_FILES)} required artifacts and all SQL concept checks found.")
    print("Scope note: this validates repository structure and extract reconciliation, not a fresh BigQuery run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
