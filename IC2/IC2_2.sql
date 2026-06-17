CREATE TABLE stg_customer (
    customer_id BIGINT,
    email TEXT,
    country TEXT,
    segment TEXT
);


SELECT
    s.customer_id,
    s.email,
    s.country,
    s.segment
FROM stg_customer AS s
LEFT JOIN dim_customer AS d ON s.customer_id = d.customer_id AND d.is_current = TRUE
WHERE d.customer_key IS NULL;


INSERT INTO dim_customer (
    customer_id,
    email,
    country,
    segment,
    valid_from,
    valid_to,
    is_current
)
SELECT
    s.customer_id,
    s.email,
    s.country,
    s.segment,
    CURRENT_TIMESTAMP,
    NULL,
    TRUE
FROM stg_customer AS s
LEFT JOIN dim_customer AS d
    ON s.customer_id = d.customer_id
   AND d.is_current = TRUE
WHERE d.customer_key IS NULL;


SELECT
    s.customer_id,
    d.email AS old_email,
    s.email AS new_email,
    d.country AS old_country,
    s.country AS new_country,
    d.segment AS old_segment,
    s.segment AS new_segment
FROM stg_customer AS s
JOIN dim_customer AS d
    ON s.customer_id = d.customer_id
   AND d.is_current = TRUE
WHERE
	d.email IS DISTINCT FROM s.email OR
	d.country IS DISTINCT FROM s.country OR
	d.segment IS DISTINCT FROM s.segment;

