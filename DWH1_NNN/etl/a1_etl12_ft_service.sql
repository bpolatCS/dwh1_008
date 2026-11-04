
-- DWH1 ETL: load ft_service
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE ft_service RESTART IDENTITY;

-- Step 2: Insert from source
INSERT INTO ft_service (
    timeday_sk,
    device_sk,
    servicetype_sk,
    employment_sk,
    service_count,
    total_service_cost,
    total_duration_minutes,
    max_duration_minutes,
    avg_service_quality
)
WITH service_detail AS (
    SELECT
        t.timeday_sk,
        d.device_sk,
        st.servicetype_sk,
        e.employement_sk AS employment_sk,
        se.servicecost,
        se.durationminutes,
        se.servicequality
    FROM tb_serviceevent AS se
    LEFT JOIN dim_timeday AS t ON t.full_date = se.servicedat
    LEFT JOIN dim_device AS d ON d.device_id = se.sensordevid
    LEFT JOIN dim_service_type AS st ON st.servicetype_id = se.servicetypeid
    LEFT JOIN dim_employment AS e ON e.employee_id = se.employeeid
)
SELECT
    timeday_sk,
    device_sk,
    servicetype_sk,
    employment_sk,
    COUNT(*) AS service_count,
    SUM(servicecost) AS total_service_cost,
    SUM(durationminutes) AS total_duration_minutes,
    MAX(durationminutes) AS max_duration_minutes,
    AVG(servicequality)::NUMERIC(12,6) AS avg_service_quality
FROM service_detail
WHERE timeday_sk IS NOT NULL
    AND device_sk IS NOT NULL
    AND servicetype_sk IS NOT NULL
    AND employment_sk IS NOT NULL
GROUP BY
    timeday_sk,
    device_sk,
    servicetype_sk,
    employment_sk;
