
-- Check 03: Service measures
-- Checks that service counts, costs, durations
-- and quality values are valid.

WITH service_summary AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE service_count <= 0
        ) AS invalid_counts,
        COUNT(*) FILTER (
            WHERE total_service_cost < 0
        ) AS invalid_costs,
        COUNT(*) FILTER (
            WHERE total_duration_minutes < 0
               OR max_duration_minutes < 0
               OR max_duration_minutes > total_duration_minutes
        ) AS invalid_durations,
        COUNT(*) FILTER (
            WHERE avg_service_quality NOT BETWEEN 1 AND 5
        ) AS invalid_quality
    FROM ft_service
)

SELECT
    'Service measures check' AS check_name,
    CASE
        WHEN total_rows > 0
         AND invalid_counts = 0
         AND invalid_costs = 0
         AND invalid_durations = 0
         AND invalid_quality = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    total_rows,
    invalid_counts,
    invalid_costs,
    invalid_durations,
    invalid_quality
FROM service_summary;
