INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
    valid_from,
    valid_to,
    is_current,
    source_lsn,
    loaded_at
)
SELECT
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
    COALESCE(updated_at, loaded_at, NOW()) AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    source_lsn,
    NOW() AS loaded_at
FROM silver.customers
WHERE is_deleted = FALSE;

-- before SCD2 find a record to update a new version

UPDATE silver.customers
SET
    city = 'Warszawa',
    segment = 'PREMIUM',
    updated_at = NOW(),
    loaded_at = NOW(),
    source_lsn = 'manual_scd2_test_001'
WHERE customer_id = 1;

-- detect changed customers

SELECT
    s.customer_id,
    g.customer_key,

    g.full_name AS old_full_name,
    s.full_name AS new_full_name,

    g.email AS old_email,
    s.email AS new_email,

    g.country AS old_country,
    s.country AS new_country,

    g.city AS old_city,
    s.city AS new_city,

    g.segment AS old_segment,
    s.segment AS new_segment
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


DROP TABLE IF EXISTS tmp_changed_customers;

CREATE TEMP TABLE tmp_changed_customers AS
SELECT
    s.customer_id,
    g.customer_key,
    COALESCE(s.updated_at, NOW()) AS change_time
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

--close old gold version

UPDATE gold.dim_customer AS g
SET
    valid_to = t.change_time,
    is_current = FALSE,
    loaded_at = NOW()
FROM tmp_changed_customers AS t
WHERE g.customer_key = t.customer_key;

--2 records in gold to client where customer_id = 1

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
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
    t.change_time AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
JOIN tmp_changed_customers AS t
    ON s.customer_id = t.customer_id;

--end: existing customer changed → close old version → insert new current version

INSERT INTO silver.customers (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
    created_at,
    updated_at,
    source_raw_event_id,
    source_lsn
)
VALUES (
    6,
    'Jacek Jackowski',
    'test.customer@example.com',
    'PL',
    'Gdańsk',
    'RETAIL',
    NOW(),
    NOW(),
    999,
    'manual_scd2_test_002'
);

SELECT
    s.customer_id,
    s.full_name,
    s.email,
    s.country,
    s.city,
    s.segment
FROM silver.customers AS s
LEFT JOIN gold.dim_customer AS g
    ON s.customer_id = g.customer_id
WHERE s.is_deleted = FALSE
  AND g.customer_id IS NULL;

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
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
    COALESCE(s.updated_at, s.loaded_at, NOW()) AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
LEFT JOIN gold.dim_customer AS g
    ON s.customer_id = g.customer_id
WHERE s.is_deleted = FALSE
  AND g.customer_id IS NULL;

--end: new customer in silver → insert first version into gold

--SCD2 MERGE-equivalent

BEGIN;

DROP TABLE IF EXISTS tmp_changed_customers;

CREATE TEMP TABLE tmp_changed_customers AS
SELECT
    s.customer_id,
    g.customer_key,
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

UPDATE gold.dim_customer AS g
SET
    valid_to = t.change_time,
    is_current = FALSE,
    loaded_at = NOW()
FROM tmp_changed_customers AS t
WHERE g.customer_key = t.customer_key;

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
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
    t.change_time AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
JOIN tmp_changed_customers AS t
    ON s.customer_id = t.customer_id;

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
    city,
    segment,
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
    COALESCE(s.updated_at, s.loaded_at, NOW()) AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
LEFT JOIN gold.dim_customer AS g
    ON s.customer_id = g.customer_id
WHERE s.is_deleted = FALSE
  AND g.customer_id IS NULL;

COMMIT;


--test
SELECT
    customer_id,
    COUNT(*) AS current_versions
FROM gold.dim_customer
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;

--result: 0 records

--My implementation works because:
--
--- uses customer_id as the natural key,
--- uses customer_key as a surrogate key,
--- tracks 5 attributes: full_name, email, country, city, segment,
--- closes the old version with valid_to and is_current = false,
--- adds the new version with is_current = true,
--- handles new customers,
--- works like Postgres MERGE-equivalent via UPDATE + INSERT in a transaction.