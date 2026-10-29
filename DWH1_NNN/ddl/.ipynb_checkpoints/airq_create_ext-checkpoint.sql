-- DWH1 staging extension DDL
-- Define the two student-created OLTP extension tables in the active staging schema.
-- The orchestrator supplies the correct search_path before this file is executed.

-- Please remember to give meaningful names to both Table X and Table Y.

-- -------------------------------
-- 1) DROP TABLE before attempting to create OLTP snapshot tables
-- -------------------------------
DROP TABLE IF EXISTS tb_y;
DROP TABLE IF EXISTS tb_x;

-- give a meaningful name and create Table X
CREATE TABLE tb_x (
    id INT NOT NULL PRIMARY KEY
    -- the other columns here
);

-- give a meaningful name and create Table Y
CREATE TABLE tb_y (
    id INT NOT NULL PRIMARY KEY
    -- the other columns here
	-- remember to implement foreign keys correctly
);
