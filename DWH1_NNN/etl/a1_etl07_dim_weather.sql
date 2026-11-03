-- DWH1 ETL: load dim_weather (static junk dimension: rain condition x wind condition)
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_weather RESTART IDENTITY CASCADE;

-- Step 2: Insert all condition combinations
INSERT INTO dim_weather (
    rain_condition,
    wind_condition
)
SELECT
    r.rain_condition,
    w.wind_condition
FROM (VALUES ('Rainy'), ('Dry'), ('Unknown')) AS r(rain_condition)
CROSS JOIN (VALUES ('Calm'), ('Windy'), ('Unknown')) AS w(wind_condition)
ORDER BY r.rain_condition, w.wind_condition;
