
-- Check 02: Service grain
-- Checks that each combination of day, device,
-- service type and employment appears only once.

WITH duplicate_groups AS (
    SELECT
        timeday_sk,
        device_sk,
        servicetype_sk,
        employment_sk,
        COUNT(*) AS row_count
    FROM ft_service
    GROUP BY
        timeday_sk,
        device_sk,
        servicetype_sk,
        employment_sk
    HAVING COUNT(*) > 1
),
fact_summary AS (
    SELECT
        COUNT(*) AS total_rows
    FROM ft_service
),
duplicate_summary AS (
    SELECT
        COUNT(*) AS duplicate_groups
    FROM duplicate_groups
)

SELECT
    'Service grain check' AS check_name,
    CASE
        WHEN f.total_rows > 0
         AND d.duplicate_groups = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    f.total_rows,
    d.duplicate_groups
FROM fact_summary f
CROSS JOIN duplicate_summary d;
