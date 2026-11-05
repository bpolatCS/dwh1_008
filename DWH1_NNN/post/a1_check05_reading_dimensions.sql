-- The orchestrator supplies the warehouse/staging search_path for this transaction.

WITH dimension_summary AS (
    SELECT
        COUNT(*) AS fact_rows,
        COUNT(CASE WHEN tm.month_sk IS NULL THEN 1 END) AS missing_month,
        COUNT(CASE WHEN d.device_sk IS NULL THEN 1 END) AS missing_device,
        COUNT(CASE WHEN pa.paramalert_sk IS NULL THEN 1 END) AS missing_paramalert,
        COUNT(CASE WHEN he.healtheffect_sk IS NULL THEN 1 END) AS missing_health_effect,
        COUNT(CASE WHEN w.weather_sk IS NULL THEN 1 END) AS missing_weather
    FROM ft_reading_results f
    LEFT JOIN dim_timemonth tm ON tm.month_sk = f.month_sk
    LEFT JOIN dim_device d ON d.device_sk = f.device_sk
    LEFT JOIN dim_paramalert pa ON pa.paramalert_sk = f.paramalert_sk
    LEFT JOIN dim_health_effect he ON he.healtheffect_sk = f.healtheffect_sk
    LEFT JOIN dim_weather w ON w.weather_sk = f.weather_sk
)
SELECT
    'Reading dimension references are valid' AS check_name,
    CASE WHEN missing_month = 0 AND missing_device = 0 AND missing_paramalert = 0 AND missing_health_effect = 0 AND missing_weather = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    fact_rows,
    missing_month,
    missing_device,
    missing_paramalert,
    missing_health_effect,
    missing_weather
FROM dimension_summary;