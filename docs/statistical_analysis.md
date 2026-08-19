# Statistical Analysis

## Purpose

The project adds two preselected conversion comparisons to demonstrate basic statistical reasoning without turning descriptive clickstream data into causal claims. Results are materialized in `mart_conversion_comparisons` by `sql/50_statistics/50_conversion_comparisons.sql`.

## Method

For each pair, the model calculates conversion rates, an absolute percentage-point difference, a relative rate ratio, an unpooled standard error, and a normal-approximation 95% confidence interval for the absolute difference.

The unit is a session. A pseudonymous user can contribute multiple sessions, so observations are not perfectly independent and the interval may be too narrow. The interval is therefore a diagnostic measure of precision—not evidence that a channel or returning behavior caused conversion.

## Verified results

| Comparison | Conversion A | Conversion B | Absolute difference | Approx. 95% CI | Rate ratio |
|---|---:|---:|---:|---:|---:|
| Returning vs New Sessions | 3.102% | 0.681% | +2.421 pp | +2.308 to +2.534 pp | 4.553× |
| Referral vs Paid Search | 1.662% | 0.980% | +0.683 pp | +0.499 to +0.866 pp | 1.697× |

Both approximate intervals exclude zero, but practical interpretation still depends on measurement quality and business context. Returning sessions are a behavioral segment rather than a treatment. Channel is first-user acquisition, and the sample contains no spend, margin, campaign exposure, or incrementality measure.

## Better production method

For decision-grade inference, aggregate or resample at the customer level, use cluster-robust uncertainty for repeated sessions, pre-register comparisons, and evaluate interventions through randomized experiments when feasible.

