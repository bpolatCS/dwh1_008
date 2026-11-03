-- Question 1: Which cities are the leaders either in average concentration or peak concentration for each month and parameter category?

-- Calculate monthly average and peak concentrations for each city and parameter category.
WITH monthly_city_category AS (
    SELECT
        DATE_TRUNC('month', t.full_date)::DATE AS month_start,
        d.country_name,
        d.city_name,
        pa.param_category,
        SUM(f.concentration_sum) / NULLIF(SUM(f.reading_count), 0) AS average_concentration,
        MAX(f.peak_concentration) AS peak_concentration
    FROM dwh1_008.ft_reading_results AS f
    LEFT JOIN dwh1_008.dim_timeday AS t ON t.timeday_sk = f.timeday_sk
    LEFT JOIN dwh1_008.dim_device AS d ON d.device_sk = f.device_sk
    LEFT JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = f.paramalert_sk
    GROUP BY
        DATE_TRUNC('month', t.full_date)::DATE,
        d.country_name,
        d.city_name,
        pa.param_category
),
-- Rank cities by average and peak concentrations within each month and parameter category.
ranked_cities AS (
    SELECT
        monthly_city_category.*,
        DENSE_RANK() OVER (PARTITION BY month_start, param_category ORDER BY average_concentration DESC) AS average_rank,
        DENSE_RANK() OVER (PARTITION BY month_start, param_category ORDER BY peak_concentration DESC) AS peak_rank
    FROM monthly_city_category
)
-- Select the top-ranked cities for each month and parameter category based on average or peak concentration.
SELECT *
FROM ranked_cities
WHERE average_rank = 1 OR peak_rank = 1
ORDER BY month_start, param_category, country_name, city_name;
