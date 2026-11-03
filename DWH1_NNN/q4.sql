-- Question 4: For PM10, how do rain and altitude relate to the concentration level across countries?
WITH country_pm10 AS (
    SELECT
        d.country_name,
        SUM(f.reading_count) AS pm10_readings,
        ROUND(SUM(f.concentration_sum) / SUM(f.reading_count), 2) AS avg_pm10_all_days,
        ROUND(SUM(f.concentration_sum) FILTER (WHERE w.rain_condition = 'Rainy')
            / NULLIF(SUM(f.reading_count) FILTER (WHERE w.rain_condition = 'Rainy'), 0), 2) AS avg_pm10_rainy_days,
        ROUND(SUM(f.concentration_sum) FILTER (WHERE w.rain_condition = 'Dry')
            / NULLIF(SUM(f.reading_count) FILTER (WHERE w.rain_condition = 'Dry'), 0), 2) AS avg_pm10_dry_days,
        ROUND(100.0 * SUM(f.reading_count) FILTER (WHERE w.rain_condition = 'Rainy') / SUM(f.reading_count), 1) AS rainy_readings_pct,
        ROUND(SUM(d.altitude * f.reading_count)::NUMERIC / SUM(f.reading_count), 1) AS avg_device_altitude_m
    FROM dwh1_008.ft_reading_results AS f
    JOIN dwh1_008.dim_device AS d ON d.device_sk = f.device_sk
    JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = f.paramalert_sk
    JOIN dwh1_008.dim_weather AS w ON w.weather_sk = f.weather_sk
    WHERE pa.param_name = 'PM10'
    GROUP BY d.country_name
)
SELECT
    country_name,
    pm10_readings,
    avg_pm10_all_days,
    avg_pm10_rainy_days,
    avg_pm10_dry_days,
    ROUND(100.0 * (avg_pm10_rainy_days - avg_pm10_dry_days) / NULLIF(avg_pm10_dry_days, 0), 1) AS pm10_change_on_rainy_days_pct,
    rainy_readings_pct,
    avg_device_altitude_m
FROM country_pm10
ORDER BY avg_pm10_all_days DESC;