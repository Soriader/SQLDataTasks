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
) - INTERVAL '30 days'
ORDER BY placed_at DESC
LIMIT 100;
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

--Test query 1

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

--Test query 2

-- 1. Remove the partial index on paid to prevent it from mixing test results.
DROP INDEX IF EXISTS idx_orders_index_test_status_paid_partial;

- 2. Also remove any full index, if it already existed.
DROP INDEX IF EXISTS idx_orders_index_test_status_full;

- 3. Create a full index on the status column.
CREATE INDEX idx_orders_index_test_status_full
ON orders_index_test(placed_at DESC);

- 4. Refresh the table statistics.
ANALYZE orders_index_test;

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders_index_test
WHERE placed_at >= (
    SELECT MAX(placed_at)
    FROM orders_index_test
) - INTERVAL '30 days'
ORDER BY placed_at DESC
LIMIT 100;

--Problem:
--Before optimization, PostgreSQL performed a full table scan for MAX(placed_at), a
--second full scan for the date filter, and an additional sort on placed_at DESC.
--
--Optimization:
--Added an index on placed_at DESC.
--
--Result:
--The plan changed from Seq Scan + Sort to Index Only Scan + Index Scan. Execution
--time dropped from approximately 31.6 ms to approximately 0.172 ms.

--Test query 3

--first variant
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    status,
    DATE_TRUNC('month', placed_at) AS current_month,
    COUNT(*) AS count_status
FROM orders_index_test
GROUP BY status, current_month
ORDER BY status, current_month;

--second variant
EXPLAIN (ANALYZE, BUFFERS)
With monthly_counts AS (
SELECT
    status,
    DATE_TRUNC('month', placed_at) AS current_month,
    COUNT(*) AS count_status
FROM orders_index_test
GROUP BY status, current_month
)
SELECT *
FROM monthly_counts
ORDER BY status, current_month;

--third variant
EXPLAIN (ANALYZE, BUFFERS)
With monthly_counts AS MATERIALIZED (
SELECT
    status,
    DATE_TRUNC('month', placed_at) AS current_month,
    COUNT(*) AS count_status
FROM orders_index_test
GROUP BY status, current_month
)
SELECT *
FROM monthly_counts
ORDER BY status, current_month;

--Top query 3:
--Aggregating the number of orders by status and month.
--Problem:
--The original query performed a GroupAggregate followed by a 100,000-row sort.
--The sort used an external merge and temporary files, significantly increasing execution time.
--
--Optimization:
--The query was split into two stages: first, aggregation in the MATERIALIZED CTE,
--and only then sorting the final result. Additionally, EXTRACT(MONTH) was replaced with DATE_TRUNC('month')
--to avoid mixing the same months from different years.
--
--Result:
--The plan changed to a HashAggregate + a small Sort after 65 rows.
--The execution time dropped from approximately 172.7 ms to approximately 43.8 ms.