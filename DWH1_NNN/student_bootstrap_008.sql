-- This is set up and initial configuration file 
-- Here we create 'airq' database and create a role
-- Please do not work/connect under the default 'postgres' role, create your own grp_008 role (NNN is your group number)
-- Execute this script manually only once on your computer, before starting work on the actual dimensional modelling and DDL/ETL/post-checks

-- -------------------------------
-- 1) Drop and recreate airq database
-- -------------------------------
-- Terminate all connections to 'airq'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'airq' AND pid <> pg_backend_pid();

-- Drop and recreate the database
DROP DATABASE IF EXISTS airq;
CREATE DATABASE airq;

-- -------------------------------
-- 2. Create the "student group" role (replace NNN with your three-digit group number). You can choose your own password for your role or just use this simple '123' password.
-- -------------------------------
DROP ROLE IF EXISTS grp_008;
CREATE ROLE grp_008 LOGIN PASSWORD 'Sarp@sarp123';
GRANT CONNECT, CREATE ON DATABASE airq TO grp_008;

-- -------------------------------
-- 3. Lock down the default public, so that we do not accidentally create objects there
-- -------------------------------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE  ON SCHEMA public FROM PUBLIC;


