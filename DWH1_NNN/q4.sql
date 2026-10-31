-- Question 4: Data quality by parameter, manufacturer, technology, and stated accuracy.
WITH sensor_quality AS (
    SELECT
        pa.param_id,
        pa.param_name,
        d.manufacturer,
        d.technology,
        fact.sensor_accuracy,
        SUM(fact.data_quality_sum) AS data_quality_sum,
        SUM(fact.reading_count) AS reading_count,
        SUM(fact.data_quality_sum)::NUMERIC / NULLIF(SUM(fact.reading_count), 0) AS average_data_quality
    FROM dwh1_008.ft_reading_results AS fact
    LEFT JOIN dwh1_008.dim_device AS d ON d.device_sk = fact.device_sk
    LEFT JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = fact.paramalert_sk
    GROUP BY
        pa.param_id,
        pa.param_name,
        d.manufacturer,
        d.technology,
        fact.sensor_accuracy
),
accuracy_comparison AS (
    SELECT
        param_id,
        param_name,
        SUM(data_quality_sum) FILTER (WHERE sensor_accuracy = 'High')::NUMERIC / NULLIF(SUM(reading_count) FILTER (WHERE sensor_accuracy = 'High'), 0) AS high_accuracy_average,
        SUM(data_quality_sum) FILTER (WHERE sensor_accuracy <> 'High')::NUMERIC / NULLIF(SUM(reading_count) FILTER (WHERE sensor_accuracy <> 'High'), 0) AS other_accuracy_average
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
    ROUND(accuracy_comparison.high_accuracy_average - accuracy_comparison.other_accuracy_average, 3) AS high_vs_other_difference,
    CASE
        WHEN accuracy_comparison.high_accuracy_average IS NULL
          OR accuracy_comparison.other_accuracy_average IS NULL THEN 'Insufficient comparison data'
        WHEN accuracy_comparison.high_accuracy_average > accuracy_comparison.other_accuracy_average THEN 'High accuracy scores better'
        WHEN accuracy_comparison.high_accuracy_average < accuracy_comparison.other_accuracy_average THEN 'High accuracy scores worse'
        ELSE 'Equal average scores'
    END AS accuracy_comparison_result
FROM sensor_quality
LEFT JOIN accuracy_comparison ON accuracy_comparison.param_id = sensor_quality.param_id AND accuracy_comparison.param_name = sensor_quality.param_name
ORDER BY sensor_quality.param_name, sensor_quality.manufacturer, sensor_quality.technology;
