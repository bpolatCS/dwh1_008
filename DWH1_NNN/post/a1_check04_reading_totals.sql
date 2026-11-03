-- The orchestrator supplies the warehouse/staging search_path for this transaction.

WITH source_summary AS (
    SELECT
        COUNT(*) AS source_readings,
        COALESCE(SUM(dataquality), 0) AS source_quality,
        COALESCE(SUM(datavolumekb), 0) AS source_volume
    FROM stg1_008.tb_readingevent
),
fact_summary AS (
    SELECT
        COALESCE(SUM(reading_count), 0) AS fact_readings,
        COALESCE(SUM(data_quality_sum), 0) AS fact_quality,
        COALESCE(SUM(data_volume_kb_sum), 0) AS fact_volume
    FROM dwh1_008.ft_reading_results
)
SELECT
    'Reading totals match source' AS check_name,
    CASE
        WHEN s.source_readings = f.fact_readings AND s.source_quality = f.fact_quality AND s.source_volume = f.fact_volume THEN 'PASS'
    	ELSE 'FAIL' 
	END AS status,
    s.source_readings,
    f.fact_readings,
    s.source_quality,
    f.fact_quality,
    s.source_volume,
    f.fact_volume,
    f.fact_readings - s.source_readings AS reading_difference,
    f.fact_quality - s.source_quality AS quality_difference,
    f.fact_volume - s.source_volume AS volume_difference
FROM source_summary s
CROSS JOIN fact_summary f;