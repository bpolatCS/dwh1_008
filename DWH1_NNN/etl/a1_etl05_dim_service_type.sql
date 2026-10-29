-- DWH1 ETL: load dim_service_type
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_service_type RESTART IDENTITY CASCADE;

-- Step 2: Insert from source
INSERT INTO dim_service_type (
    servicetype_id,
    service_name,
    service_category,
    service_group,
    minimum_qualification,
    service_details
)
SELECT
    id,
    typename,
    category,
    servicegroup,
    minlevel,
    details
FROM tb_servicetype
ORDER BY id;
