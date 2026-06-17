--Partial vs Full Index Test
--Compare a partial index ( WHERE status='paid' ) to a full index. Measure index size, read speed, write penalty.

--created table for test

CREATE TABLE orders_index_test (
 id BIGSERIAL PRIMARY KEY,
 placed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 status TEXT NOT NULL
);

INSERT INTO orders_index_test (placed_at, status)
SELECT
    NOW() - (random() * interval '365 days') AS placed_at,
    CASE
        WHEN r < 0.10 THEN 'paid'
        WHEN r < 0.40 THEN 'shipped'
        WHEN r < 0.70 THEN 'pending'
        WHEN r < 0.90 THEN 'cancelled'
        ELSE 'refunded'
    END AS status
FROM (
    SELECT random() AS r
    FROM generate_series(1, 100000)
) AS x;

-- Seq Scan paid

EXPLAIN ANALYZE
SELECT *
FROM orders_index_test
WHERE status = 'paid';

"Seq Scan on orders_index_test  (cost=0.00..1919.00 rows=9923 width=24) (actual time=0.018..7.044 rows=9993.00 loops=1)"
"  Filter: (status = 'paid'::text)"
"  Rows Removed by Filter: 90007"
"  Buffers: shared hit=669"
"Planning:"
"  Buffers: shared hit=12"
"Planning Time: 0.259 ms"
"Execution Time: 7.327 ms"

--Full index for paid

CREATE INDEX idx_orders_index_test_status_full
ON orders_index_test(status);

ANALYZE orders_index_test;

EXPLAIN ANALYZE
SELECT *
FROM orders_index_test
WHERE status = 'paid';

"Bitmap Heap Scan on orders_index_test  (cost=114.23..908.95 rows=10057 width=24) (actual time=0.647..2.690 rows=9993.00 loops=1)"
"  Recheck Cond: (status = 'paid'::text)"
"  Heap Blocks: exact=668"
"  Buffers: shared hit=668 read=10"
"  ->  Bitmap Index Scan on idx_orders_index_test_status_full  (cost=0.00..111.72 rows=10057 width=0) (actual time=0.551..0.551 rows=9993.00 loops=1)"
"        Index Cond: (status = 'paid'::text)"
"        Index Searches: 1"
"        Buffers: shared read=10"
"Planning:"
"  Buffers: shared hit=11 read=1"
"Planning Time: 0.253 ms"
"Execution Time: 3.022 ms"

--paid size

SELECT
    pg_size_pretty(pg_relation_size('idx_orders_index_test_status_full')) AS full_index_size;

--Result: 696 kB

--partial index for paid

DROP INDEX idx_orders_index_test_status_full;

CREATE INDEX idx_orders_index_test_status_paid_partial
ON orders_index_test(status)
WHERE status = 'paid';

ANALYZE orders_index_test;

EXPLAIN ANALYZE
SELECT *
FROM orders_index_test
WHERE status = 'paid';

"Bitmap Heap Scan on orders_index_test  (cost=96.61..890.20 rows=9967 width=24) (actual time=0.456..2.743 rows=9993.00 loops=1)"
"  Recheck Cond: (status = 'paid'::text)"
"  Heap Blocks: exact=668"
"  Buffers: shared hit=668 read=10"
"  ->  Bitmap Index Scan on idx_orders_index_test_status_paid_partial  (cost=0.00..94.12 rows=9967 width=0) (actual time=0.373..0.373 rows=9993.00 loops=1)"
"        Index Searches: 1"
"        Buffers: shared read=10"
"Planning:"
"  Buffers: shared hit=17 read=1"
"Planning Time: 1.103 ms"
"Execution Time: 3.101 ms"

-- partial index  size

--Result: 88 kB



Without index:
- plan: Seq Scan
- execution time: 7.327 ms
- index size: none

Full index:
- plan: Bitmap Index Scan + Bitmap Heap Scan
- execution time: 3.022 ms
- index size: 696 kB

Partial index:
- plan: Bitmap Index Scan + Bitmap Heap Scan
- execution time: 3.101 ms
- index size: 88 kB

The partial index for status='paid' gave a similar read time as the full index, but was about 8 times faster.
This is good when you frequently filter by paid and paid is a small part of the table.