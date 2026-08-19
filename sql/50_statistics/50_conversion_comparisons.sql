-- BigQuery GoogleSQL
-- Approximate 95% confidence intervals for two preselected conversion comparisons.
-- These are descriptive diagnostics, not causal tests. Session independence is imperfect
-- because a pseudonymous user can contribute more than one session.

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.marketing_analytics.mart_conversion_comparisons` AS
WITH segment_counts AS (
  SELECT
    user_type AS population,
    COUNT(*) AS sessions,
    SUM(has_purchase) AS purchase_sessions
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
  WHERE user_type IN ('New Session', 'Returning Session')
  GROUP BY population
), channel_counts AS (
  SELECT
    acquisition_channel AS population,
    COUNT(*) AS sessions,
    SUM(has_purchase) AS purchase_sessions
  FROM `YOUR_PROJECT_ID.marketing_analytics.fct_sessions`
  WHERE acquisition_channel IN ('Referral', 'Paid Search')
  GROUP BY population
), comparisons AS (
  SELECT
    'Returning vs New Sessions' AS comparison_name,
    'Returning Session' AS population_a,
    'New Session' AS population_b,
    a.sessions AS sessions_a,
    a.purchase_sessions AS purchase_sessions_a,
    b.sessions AS sessions_b,
    b.purchase_sessions AS purchase_sessions_b,
    'Session' AS unit_of_analysis,
    'Behavioral segment; descriptive, not a lifecycle-treatment effect' AS interpretation_scope
  FROM segment_counts AS a
  CROSS JOIN segment_counts AS b
  WHERE a.population = 'Returning Session'
    AND b.population = 'New Session'

  UNION ALL

  SELECT
    'Referral vs Paid Search',
    'Referral',
    'Paid Search',
    a.sessions,
    a.purchase_sessions,
    b.sessions,
    b.purchase_sessions,
    'Session',
    'First-user acquisition; excludes spend, margin, and incrementality'
  FROM channel_counts AS a
  CROSS JOIN channel_counts AS b
  WHERE a.population = 'Referral'
    AND b.population = 'Paid Search'
), rates AS (
  SELECT
    *,
    SAFE_DIVIDE(purchase_sessions_a, sessions_a) AS conversion_rate_a,
    SAFE_DIVIDE(purchase_sessions_b, sessions_b) AS conversion_rate_b
  FROM comparisons
), estimates AS (
  SELECT
    *,
    conversion_rate_a - conversion_rate_b AS absolute_conversion_difference,
    SAFE_DIVIDE(conversion_rate_a, conversion_rate_b) AS relative_conversion_ratio,
    SQRT(
      SAFE_DIVIDE(conversion_rate_a * (1 - conversion_rate_a), sessions_a)
      + SAFE_DIVIDE(conversion_rate_b * (1 - conversion_rate_b), sessions_b)
    ) AS unpooled_standard_error
  FROM rates
)
SELECT
  *,
  absolute_conversion_difference - 1.96 * unpooled_standard_error
    AS lower_95_ci_absolute_difference,
  absolute_conversion_difference + 1.96 * unpooled_standard_error
    AS upper_95_ci_absolute_difference,
  'Normal approximation for two proportions; repeated-user sessions can narrow the interval'
    AS confidence_interval_caveat
FROM estimates;
