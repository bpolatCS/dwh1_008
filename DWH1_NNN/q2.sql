-- Question 2: Compare concentration and exceedance rates across rainy/dry and calm/windy days.
WITH weather_comparison AS (
    SELECT
        'Rain' AS weather_factor,
        fact.rain_condition AS weather_condition,
        d.country_name,
        d.city_name,
        pa.param_category,
        SUM(fact.concentration_sum) / NULLIF(SUM(fact.reading_count), 0) AS average_concentration,
        SUM(CASE WHEN pa.alert_level > 0 THEN fact.reading_count ELSE 0 END) AS exceedance_count,
        SUM(fact.reading_count) AS reading_count
    FROM dwh1_008.ft_reading_results AS fact
    LEFT JOIN dwh1_008.dim_device AS d ON d.device_sk = fact.device_sk
    LEFT JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = fact.paramalert_sk
    WHERE fact.rain_condition IN ('Rainy', 'Dry')
    GROUP BY
        fact.rain_condition,
        d.country_name,
        d.city_name,
        pa.param_category

    UNION ALL

    SELECT
        'Wind' AS weather_factor,
        fact.wind_condition AS weather_condition,
        d.country_name,
        d.city_name,
        pa.param_category,
        SUM(fact.concentration_sum) / NULLIF(SUM(fact.reading_count), 0) AS average_concentration,
        SUM(CASE WHEN pa.alert_level > 0 THEN fact.reading_count ELSE 0 END) AS exceedance_count,
        SUM(fact.reading_count) AS reading_count
    FROM dwh1_008.ft_reading_results AS fact
    LEFT JOIN dwh1_008.dim_device AS d ON d.device_sk = fact.device_sk
    LEFT JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = fact.paramalert_sk
    WHERE fact.wind_condition IN ('Calm', 'Windy')
    GROUP BY
        fact.wind_condition,
        d.country_name,
        d.city_name,
        pa.param_category
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
    ROUND(100.0 * exceedance_count / NULLIF(reading_count, 0), 2) AS exceedance_percentage
FROM weather_comparison
ORDER BY weather_factor, country_name, city_name, param_category, weather_condition;
