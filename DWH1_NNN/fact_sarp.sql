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
DROP TABLE IF EXISTS ft_airquality_summary;
DROP TABLE IF EXISTS ft_name1;

CREATE TABLE ft_airquality_summary (
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
    CONSTRAINT pk_ft_airquality_summary
        PRIMARY KEY (timeday_sk, device_sk, paramalert_sk, healtheffect_sk),
    CONSTRAINT fk_ft_airquality_summary_timeday
        FOREIGN KEY (timeday_sk) REFERENCES dim_timeday(timeday_sk),
    CONSTRAINT fk_ft_airquality_summary_device
        FOREIGN KEY (device_sk) REFERENCES dim_device(device_sk),
    CONSTRAINT fk_ft_airquality_summary_paramalert
        FOREIGN KEY (paramalert_sk) REFERENCES dim_paramalert(paramalert_sk),
    CONSTRAINT fk_ft_airquality_summary_health_effect
        FOREIGN KEY (healtheffect_sk) REFERENCES dim_health_effect(healtheffect_sk),
    CONSTRAINT ck_ft_airquality_summary_accuracy
        CHECK (sensor_accuracy IN ('High', 'Medium', 'Low')),
    CONSTRAINT ck_ft_airquality_summary_rain
        CHECK (rain_condition IN ('Rainy', 'Dry', 'Unknown')),
    CONSTRAINT ck_ft_airquality_summary_wind
        CHECK (wind_condition IN ('Calm', 'Windy', 'Unknown')),
    CONSTRAINT ck_ft_airquality_summary_quality_sum
        CHECK (data_quality_sum BETWEEN reading_count AND reading_count * 5),
    CONSTRAINT ck_ft_airquality_summary_volume
        CHECK (data_volume_kb_sum >= 0)
);

-- ETL: aggregate source readings at the declared grain.
INSERT INTO ft_airquality_summary (
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
), reading_detail AS (
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

-- Question 1: Monthly average and peak concentration leaders by category and city.
WITH monthly_city_category AS (
    SELECT
        DATE_TRUNC('month', time_dim.full_date)::DATE AS month_start,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category,
        SUM(fact.concentration_sum)
            / NULLIF(SUM(fact.reading_count), 0) AS average_concentration,
        MAX(fact.peak_concentration) AS peak_concentration
    FROM ft_airquality_summary AS fact
    JOIN dim_timeday AS time_dim
        ON time_dim.timeday_sk = fact.timeday_sk
    JOIN dim_device AS device_dim
        ON device_dim.device_sk = fact.device_sk
    JOIN dim_paramalert AS alert_dim
        ON alert_dim.paramalert_sk = fact.paramalert_sk
    GROUP BY
        DATE_TRUNC('month', time_dim.full_date)::DATE,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category
), ranked_cities AS (
    SELECT
        monthly_city_category.*,
        DENSE_RANK() OVER (
            PARTITION BY month_start, param_category
            ORDER BY average_concentration DESC
        ) AS average_rank,
        DENSE_RANK() OVER (
            PARTITION BY month_start, param_category
            ORDER BY peak_concentration DESC
        ) AS peak_rank
    FROM monthly_city_category
)
SELECT *
FROM ranked_cities
WHERE average_rank = 1 OR peak_rank = 1
ORDER BY month_start, param_category, country_name, city_name;

-- Question 2: Compare concentration and exceedance rates across rainy/dry and calm/windy days.
WITH weather_comparison AS (
    SELECT
        'Rain' AS weather_factor,
        fact.rain_condition AS weather_condition,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category,
        SUM(fact.concentration_sum)
            / NULLIF(SUM(fact.reading_count), 0) AS average_concentration,
        SUM(CASE WHEN alert_dim.alert_level > 0 THEN fact.reading_count ELSE 0 END)
            AS exceedance_count,
        SUM(fact.reading_count) AS reading_count
    FROM ft_airquality_summary AS fact
    JOIN dim_device AS device_dim
        ON device_dim.device_sk = fact.device_sk
    JOIN dim_paramalert AS alert_dim
        ON alert_dim.paramalert_sk = fact.paramalert_sk
    WHERE fact.rain_condition IN ('Rainy', 'Dry')
    GROUP BY
        fact.rain_condition,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category

    UNION ALL

    SELECT
        'Wind' AS weather_factor,
        fact.wind_condition AS weather_condition,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category,
        SUM(fact.concentration_sum)
            / NULLIF(SUM(fact.reading_count), 0) AS average_concentration,
        SUM(CASE WHEN alert_dim.alert_level > 0 THEN fact.reading_count ELSE 0 END)
            AS exceedance_count,
        SUM(fact.reading_count) AS reading_count
    FROM ft_airquality_summary AS fact
    JOIN dim_device AS device_dim
        ON device_dim.device_sk = fact.device_sk
    JOIN dim_paramalert AS alert_dim
        ON alert_dim.paramalert_sk = fact.paramalert_sk
    WHERE fact.wind_condition IN ('Calm', 'Windy')
    GROUP BY
        fact.wind_condition,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_category
)
SELECT
    weather_factor,
    weather_condition,
    country_name,
    city_name,
    param_category,
    average_concentration,
    exceedance_count,
    reading_count,
    ROUND(100.0 * exceedance_count / NULLIF(reading_count, 0), 2)
        AS exceedance_percentage
FROM weather_comparison
ORDER BY weather_factor, country_name, city_name, param_category, weather_condition;

-- Question 3: Monthly Red/Crimson leaders and high-alert share trend.
WITH monthly_alerts AS (
    SELECT
        DATE_TRUNC('month', time_dim.full_date)::DATE AS month_start,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_id,
        alert_dim.param_name,
        SUM(CASE WHEN alert_dim.alert_name = 'Red' THEN fact.reading_count ELSE 0 END)
            AS red_exceedance_count,
        SUM(CASE WHEN alert_dim.alert_name = 'Crimson' THEN fact.reading_count ELSE 0 END)
            AS crimson_exceedance_count,
        SUM(CASE WHEN alert_dim.alert_name IN ('Red', 'Crimson')
            THEN fact.reading_count ELSE 0 END) AS high_alert_count,
        SUM(fact.reading_count) AS reading_count
    FROM ft_airquality_summary AS fact
    JOIN dim_timeday AS time_dim
        ON time_dim.timeday_sk = fact.timeday_sk
    JOIN dim_device AS device_dim
        ON device_dim.device_sk = fact.device_sk
    JOIN dim_paramalert AS alert_dim
        ON alert_dim.paramalert_sk = fact.paramalert_sk
    GROUP BY
        DATE_TRUNC('month', time_dim.full_date)::DATE,
        device_dim.country_name,
        device_dim.city_name,
        alert_dim.param_id,
        alert_dim.param_name
), monthly_shares AS (
    SELECT
        monthly_alerts.*,
        ROUND(100.0 * high_alert_count / NULLIF(reading_count, 0), 2)
            AS high_alert_share_percentage
    FROM monthly_alerts
), trends AS (
    SELECT
        monthly_shares.*,
        LAG(high_alert_share_percentage) OVER (
            PARTITION BY country_name, city_name, param_id
            ORDER BY month_start
        ) AS previous_month_share
    FROM monthly_shares
), ranked_alerts AS (
    SELECT
        trends.*,
        DENSE_RANK() OVER (
            PARTITION BY month_start
            ORDER BY red_exceedance_count DESC
        ) AS red_rank,
        DENSE_RANK() OVER (
            PARTITION BY month_start
            ORDER BY crimson_exceedance_count DESC
        ) AS crimson_rank
    FROM trends
)
SELECT
    month_start,
    country_name,
    city_name,
    param_id,
    param_name,
    red_exceedance_count,
    crimson_exceedance_count,
    high_alert_share_percentage,
    previous_month_share,
    high_alert_share_percentage - previous_month_share AS share_change,
    CASE
        WHEN previous_month_share IS NULL THEN 'No previous month'
        WHEN high_alert_share_percentage > previous_month_share THEN 'Increasing'
        WHEN high_alert_share_percentage < previous_month_share THEN 'Decreasing'
        ELSE 'Unchanged'
    END AS share_trend,
    red_rank,
    crimson_rank
FROM ranked_alerts
ORDER BY month_start, red_rank, crimson_rank, country_name, city_name, param_name;

-- Question 4: Data quality by parameter, manufacturer, technology, and stated accuracy.
WITH sensor_quality AS (
    SELECT
        alert_dim.param_id,
        alert_dim.param_name,
        device_dim.manufacturer,
        device_dim.technology,
        fact.sensor_accuracy,
        SUM(fact.data_quality_sum) AS data_quality_sum,
        SUM(fact.reading_count) AS reading_count,
        SUM(fact.data_quality_sum)::NUMERIC
            / NULLIF(SUM(fact.reading_count), 0) AS average_data_quality
    FROM ft_airquality_summary AS fact
    JOIN dim_device AS device_dim
        ON device_dim.device_sk = fact.device_sk
    JOIN dim_paramalert AS alert_dim
        ON alert_dim.paramalert_sk = fact.paramalert_sk
    GROUP BY
        alert_dim.param_id,
        alert_dim.param_name,
        device_dim.manufacturer,
        device_dim.technology,
        fact.sensor_accuracy
), accuracy_comparison AS (
    SELECT
        param_id,
        param_name,
        SUM(data_quality_sum) FILTER (WHERE sensor_accuracy = 'High')::NUMERIC
            / NULLIF(SUM(reading_count) FILTER (WHERE sensor_accuracy = 'High'), 0)
            AS high_accuracy_average,
        SUM(data_quality_sum) FILTER (WHERE sensor_accuracy <> 'High')::NUMERIC
            / NULLIF(SUM(reading_count) FILTER (WHERE sensor_accuracy <> 'High'), 0)
            AS other_accuracy_average
    FROM sensor_quality
    GROUP BY param_id, param_name
)
SELECT
    sensor_quality.param_id,
    sensor_quality.param_name,
    sensor_quality.manufacturer,
    sensor_quality.technology,
    sensor_quality.sensor_accuracy,
    sensor_quality.reading_count,
    ROUND(sensor_quality.average_data_quality, 3) AS average_data_quality,
    ROUND(accuracy_comparison.high_accuracy_average, 3) AS high_accuracy_average,
    ROUND(accuracy_comparison.other_accuracy_average, 3) AS other_accuracy_average,
    ROUND(
        accuracy_comparison.high_accuracy_average
        - accuracy_comparison.other_accuracy_average,
        3
    ) AS high_vs_other_difference,
    CASE
        WHEN accuracy_comparison.high_accuracy_average IS NULL
          OR accuracy_comparison.other_accuracy_average IS NULL THEN 'Insufficient comparison data'
        WHEN accuracy_comparison.high_accuracy_average
            > accuracy_comparison.other_accuracy_average THEN 'High accuracy scores better'
        WHEN accuracy_comparison.high_accuracy_average
            < accuracy_comparison.other_accuracy_average THEN 'High accuracy scores worse'
        ELSE 'Equal average scores'
    END AS accuracy_comparison_result
FROM sensor_quality
JOIN accuracy_comparison
    ON accuracy_comparison.param_id = sensor_quality.param_id
   AND accuracy_comparison.param_name = sensor_quality.param_name
ORDER BY sensor_quality.param_name, sensor_quality.manufacturer, sensor_quality.technology;
