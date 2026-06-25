--Added current_segment

UPDATE gold.dim_customer AS g
SET current_segment = c.segment
FROM gold.dim_customer AS c
WHERE g.customer_id = c.customer_id
  AND c.is_current = TRUE;

--simulation for change segment PREMIUM -> BUSINESS

UPDATE silver.customers
SET
    segment = 'BUSINESS',
    updated_at = NOW(),
    loaded_at = NOW(),
    source_lsn = 'manual_scd6_test_001'
WHERE customer_id = 1;

--control select

SELECT
    s.customer_id,
    g.customer_key,
    g.segment AS old_segment,
    s.segment AS new_segment,
    g.current_segment AS old_current_segment
FROM silver.customers AS s
JOIN gold.dim_customer AS g
    ON s.customer_id = g.customer_id
WHERE g.is_current = TRUE
  AND s.is_deleted = FALSE
  AND (
        s.full_name IS DISTINCT FROM g.full_name
        OR s.email IS DISTINCT FROM g.email
        OR s.country IS DISTINCT FROM g.country
        OR s.city IS DISTINCT FROM g.city
        OR s.segment IS DISTINCT FROM g.segment
  );

--save changed clients

DROP TABLE IF EXISTS tmp_scd6_changed_customers;

CREATE TEMP TABLE tmp_scd6_changed_customers AS
SELECT
    s.customer_id,
    g.customer_key,
    g.segment AS previous_segment,
    s.segment AS new_segment,
    COALESCE(s.updated_at, s.loaded_at, NOW()) AS change_time
FROM silver.customers AS s
JOIN gold.dim_customer AS g
    ON s.customer_id = g.customer_id
WHERE g.is_current = TRUE
  AND s.is_deleted = FALSE
  AND (
        s.full_name IS DISTINCT FROM g.full_name
        OR s.email IS DISTINCT FROM g.email
        OR s.country IS DISTINCT FROM g.country
        OR s.city IS DISTINCT FROM g.city
        OR s.segment IS DISTINCT FROM g.segment
  );

--close actual (old) version SCD2
UPDATE gold.dim_customer AS g
SET
    valid_to = t.change_time,
    is_current = FALSE,
    loaded_at = NOW()
FROM tmp_scd6_changed_customers AS t
WHERE g.customer_key = t.customer_key;

--new version for client

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
    current_segment,
    previous_segment,
    valid_from,
    valid_to,
    is_current,
    source_lsn,
    loaded_at
)
SELECT
    s.customer_id,
    s.full_name,
    s.email,
    s.country,
    s.city,
    s.segment,
    s.segment AS current_segment,
    t.previous_segment,
    t.change_time AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
JOIN tmp_scd6_changed_customers AS t
    ON s.customer_id = t.customer_id;


--update current_segment in all client versions

UPDATE gold.dim_customer AS g
SET
    current_segment = t.new_segment,
    loaded_at = NOW()
FROM tmp_scd6_changed_customers AS t
WHERE g.customer_id = t.customer_id;

--check the result

SELECT
    customer_key,
    customer_id,
    segment,
    current_segment,
    previous_segment,
    valid_from,
    valid_to,
    is_current
FROM gold.dim_customer
WHERE customer_id = 1
ORDER BY valid_from;

--raprot

SELECT
    f.order_id,
    f.order_item_id,
    f.placed_at,
    c.customer_id,
    c.full_name,
    c.segment AS segment_at_time_of_order,
    c.current_segment,
    c.previous_segment,
    f.line_total
FROM gold.fact_order_line AS f
JOIN gold.dim_customer AS c
    ON f.customer_key = c.customer_key
ORDER BY
    f.placed_at,
    f.order_id,
    f.order_item_id;

-- result for this inquirie is on HW2_4_RAPORT.png
