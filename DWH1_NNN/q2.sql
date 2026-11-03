-- Question 2: In which countries are the readings of each health effect most often in a severe (Red/Crimson) alert, and how are they distributed across all alert types?
SELECT
    e.effect_name,
    d.country_name,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_name = 'No alert'), 0) / SUM(f.reading_count), 2) AS no_alert_pct,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_name = 'Yellow'), 0)   / SUM(f.reading_count), 2) AS yellow_pct,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_name = 'Orange'), 0)   / SUM(f.reading_count), 2) AS orange_pct,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_name = 'Red'), 0)      / SUM(f.reading_count), 2) AS red_pct,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_name = 'Crimson'), 0)  / SUM(f.reading_count), 2) AS crimson_pct,
    ROUND(100.0 * COALESCE(SUM(f.reading_count) FILTER (WHERE pa.alert_level >= 3), 0)        / SUM(f.reading_count), 2) AS severe_share_pct
FROM dwh1_008.ft_reading_results AS f
JOIN dwh1_008.dim_health_effect AS he ON he.healtheffect_sk = f.healtheffect_sk
JOIN dwh1_008.dim_paramalert AS pa ON pa.paramalert_sk = f.paramalert_sk
JOIN dwh1_008.dim_device AS d ON d.device_sk = f.device_sk
CROSS JOIN LATERAL (VALUES
    ('Respiratory',    he.is_respiratory),
    ('Cardiovascular', he.is_cardiovascular),
    ('Cancer risk',    he.is_cancer_risk),
    ('Neurological',   he.is_neurological),
    ('Allergic',       he.is_allergic),
    ('Eye irritation', he.is_eye_irritation)
) AS e(effect_name, has_effect)
WHERE e.has_effect
GROUP BY e.effect_name, d.country_name
ORDER BY e.effect_name, severe_share_pct DESC, d.country_name;