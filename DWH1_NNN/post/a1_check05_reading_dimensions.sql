-- The orchestrator supplies the warehouse/staging search_path for this transaction.

WITH dimension_summary AS (
    SELECT
        COUNT(*) AS fact_rows,
        COUNT(CASE WHEN t.timeday_sk IS NULL THEN 1 END) AS missing_timeday,
        COUNT(CASE WHEN d.device_sk IS NULL THEN 1 END) AS missing_device,
        COUNT(CASE WHEN pa.paramalert_sk IS NULL THEN 1 END) AS missing_paramalert,
        COUNT(CASE WHEN he.healtheffect_sk IS NULL THEN 1 END) AS missing_health_effect
    FROM ft_reading_results f
    LEFT JOIN dim_timeday t ON t.timeday_sk = f.timeday_sk
    LEFT JOIN dim_device d ON d.device_sk = f.device_sk
    LEFT JOIN dim_paramalert pa ON pa.paramalert_sk = f.paramalert_sk
    LEFT JOIN dim_health_effect he ON he.healtheffect_sk = f.healtheffect_sk
)
SELECT
    'Reading dimension references are valid' AS check_name,
    CASE WHEN missing_timeday = 0 AND missing_device = 0 AND missing_paramalert = 0 AND missing_health_effect = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    fact_rows,
    missing_timeday,
    missing_device,
    missing_paramalert,
    missing_health_effect
FROM dimension_summary;