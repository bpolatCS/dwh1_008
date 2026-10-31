-- Question 3: Monthly Red/Crimson leaders and high-alert share trend.
WITH monthly_alerts AS (
    SELECT
        DATE_TRUNC('month', t.full_date)::DATE AS month_start,
        d.country_name,
        d.city_name,
        pa.param_id,
        pa.param_name,
        SUM(CASE WHEN pa.alert_name = 'Red' THEN fact.reading_count ELSE 0 END) AS red_exceedance_count,
        SUM(CASE WHEN pa.alert_name = 'Crimson' THEN fact.reading_count ELSE 0 END) AS crimson_exceedance_count,
        SUM(CASE WHEN pa.alert_name IN ('Red', 'Crimson') THEN fact.reading_count ELSE 0 END) AS high_alert_count,
        SUM(fact.reading_count) AS reading_count
    FROM dwh1_008.ft_reading_results AS fact
    LEFT JOIN dwh1_008.dim_timeday AS t ON t.timeday_sk = fact.timeday_sk
    LEFT JOIN dwh1_008.dim_device AS d ON d.device_sk = fact.device_sk
    LEFT JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = fact.paramalert_sk
    GROUP BY
        DATE_TRUNC('month', t.full_date)::DATE,
        d.country_name,
        d.city_name,
        pa.param_id,
        pa.param_name
),
monthly_shares AS (
    SELECT
        monthly_alerts.*,
        ROUND(100.0 * high_alert_count / NULLIF(reading_count, 0), 2) AS high_alert_share_percentage
    FROM monthly_alerts
),
trends AS (
    SELECT
        monthly_shares.*,
        LAG(high_alert_share_percentage) OVER (PARTITION BY country_name, city_name, param_id ORDER BY month_start) AS previous_month_share
    FROM monthly_shares
),
ranked_alerts AS (
    SELECT
        trends.*,
        DENSE_RANK() OVER (PARTITION BY month_start ORDER BY red_exceedance_count DESC) AS red_rank,
        DENSE_RANK() OVER (PARTITION BY month_start ORDER BY crimson_exceedance_count DESC) AS crimson_rank
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
