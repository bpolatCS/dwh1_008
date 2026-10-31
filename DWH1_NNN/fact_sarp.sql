-- Preview only: combined fact DDL and ETL for review.
-- Intended to replace the ft_name1 placeholder, not to add a third fact.
-- For the final pipeline, move the CREATE TABLE block to airq_create_dwh1.sql
-- and the INSERT block to an a1_etl*.sql file.
--
-- Grain: one row per day, device, parameter-specific alert band.
-- Measures are aggregated from detailed reading events; averages are derived
-- as SUM / reading_count. Peak concentration is a MAX measure.
-- The health-effect profile dimension integrates Table_X and Table_Y.
-- Weather classes: Rainy means precipitation > 0 mm; Calm means mean wind
-- speed <= 10 km/h. These are explicit analysis assumptions.

-- DDL
DROP TABLE IF EXISTS ft_reading_results;

CREATE TABLE ft_reading_results (
    timeday_sk INT NOT NULL,
    device_sk INT NOT NULL,
    paramalert_sk INT NOT NULL,
    healtheffect_sk INT NOT NULL,
    sensor_accuracy VARCHAR(10) NOT NULL,
    rain_condition VARCHAR(10) NOT NULL,
    wind_condition VARCHAR(10) NOT NULL,
    precipitation_mm DECIMAL(6,1),
    wind_speed_kmh DECIMAL(6,1),
    reading_count BIGINT NOT NULL CHECK (reading_count > 0),
    concentration_sum NUMERIC(18,4) NOT NULL,
    peak_concentration NUMERIC(10,4) NOT NULL,
    data_quality_sum BIGINT NOT NULL,
    data_volume_kb_sum BIGINT NOT NULL,
    etl_load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ft_reading_results PRIMARY KEY (timeday_sk, device_sk, paramalert_sk, healtheffect_sk),
    CONSTRAINT fk_ft_reading_results_timeday FOREIGN KEY (timeday_sk) REFERENCES dim_timeday(timeday_sk),
    CONSTRAINT fk_ft_reading_results_device FOREIGN KEY (device_sk) REFERENCES dim_device(device_sk),
    CONSTRAINT fk_ft_reading_results_paramalert FOREIGN KEY (paramalert_sk) REFERENCES dim_paramalert(paramalert_sk),
    CONSTRAINT fk_ft_reading_results_health_effect FOREIGN KEY (healtheffect_sk) REFERENCES dim_health_effect(healtheffect_sk),
    CONSTRAINT ck_ft_reading_results_accuracy CHECK (sensor_accuracy IN ('High', 'Medium', 'Low')),
    CONSTRAINT ck_ft_reading_results_rain CHECK (rain_condition IN ('Rainy', 'Dry', 'Unknown')),
    CONSTRAINT ck_ft_reading_results_wind CHECK (wind_condition IN ('Calm', 'Windy', 'Unknown')),
    CONSTRAINT ck_ft_reading_results_quality_sum CHECK (data_quality_sum BETWEEN reading_count AND reading_count * 5),
    CONSTRAINT ck_ft_reading_results_volume CHECK (data_volume_kb_sum >= 0)
);

-- ETL: aggregate source readings at the declared grain.
INSERT INTO ft_reading_results (
    timeday_sk,
    device_sk,
    paramalert_sk,
    healtheffect_sk,
    sensor_accuracy,
    rain_condition,
    wind_condition,
    precipitation_mm,
    wind_speed_kmh,
    reading_count,
    concentration_sum,
    peak_concentration,
    data_quality_sum,
    data_volume_kb_sum
)
WITH parameter_effect_profile AS (
    SELECT
        parameter.id AS param_id,
        COALESCE(STRING_AGG(effect.effectname, ', ' ORDER BY effect.effectname), 'No known effect') AS effect_profile
    FROM tb_param AS parameter
    LEFT JOIN tb_paramhealtheffect AS parameter_effect ON parameter_effect.paramid = parameter.id
    LEFT JOIN tb_healtheffect AS effect ON effect.id = parameter_effect.effectid
    GROUP BY parameter.id
),
reading_detail AS (
    SELECT
        time_dim.timeday_sk,
        device_dim.device_sk,
        alert_dim.paramalert_sk,
        health_dim.healtheffect_sk,
        capability.accuracy AS sensor_accuracy,
        CASE
            WHEN weather.precipmm IS NULL THEN 'Unknown'
            WHEN weather.precipmm > 0 THEN 'Rainy'
            ELSE 'Dry'
        END AS rain_condition,
        CASE
            WHEN weather.windspeed IS NULL THEN 'Unknown'
            WHEN weather.windspeed <= 10 THEN 'Calm'
            ELSE 'Windy'
        END AS wind_condition,
        weather.precipmm AS precipitation_mm,
        weather.windspeed AS wind_speed_kmh,
        reading.recordedvalue,
        reading.dataquality,
        reading.datavolumekb
    FROM tb_readingevent AS reading
    LEFT JOIN tb_sensordevice AS source_device ON source_device.id = reading.sensordevid
    LEFT JOIN dim_device AS device_dim ON device_dim.device_id = source_device.id
    LEFT JOIN dim_timeday AS time_dim ON time_dim.full_date = reading.readat
    LEFT JOIN tb_paramsensortype AS capability ON capability.sensortypeid = source_device.sensortypeid AND capability.paramid = reading.paramid
    LEFT JOIN dim_paramalert AS alert_dim ON alert_dim.param_id = reading.paramid AND reading.recordedvalue >= alert_dim.threshold_from AND (alert_dim.threshold_to IS NULL OR reading.recordedvalue < alert_dim.threshold_to)
    LEFT JOIN parameter_effect_profile AS effect_profile ON effect_profile.param_id = reading.paramid
    LEFT JOIN dim_health_effect AS health_dim ON health_dim.effect_profile = effect_profile.effect_profile
    LEFT JOIN tb_weather AS weather ON weather.cityid = source_device.cityid AND weather.observedat = reading.readat
)
SELECT
    timeday_sk,
    device_sk,
    paramalert_sk,
    healtheffect_sk,
    sensor_accuracy,
    rain_condition,
    wind_condition,
    precipitation_mm,
    wind_speed_kmh,
    COUNT(*)::BIGINT AS reading_count,
    SUM(recordedvalue)::NUMERIC(18,4) AS concentration_sum,
    MAX(recordedvalue)::NUMERIC(10,4) AS peak_concentration,
    SUM(dataquality)::BIGINT AS data_quality_sum,
    SUM(datavolumekb)::BIGINT AS data_volume_kb_sum
FROM reading_detail
GROUP BY
    timeday_sk,
    device_sk,
    paramalert_sk,
    healtheffect_sk,
    sensor_accuracy,
    rain_condition,
    wind_condition,
    precipitation_mm,
    wind_speed_kmh;
