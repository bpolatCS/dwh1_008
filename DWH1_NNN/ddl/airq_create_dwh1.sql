-- -------------------------------
-- 1) DROP TABLE before attempting to create DWH schema tables
-- -------------------------------
DROP TABLE IF EXISTS ft_name2;
DROP TABLE IF EXISTS ft_service;

DROP TABLE IF EXISTS dim_device;
DROP TABLE IF EXISTS dim_service_type;
DROP TABLE IF EXISTS dim_timeday;
DROP TABLE IF EXISTS dim_paramalert;
DROP TABLE IF EXISTS dim_health_effect;
DROP TABLE IF EXISTS dim_employment;

-- -------------------------------
-- 2) CREATE TABLE statements for facts and dimensions
-- Please make sure the order in which individual statements are executed respects the FOREIGN KEY constraints
-- -------------------------------

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

CREATE TABLE dim_timeday (
    timeday_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_number INT NOT NULL CHECK (day_number BETWEEN 1 AND 31),
    month_number INT NOT NULL CHECK (month_number BETWEEN 1 AND 12),
    quarter_number INT NOT NULL CHECK (quarter_number BETWEEN 1 AND 4),
    year_number INT NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_service_type (
    servicetype_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    servicetype_id INT NOT NULL UNIQUE,
    service_name VARCHAR(255) NOT NULL,
    service_category VARCHAR(255) NOT NULL,
    service_group VARCHAR(255) NOT NULL,
    minimum_qualification INT NOT NULL CHECK (minimum_qualification BETWEEN 1 AND 4),
    service_details VARCHAR(255) NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_device (
    device_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id INT NOT NULL UNIQUE,
    sensor_type_name VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(255) NOT NULL,
    technology VARCHAR(255) NOT NULL,
    location_name VARCHAR(255) NOT NULL,
    location_type VARCHAR(255) NOT NULL,
    city_name VARCHAR(255) NOT NULL,
    country_name VARCHAR(255) NOT NULL,
    altitude INT NOT NULL,
    installed_at DATE NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- fact tables
CREATE TABLE ft_service (
    service_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timeday_sk INT NOT NULL REFERENCES dim_timeday(timeday_sk),
    device_sk INT NOT NULL REFERENCES dim_device(device_sk),
    servicetype_sk INT NOT NULL REFERENCES dim_service_type(servicetype_sk),
    employment_sk INT NOT NULL REFERENCES dim_employment(employement_sk),
    service_count INT NOT NULL CHECK (service_count > 0),
    total_service_cost BIGINT NOT NULL,
    total_duration_minutes BIGINT NOT NULL CHECK (total_duration_minutes >= 0),
    avg_service_quality NUMERIC(12,6) NOT NULL CHECK (avg_service_quality BETWEEN 1 AND 5),
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (timeday_sk, device_sk, servicetype_sk, employment_sk)
);

CREATE TABLE ft_name2 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

