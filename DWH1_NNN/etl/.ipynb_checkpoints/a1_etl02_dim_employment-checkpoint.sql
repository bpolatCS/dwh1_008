-- DWH1 ETL: load dim_employment
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_employment RESTART IDENTITY CASCADE;

-- Step 2: Insert from source
INSERT INTO dim_employment (
    employee_src_id, 
    badgenumber, 
    role_src_id, 
    rolename, 
    rolelevel, 
    rolecategory,
    effective_date, 
    expiry_date, 
    is_current, 
    is_deleted
)
SELECT
    e.id,
    e.badgenumber,
    r.id,
    r.rolename,
    r.rolelevel,
    r.category,
    e.validfrom,
    COALESCE(e.validto, DATE '9999-12-31'),
    ROW_NUMBER() OVER (PARTITION BY e.badgenumber ORDER BY e.validfrom DESC) = 1,
    ROW_NUMBER() OVER (PARTITION BY e.badgenumber ORDER BY e.validfrom DESC) = 1 AND e.validto IS NOT NULL
FROM tb_employee e
JOIN tb_role r ON r.id = e.roleid
ORDER BY e.badgenumber, e.validfrom;
