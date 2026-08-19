-- BigQuery GoogleSQL
-- Stops the workflow when a publish-blocking test fails, then returns the complete audit table.

ASSERT (
  SELECT COUNTIF(severity = 'ERROR' AND failure_count > 0)
  FROM `YOUR_PROJECT_ID.marketing_analytics.dq_results`
) = 0 AS 'Publish validation failed. Inspect marketing_analytics.dq_results.';

SELECT *
FROM `YOUR_PROJECT_ID.marketing_analytics.dq_results`
ORDER BY
  CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
  check_name;

