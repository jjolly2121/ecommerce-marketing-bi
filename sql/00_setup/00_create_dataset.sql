-- BigQuery GoogleSQL
-- Replace YOUR_PROJECT_ID with the project that will own derived tables.

CREATE SCHEMA IF NOT EXISTS `YOUR_PROJECT_ID.marketing_analytics`
OPTIONS (
  location = 'US',
  description = 'Curated GA4 e-commerce customer journey and marketing BI models'
);

