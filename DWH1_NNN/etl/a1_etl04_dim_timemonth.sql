-- DWH1 ETL: load dim_timemonth
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_timemonth RESTART IDENTITY CASCADE;

-- Step 2: Insert one row per month (2024-01 to 2025-12)
INSERT INTO dim_timemonth (
    year_number,
    quarter_number,
    month_number,
    month_start
)
SELECT
    EXTRACT(YEAR FROM months.month_start)::INT AS year_number,
    EXTRACT(QUARTER FROM months.month_start)::INT AS quarter_number,
    EXTRACT(MONTH FROM months.month_start)::INT AS month_number,
    months.month_start::DATE AS month_start
FROM GENERATE_SERIES(DATE '2024-01-01', DATE '2025-12-01', INTERVAL '1 month') AS months(month_start)
ORDER BY months.month_start;
