-- DWH1 ETL: load ft_name1
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE ft_reading_results RESTART IDENTITY;

-- Step 2: Insert from source
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
        t.timeday_sk,
        d.device_sk,
        pa.paramalert_sk,
        he.healtheffect_sk,
        pst.accuracy AS sensor_accuracy,
        CASE
            WHEN w.precipmm IS NULL THEN 'Unknown'
            WHEN w.precipmm > 0 THEN 'Rainy'
            ELSE 'Dry'
        END AS rain_condition,
        CASE
            WHEN w.windspeed IS NULL THEN 'Unknown'
            WHEN w.windspeed <= 10 THEN 'Calm'
            ELSE 'Windy'
        END AS wind_condition,
        w.precipmm AS precipitation_mm,
        w.windspeed AS wind_speed_kmh,
        re.recordedvalue,
        re.dataquality,
        re.datavolumekb
    FROM tb_readingevent re
    LEFT JOIN tb_sensordevice sd ON sd.id = re.sensordevid
    LEFT JOIN dim_device d ON d.device_id = sd.id
    LEFT JOIN dim_timeday t ON t.full_date = re.readat
    LEFT JOIN tb_paramsensortype pst ON pst.sensortypeid = sd.sensortypeid AND pst.paramid = re.paramid
    LEFT JOIN dim_paramalert pa ON pa.param_id = re.paramid AND re.recordedvalue >= pa.threshold_from AND (pa.threshold_to IS NULL OR re.recordedvalue < pa.threshold_to)
    LEFT JOIN parameter_effect_profile pep ON pep.param_id = re.paramid
    LEFT JOIN dim_health_effect he ON he.effectname = pep.effect_profile
    LEFT JOIN tb_weather w ON w.cityid = sd.cityid AND w.observedat = re.readat
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
    COUNT(*) AS reading_count,
    SUM(recordedvalue) AS concentration_sum,
    MAX(recordedvalue) AS peak_concentration,
    SUM(dataquality) AS data_quality_sum,
    SUM(datavolumekb) AS data_volume_kb_sum
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
