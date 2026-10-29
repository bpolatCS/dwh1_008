-- DWH1 ETL: load dim_timeday
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_timeday RESTART IDENTITY CASCADE;

-- Step 2: Insert from source
INSERT INTO dim_timeday (
    full_date,
    day_number,
    month_number,
    quarter_number,
    year_number
)
SELECT 
    dates.full_date,
    EXTRACT(DAY FROM dates.full_date)::INT as day_number,
    EXTRACT(MONTH FROM dates.full_date)::INT as month_number,
    EXTRACT(QUARTER FROM dates.full_date)::INT as quarter_number,
    EXTRACT(YEAR FROM dates.full_date)::INT as year_number
FROM (
    SELECT 
        servicedat AS full_date
    FROM tb_serviceevent

    UNION
    
    SELECT 
        readat AS full_date
    FROM tb_readingevent
) AS dates
ORDER BY dates.full_date;
