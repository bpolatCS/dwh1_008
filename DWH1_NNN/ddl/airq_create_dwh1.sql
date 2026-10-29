-- DWH1 warehouse DDL
-- Creates the dimensional-model tables in the active warehouse schema.
-- The table and column definitions below are placeholders.
-- Replace them with your own dimensional model, add/remove tables as required.
-- The orchestrator supplies the correct search_path before this file is executed.

-- -------------------------------
-- 1) DROP TABLE before attempting to create DWH schema tables
-- -------------------------------
DROP TABLE IF EXISTS ft_name2;
DROP TABLE IF EXISTS ft_name1;

DROP TABLE IF EXISTS dim_paramalert;
DROP TABLE IF EXISTS dim_health_effect;
DROP TABLE IF EXISTS dim_employment;
DROP TABLE IF EXISTS ...

-- -------------------------------
-- 2) CREATE TABLE statements for facts and dimensions
-- Please make sure the order in which individual statements are executed respects the FOREIGN KEY constraints
-- -------------------------------
-- non-time dimensions
CREATE TABLE dim_employment (
    employement_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id INT NOT NULL,
    role_id INT NOT NULL,
    badge_number VARCHAR(255) NOT NULL,
    role_name VARCHAR(255) NOT NULL,
    role_level INT NOT NULL,
    role_category VARCHAR(255) NOT NULL,
    effective_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    is_current BOOLEAN NOT NULL,
    is_deleted BOOLEAN NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uc_dim_employment_src UNIQUE (employee_id),
    CONSTRAINT uc_dim_employment_badge_eff UNIQUE (badge_number, effective_date),
    CHECK (expiry_date >= effective_date),
    CHECK (role_level IN (1, 2, 3, 4))
);

CREATE TABLE dim_health_effect (
    healtheffect_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    effect_profile VARCHAR(255) NOT NULL,        
    effect_count INT NOT NULL,
    is_respiratory BOOLEAN NOT NULL,
    is_cardiovascular BOOLEAN NOT NULL,
    is_cancer_risk BOOLEAN NOT NULL,
    is_neurological BOOLEAN NOT NULL,
    is_allergic BOOLEAN NOT NULL,
    is_eye_irritation BOOLEAN NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uc_dim_healtheffect_profile UNIQUE (effect_profile)
);


CREATE TABLE dim_paramalert (
    paramalert_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    param_id INT NOT NULL,
    alert_id INT NOT NULL,                        
    param_name VARCHAR(255) NOT NULL,
    alert_name VARCHAR(255) NOT NULL,    
    param_category VARCHAR(255) NOT NULL,
    param_purpose VARCHAR(255) NOT NULL,
    param_unit VARCHAR(255) NOT NULL,
    alert_level INT NOT NULL,                      
    alert_colour VARCHAR(255) NOT NULL,
    threshold_from DECIMAL(10,4) NOT NULL,         
    threshold_to DECIMAL(10,4),                   
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uc_dim_paramalert_param_level UNIQUE (param_id, alert_level),
    CHECK (alert_level IN (0, 1, 2, 3, 4)),
    CHECK (threshold_to IS NULL OR threshold_to > threshold_from)
);

CREATE TABLE dim_name3 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_name5 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_timeday (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- fact tables
CREATE TABLE ft_name1 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ft_name2 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

