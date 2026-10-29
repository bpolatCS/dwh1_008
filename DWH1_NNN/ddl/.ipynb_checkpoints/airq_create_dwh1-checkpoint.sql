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

DROP TABLE IF EXISTS dim_timeday;
DROP TABLE IF EXISTS dim_name4;
DROP TABLE IF EXISTS dim_name3;
DROP TABLE IF EXISTS dim_name2;
DROP TABLE IF EXISTS dim_name1;
--- and so on ...

-- -------------------------------
-- 2) CREATE TABLE statements for facts and dimensions
-- Please make sure the order in which individual statements are executed respects the FOREIGN KEY constraints
-- -------------------------------
-- non-time dimensions
CREATE TABLE dim_name1 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_name2 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_name3 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dim_name4 (
    id INT NOT NULL PRIMARY KEY,
    -- ...
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- time dimension(s)
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

