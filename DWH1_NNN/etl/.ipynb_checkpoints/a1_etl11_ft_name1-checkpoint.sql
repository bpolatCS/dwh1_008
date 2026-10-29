-- DWH1 ETL: load ft_name1
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE ft_name1 RESTART IDENTITY;

-- Step 2: Insert from source
INSERT INTO ft_name1 (id)
SELECT 1
    -- , ...
-- FROM ...
-- JOIN ...
-- WHERE ...
;
