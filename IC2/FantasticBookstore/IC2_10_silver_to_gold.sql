--initial load z Silver do Gold

INSERT INTO gold.dim_customer (
    customer_id,
    full_name,
    email,
    country,
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
    s.segment,
    COALESCE(s.updated_at, s.created_at, s.loaded_at) AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current,
    s.source_lsn,
    NOW() AS loaded_at
FROM silver.customers AS s
LEFT JOIN gold.dim_customer AS d
    ON s.customer_id = d.customer_id
   AND d.is_current = TRUE
WHERE d.customer_key IS NULL
  AND s.is_deleted = FALSE;


INSERT INTO gold.dim_book (
    book_id,
    author_id,
    title,
    isbn,
    genre,
    publisher,
    author_name,
    author_country,
    published_at,
    list_price,
    source_lsn,
    loaded_at,
    is_deleted,
    deleted_at
)
SELECT
    b.book_id,
    b.author_id,
    b.title,
    b.isbn,
    b.genre,
    b.publisher,
    a.author_name,
    a.author_country,
    b.published_at,
    b.price AS list_price,
    b.source_lsn,
    NOW() AS loaded_at,
    FALSE AS is_deleted,
    NULL AS deleted_at
FROM silver.books AS b
JOIN silver.authors AS a
    ON b.author_id = a.author_id
WHERE b.is_deleted = FALSE
  AND a.is_deleted = FALSE
ON CONFLICT DO NOTHING;

INSERT INTO gold.fact_order_line (
    order_item_id,
    order_id,
    customer_key,
    book_key,
    date_key,
    order_status,
    quantity,
    price_each,
    placed_at,
    source_order_lsn,
    source_order_item_lsn,
    loaded_at
)
SELECT
    oi.order_item_id,
    o.order_id,
    dc.customer_key,
    db.book_key,
    TO_CHAR(o.placed_at::DATE, 'YYYYMMDD')::INT AS date_key,
    o.order_status,
    oi.quantity,
    oi.price_each,
    o.placed_at,
    o.source_lsn AS source_order_lsn,
    oi.source_lsn AS source_order_item_lsn,
    NOW() AS loaded_at
FROM silver.order_items AS oi
JOIN silver.orders AS o
    ON oi.order_id = o.order_id
JOIN gold.dim_customer AS dc
    ON o.customer_id = dc.customer_id
   AND dc.is_current = TRUE
JOIN gold.dim_book AS db
    ON oi.book_id = db.book_id
   AND db.is_deleted = FALSE
JOIN gold.dim_date AS dd
    ON TO_CHAR(o.placed_at::DATE, 'YYYYMMDD')::INT = dd.date_key
WHERE oi.is_deleted = FALSE
  AND o.is_deleted = FALSE
ON CONFLICT DO NOTHING;

--test
--Revenue per species
SELECT
    db.genre,
    SUM(f.line_total) AS revenue,
    SUM(f.quantity) AS sold_units,
    COUNT(*) AS order_lines
FROM gold.fact_order_line AS f
JOIN gold.dim_book AS db
    ON f.book_key = db.book_key
WHERE f.order_status IN ('PAID', 'SHIPPED')
GROUP BY db.genre
ORDER BY revenue DESC;

--Revenue per client
SELECT
    dc.full_name,
    dc.segment,
    SUM(f.line_total) AS revenue,
    SUM(f.quantity) AS sold_units
FROM gold.fact_order_line AS f
JOIN gold.dim_customer AS dc
    ON f.customer_key = dc.customer_key
WHERE f.order_status IN ('PAID', 'SHIPPED')
GROUP BY dc.full_name, dc.segment
ORDER BY revenue DESC;

--Revenue per day

SELECT
    dd.full_date,
    dd.day_name,
    SUM(f.line_total) AS revenue,
    COUNT(DISTINCT f.order_id) AS orders_count
FROM gold.fact_order_line AS f
JOIN gold.dim_date AS dd
    ON f.date_key = dd.date_key
WHERE f.order_status IN ('PAID', 'SHIPPED')
GROUP BY dd.full_date, dd.day_name
ORDER BY dd.full_date;