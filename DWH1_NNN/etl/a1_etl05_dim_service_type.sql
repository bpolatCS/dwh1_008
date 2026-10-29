-- Load service types and their category -> group -> type hierarchy.
TRUNCATE TABLE dim_service_type RESTART IDENTITY CASCADE;

INSERT INTO dim_service_type (
    servicetype_src_id, 
    service_name, 
    service_category, 
    service_group,
    minimum_qualification, 
    service_details
)
SELECT 
    id, 
    typename, 
    category, 
    servicegroup, 
    minlevel, 
    details
FROM tb_servicetype
ORDER BY id;
