-- Question 3: How did the monthly share of severe (Orange/Red/Crimson) alert readings in Turkey change between 2024 and 2025 for Istanbul vs. Ankara?
WITH monthly AS (
    SELECT
        CASE WHEN d.city_name = 'Istanbul' THEN 'Istanbul' ELSE 'Ankara' END AS city_group,
        pa.param_category,
        t.month_number,
        SUM(CASE WHEN t.year_number = 2024 THEN f.reading_count ELSE 0 END) AS readings_2024,
        SUM(CASE WHEN t.year_number = 2025 THEN f.reading_count ELSE 0 END) AS readings_2025,
        SUM(CASE WHEN t.year_number = 2024 AND pa.alert_level >= 2 THEN f.reading_count ELSE 0 END) AS severe_2024,
        SUM(CASE WHEN t.year_number = 2025 AND pa.alert_level >= 2 THEN f.reading_count ELSE 0 END) AS severe_2025
    FROM dwh1_008.ft_reading_results AS f
    JOIN dwh1_008.dim_timemonth AS t ON t.month_sk = f.month_sk
    JOIN dwh1_008.dim_device AS d ON d.device_sk = f.device_sk
    JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = f.paramalert_sk
    WHERE d.country_name = 'Turkey'
    GROUP BY
        CASE WHEN d.city_name = 'Istanbul' THEN 'Istanbul' ELSE 'Ankara' END,
        pa.param_category,
        t.month_number
)
SELECT
    city_group,
    param_category,
    month_number,
    readings_2024,
    readings_2025,
    ROUND(100.0 * severe_2024 / NULLIF(readings_2024, 0), 2) AS severe_pct_2024,
    ROUND(100.0 * severe_2025 / NULLIF(readings_2025, 0), 2) AS severe_pct_2025,
    ROUND(100.0 * severe_2025 / NULLIF(readings_2025, 0) - 100.0 * severe_2024 / NULLIF(readings_2024, 0), 2) AS change_pp
FROM monthly
ORDER BY city_group, param_category, month_number;