-- Load the shared daily calendar dimension.
TRUNCATE TABLE dim_timeday RESTART IDENTITY CASCADE;

INSERT INTO dim_timeday (full_date, day_number, month_number, quarter_number, year_number)
SELECT dates.full_date,
       EXTRACT(DAY FROM dates.full_date)::INT,
       EXTRACT(MONTH FROM dates.full_date)::INT,
       EXTRACT(QUARTER FROM dates.full_date)::INT,
       EXTRACT(YEAR FROM dates.full_date)::INT
FROM (
    SELECT servicedat AS full_date FROM tb_serviceevent
    UNION
    SELECT readat AS full_date FROM tb_readingevent
) AS dates
ORDER BY dates.full_date;
