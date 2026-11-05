-- DWH1 ETL: load ft_reading_results
-- The orchestrator supplies the warehouse/staging search_path for this transaction.

-- Step 1: Truncate target table
TRUNCATE TABLE ft_reading_results RESTART IDENTITY;

-- Step 2: Insert from source
INSERT INTO ft_reading_results (
    timeday_sk,
    device_sk,
    paramalert_sk,
    healtheffect_sk,
    weather_sk,
    reading_count,
    concentration_sum,
    peak_concentration,
    data_quality_sum,
    data_volume_kb_sum
)
WITH parameter_effect_profile AS (
    SELECT
        p.id AS param_id,
        COALESCE(STRING_AGG(effect.effectname, ', ' ORDER BY effect.effectname), 'No known effect') AS effect_profile
    FROM tb_param AS p
    LEFT JOIN tb_paramhealtheffect AS parameter_effect ON parameter_effect.paramid = p.id
    LEFT JOIN tb_healtheffect AS effect ON effect.id = parameter_effect.effectid
    GROUP BY p.id
), 

weather_condition AS (
    SELECT
        cityid,
        observedat,
        CASE
            WHEN precipmm IS NULL THEN 'Unknown'
            WHEN precipmm > 0 THEN 'Rainy'
            ELSE 'Dry'
        END AS rain_condition,
        CASE
            WHEN windspeed IS NULL THEN 'Unknown'
            WHEN windspeed <= 10 THEN 'Calm'
            ELSE 'Windy'
        END AS wind_condition
    FROM tb_weather
),

reading_detail AS (
    SELECT
        t.timeday_sk,
        d.device_sk,
        pa.paramalert_sk,
        he.healtheffect_sk,
        dw.weather_sk,
        re.recordedvalue,
        re.dataquality,
        re.datavolumekb
    FROM tb_readingevent re
    LEFT JOIN tb_sensordevice sd ON sd.id = re.sensordevid
    LEFT JOIN dim_device d ON d.device_id = sd.id
    LEFT JOIN dim_timeday t ON t.full_date = re.readat
    LEFT JOIN dim_paramalert pa ON pa.param_id = re.paramid AND re.recordedvalue >= pa.threshold_from AND (pa.threshold_to IS NULL OR re.recordedvalue < pa.threshold_to)
    LEFT JOIN parameter_effect_profile pep ON pep.param_id = re.paramid
    LEFT JOIN dim_health_effect he ON he.effect_profile = pep.effect_profile
    LEFT JOIN weather_condition wc ON wc.cityid = sd.cityid AND wc.observedat = re.readat
    LEFT JOIN dim_weather dw ON dw.rain_condition = wc.rain_condition AND dw.wind_condition = wc.wind_condition
)
SELECT
    timeday_sk,
    device_sk,
    paramalert_sk,
    healtheffect_sk,
    weather_sk,
    COUNT(*) AS reading_count,
    SUM(recordedvalue) AS concentration_sum,
    MAX(recordedvalue) AS peak_concentration,
    SUM(dataquality) AS data_quality_sum,
    SUM(datavolumekb) AS data_volume_kb_sum
FROM reading_detail
GROUP BY timeday_sk, device_sk, paramalert_sk, healtheffect_sk, weather_sk;
