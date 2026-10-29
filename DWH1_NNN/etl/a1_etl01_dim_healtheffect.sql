-- DWH1 ETL: load dim_health_effect
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE dim_health_effect RESTART IDENTITY CASCADE;

-- Step 2: Insert from source
INSERT INTO dim_health_effect (
    effect_profile, 
    effect_count,
    is_respiratory,
    is_cardiovascular, 
    is_cancer_risk,
    is_neurological,
    is_allergic,
    is_eye_irritation
)
Binder Error: 
Table "h" does not have a column named "id" Candidate bindings: : "id,effectname,description" LINE 13: LEFT JOIN tb_healtheffect_csv h ON h.id = ph.effectid ^



WITH param_profile AS (
    SELECT
        p.id AS param_id,
        COALESCE(STRING_AGG(h.effectname, ', ' ORDER BY h.effectname), 'No known effect') AS effect_profile,
        COUNT(h.id) AS effect_count,
        COALESCE(BOOL_OR(h.effectname = 'Respiratory'), FALSE) AS is_respiratory,
        COALESCE(BOOL_OR(h.effectname = 'Cardiovascular'), FALSE) AS is_cardiovascular,
        COALESCE(BOOL_OR(h.effectname = 'Cancer risk'), FALSE) AS is_cancer_risk,
        COALESCE(BOOL_OR(h.effectname = 'Neurological'), FALSE) AS is_neurological,
        COALESCE(BOOL_OR(h.effectname = 'Allergic'), FALSE) AS is_allergic,
        COALESCE(BOOL_OR(h.effectname = 'Eye irritation'), FALSE) AS is_eye_irritation
    FROM tb_param p
    LEFT JOIN tb_paramhealtheffect_csv ph ON ph.paramid = p.id
    LEFT JOIN tb_healtheffect_csv h ON h.id = ph.effectid
    GROUP BY p.id
)

SELECT DISTINCT
    effect_profile,
    effect_count,
    is_respiratory,
    is_cardiovascular, 
    is_cancer_risk,
    is_neurological,
    is_allergic,
    is_eye_irritation
FROM param_profile
ORDER BY effect_count, effect_profile;

