-- DWH1 student post-ETL validation example
-- The orchestrator supplies the warehouse/staging search_path for this transaction.


-- Check 01: Service source-to-fact reconciliation
-- Verifies that aggregated service counts and costs
-- match the original staging data.

WITH source_summary AS (
    SELECT
        COUNT(*) AS source_events,
        COALESCE(SUM(servicecost), 0) AS source_cost
    FROM tb_serviceevent
),
fact_summary AS (
    SELECT
        COALESCE(SUM(service_count), 0) AS fact_events,
        COALESCE(SUM(total_service_cost), 0) AS fact_cost
    FROM ft_service
)
SELECT
    'Service totals match source' AS check_name,
    CASE
        WHEN s.source_events = f.fact_events
         AND s.source_cost = f.fact_cost
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    s.source_events,
    f.fact_events,
    s.source_cost,
    f.fact_cost,
    f.fact_events - s.source_events AS event_difference,
    f.fact_cost - s.source_cost AS cost_difference
FROM source_summary s
CROSS JOIN fact_summary f;





























