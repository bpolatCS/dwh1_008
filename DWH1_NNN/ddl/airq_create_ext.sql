-- DWH1 staging extension DDL
-- Define the two student-created OLTP extension tables in the active staging schema.
-- The orchestrator supplies the correct search_path before this file is executed.

-- Please remember to give meaningful names to both Table X and Table Y.

-- -------------------------------
-- 1) DROP TABLE before attempting to create OLTP snapshot tables
-- -------------------------------
DROP TABLE IF EXISTS tb_paramhealtheffect;
DROP TABLE IF EXISTS tb_healtheffect;

-- Table X: health effect categories caused by air pollutants
CREATE TABLE tb_healtheffect (
    id INT NOT NULL PRIMARY KEY,
    effectname VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL,
    CONSTRAINT uc_healtheffect_effectname UNIQUE (effectname)
);

-- Table Y: bridge tb_param <-> tb_healtheffect (M:N)
CREATE TABLE tb_paramhealtheffect (
    id INT NOT NULL PRIMARY KEY,
    paramid INT NOT NULL,
    effectid INT NOT NULL,
    CONSTRAINT fk_paramhealtheffect_paramid FOREIGN KEY (paramid) REFERENCES tb_param(id),
    CONSTRAINT fk_paramhealtheffect_effectid FOREIGN KEY (effectid) REFERENCES tb_healtheffect(id),
    CONSTRAINT uc_param_healtheffect UNIQUE (paramid, effectid)
);





