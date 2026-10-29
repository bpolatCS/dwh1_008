-- Load shared device dimension, including flattened geographic hierarchy.
TRUNCATE TABLE dim_device RESTART IDENTITY CASCADE;

INSERT INTO dim_device (
    device_src_id, sensor_type_name, manufacturer, technology,
    location_name, location_type, city_name, country_name,
    altitude, installed_at
)
SELECT d.id, st.typename, st.manufacturer, st.technology,
       d.locationname, d.locationtype, c.cityname, co.countryname,
       d.altitude, d.installedat
FROM tb_sensordevice AS d
JOIN tb_sensortype AS st ON st.id = d.sensortypeid
JOIN tb_city AS c ON c.id = d.cityid
JOIN tb_country AS co ON co.id = c.countryid
ORDER BY d.id;
