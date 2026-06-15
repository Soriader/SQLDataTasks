--check the pg_stat_statements is available

SELECT *
FROM pg_available_extensions
WHERE name = 'pg_stat_statements';

--A
Select *
From orders_index_test
Where status = 'paid';

--B
Select *
From orders_index_test
Where status = 'shipped';

--C
SELECT *
FROM orders_index_test
Order By placed_at DESC
Limit 100;

--D
SELECT *
FROM orders_index_test
WHERE placed_at >= (
    SELECT MAX(placed_at)
    FROM orders_index_test
) - INTERVAL '30 days';
--E
SELECT *
FROM orders_index_test
WHERE status = 'paid'
order by placed_at DESC
LIMIT 100;

--F
SELECT status, COUNT(*) AS count_status
FROM orders_index_test
GROUP BY status
ORDER BY count_status DESC;

--G
SELECT
    status,
    EXTRACT(MONTH FROM placed_at) AS current_month,
    COUNT(*) AS count_status
FROM orders_index_test
GROUP BY status, EXTRACT(MONTH FROM placed_at)
ORDER BY status, current_month;

--pg_stat_statements

SELECT
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10

-- 1. Remove the partial index on paid to prevent it from mixing test results.
DROP INDEX IF EXISTS idx_orders_index_test_status_paid_partial;

- 2. Also remove any full index, if it already existed.
DROP INDEX IF EXISTS idx_orders_index_test_status_full;

- 3. Create a full index on the status column.
CREATE INDEX idx_orders_index_test_status_full
ON orders_index_test(status);

- 4. Refresh the table statistics.
ANALYZE orders_index_test;

- 5. Check the plan for status = paid.
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders_index_test
WHERE status = 'paid';

-- 6. Check the plan for status = shipped
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders_index_test
WHERE status = 'shipped';

--Top query 1: SELECT * FROM orders_index_test WHERE status = $1
--
--Problem:
--The query was executed multiple times for different statuses.
--A partial index on status='paid' only helped for paid, but for shipped,
--PostgreSQL performed a Seq Scan and discarded 70017 rows.
--
--Optimization:
--A full index was applied to the status column.
--
--Result:
--For status='shipped', the plan changed from Seq Scan to Bitmap Index Scan,
--and the execution time dropped from approximately 9.038 ms
--to approximately 6.056 ms. For status='paid', the index is also used.


