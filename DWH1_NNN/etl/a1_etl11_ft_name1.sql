-- DWH1 ETL: load ft_name1
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE ft_service RESTART IDENTITY;


-- Step 2: Insert from source
INSERT INTO ft_service (
    timeday_sk, device_sk, servicetype_sk, employment_sk,
    service_count, total_service_cost, total_duration_minutes, avg_service_quality
)
SELECT
    dt.timeday_sk,
    dd.device_sk,
    ds.servicetype_sk,
    de.employement_sk,
    COUNT(*)::INT AS service_count,
    SUM(se.servicecost)::BIGINT AS total_service_cost,
    SUM(se.durationminutes)::BIGINT AS total_duration_minutes,
    AVG(se.servicequality)::NUMERIC(12,6) AS avg_service_quality
FROM tb_serviceevent AS se
JOIN dim_timeday AS dt
    ON dt.full_date = se.servicedat
JOIN dim_device AS dd
    ON dd.device_id = se.sensordevid
JOIN dim_service_type AS ds
    ON ds.servicetype_id = se.servicetypeid
JOIN dim_employment AS de
    ON de.employee_id = se.employeeid
GROUP BY
    dt.timeday_sk, dd.device_sk, ds.servicetype_sk, de.employement_sk
ORDER BY
    dt.timeday_sk, dd.device_sk, ds.servicetype_sk, de.employement_sk;
