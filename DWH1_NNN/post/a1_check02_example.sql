-- DWH1 student post-ETL validation example
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- ============================================================
-- Example check: source-to-target reconciliation for a fact
-- ============================================================
-- Replace source_count with logic that calculates the expected number
-- of rows at the grain of your fact table from the relevant staging data.

WITH source_count AS (
    SELECT 1::BIGINT AS row_count
),
dwh_count AS (
    SELECT COUNT(*) AS row_count
    FROM ft_name1
)

SELECT
    'ft_name1 row count matches expected source result' AS check_name,
    CASE
        WHEN d.row_count = s.row_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    s.row_count AS source_rows,
    d.row_count AS target_rows,
    d.row_count - s.row_count AS row_difference
FROM dwh_count d
CROSS JOIN source_count s;




























