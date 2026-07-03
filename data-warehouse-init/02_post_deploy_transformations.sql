-- ==============================================================================
-- Bansi.la Automated Post-Deployment Transformations
-- Execution Layer: Materialized Views and Aggregate Tables
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Create Aggregate Table: summary_daily_active
-- ------------------------------------------------------------------------------
-- Safely drop existing table if the container is being rebuilt
DROP TABLE IF EXISTS summary_daily_active;

-- Create the table with pre-configured indexes for BI performance
CREATE TABLE summary_daily_active (
    active_date DATE,
    company_id INT,
    INDEX idx_date (active_date),
    INDEX idx_company (company_id)
);

-- Ingest the historical data (excluding internal company 97 and system user 0)
INSERT INTO summary_daily_active (active_date, company_id)
SELECT DISTINCT 
    DATE(created_at), 
    company_id
FROM g4o_audits
WHERE company_id IS NOT NULL 
  AND company_id != 97
  AND user_id != 0;


-- ------------------------------------------------------------------------------
-- 2. Create View: vw_renewal_pipeline
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_renewal_pipeline AS
WITH LatestSubscriptions AS (
    SELECT 
        company_id,
        id AS subscription_id,
        status,
        end_date,
        amount AS sticker_price,
        -- Calculate exact days until/since expiration
        DATEDIFF(end_date, CURRENT_DATE) AS days_to_expiry,
        -- This guarantees we only look at the most recent subscription per company
        ROW_NUMBER() OVER(PARTITION BY company_id ORDER BY end_date DESC) as rn
    FROM g4o_subscriptions
    WHERE company_id != 97
)
SELECT 
    company_id,
    subscription_id,
    status,
    end_date,
    days_to_expiry,
    sticker_price AS revenue_at_risk,
    -- The Bucketing Logic
    (CASE 
        WHEN days_to_expiry BETWEEN -30 AND -22 THEN '1. Expired 3-4 Weeks Ago'
        WHEN days_to_expiry BETWEEN -21 AND -15 THEN '2. Expired 2-3 Weeks Ago'
        WHEN days_to_expiry BETWEEN -14 AND -8  THEN '3. Expired 1-2 Weeks Ago'
        WHEN days_to_expiry BETWEEN -7 AND -1   THEN '4. Expired < 1 Week Ago'
        WHEN days_to_expiry BETWEEN 0 AND 7     THEN '5. Expires in < 1 Week'
        WHEN days_to_expiry BETWEEN 8 AND 14    THEN '6. Expires in 1-2 Weeks'
        WHEN days_to_expiry BETWEEN 15 AND 21   THEN '7. Expires in 2-3 Weeks'
        WHEN days_to_expiry BETWEEN 22 AND 30   THEN '8. Expires in 3-4 Weeks'
        ELSE '9. Outside Window'
    END) COLLATE utf8mb4_unicode_ci AS renewal_cohort
FROM LatestSubscriptions
WHERE rn = 1 
  -- We only care about the +/- 30 day window for this specific dashboard
  AND days_to_expiry BETWEEN -30 AND 30;