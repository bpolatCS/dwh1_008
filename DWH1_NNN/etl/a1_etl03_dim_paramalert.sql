-- DWH1 ETL: load dim_paramalert
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_paramalert RESTART IDENTITY CASCADE;

-- Step 2: Insert from source
INSERT INTO dim_paramalert (
    param_id
    alert_id,
    param_name,
    alert_name,
    param_category,
    param_purpose,
    param_unit,
    alert_level,
    alert_colour,
    threshold_from,
    threshold_to
)

WITH bands AS (
    SELECT
        pa.paramid AS param_id,
        a.id AS alert_id,
        ROW_NUMBER() OVER (PARTITION BY pa.paramid ORDER BY pa.threshold) AS alert_level,
        a.alertname AS alert_name,
        a.colour AS alert_colour,
        pa.threshold AS threshold_from
    FROM tb_paramalert_csv pa
    JOIN tb_alert_csv a ON a.id = pa.alertid
    
    UNION ALL
    
    SELECT
        p.id, 
        0, 
        0, 
        'No alert', 
        'None', 
        0
    FROM tb_param_csv p
)
SELECT
    p.id,
    b.alert_id,
    p.paramname,
    b.alert_name,
    p.category,
    p.purpose,
    p.unit,
    b.alert_level,
    b.alert_colour,
    b.threshold_from,
    LEAD(b.threshold_from) OVER (PARTITION BY b.param_id ORDER BY b.alert_level) as threshold_to
FROM bands b
JOIN tb_param_csv p ON p.id = b.param_id
ORDER BY p.id, b.alert_level;
