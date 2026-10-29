-- DWH1 student post-ETL validation example
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- ============================================================
-- Example check: basic integrity of a dimension
-- ============================================================
-- Replace this example with a check that is meaningful for your model.

WITH dwh_summary AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(*) - COUNT(DISTINCT id) AS duplicate_ids,
        COUNT(*) FILTER (WHERE etl_load_timestamp IS NULL) AS missing_load_timestamps
    FROM dim_name1
)

SELECT
    'dim_name1 basic integrity' AS check_name,
    CASE
        WHEN row_count > 0
         AND duplicate_ids = 0
         AND missing_load_timestamps = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    row_count,
    duplicate_ids,
    missing_load_timestamps
FROM dwh_summary;

