-- =====================================================
-- IC2.6 -- Isolation Levels
-- Goal:
-- Walk through Read Uncommitted, Read Committed,
-- Repeatable Read, Serializable.
-- Show a phantom read.
-- =====================================================

-- =====================================================
-- Reset test data
-- =====================================================

TRUNCATE TABLE isolation_lab.isolation_orders RESTART IDENTITY;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Anna', 100.00, 'PAID'),
('Jan', 200.00, 'PAID'),
('Maria', 50.00, 'PENDING');

SELECT *
FROM isolation_lab.isolation_orders
ORDER BY id;

-- =====================================================
-- 1. Phantom Read with READ COMMITTED
-- =====================================================

-- Session A
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 2

-- Session B
BEGIN;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Kacper', 150.00, 'PAID');

COMMIT;

-- Session A
SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 3

COMMIT;

-- Explanation:
-- In one transaction in Session A, the first SELECT returned 2 rows,
-- but the second SELECT returned 3 rows.
-- This means that during one transaction, a new row appeared that met
-- the query condition.
-- This is a phantom read.

-- READ COMMITTED:
-- Each SELECT sees data committed before that specific SELECT starts.
-- Therefore, phantom reads are possible.

-- =====================================================
-- Reset test data before REPEATABLE READ
-- =====================================================

TRUNCATE TABLE isolation_lab.isolation_orders RESTART IDENTITY;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Anna', 100.00, 'PAID'),
('Jan', 200.00, 'PAID'),
('Maria', 50.00, 'PENDING');

-- =====================================================
-- 2. REPEATABLE READ
-- =====================================================

-- Session A
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 2

-- Session B
BEGIN;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Kacper', 150.00, 'PAID');

COMMIT;

-- Session A
SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 2

COMMIT;

-- Explanation:
-- The row inserted in Session B meets the condition:
-- status = 'PAID' AND amount >= 100.
-- However, Session A still returns 2 rows because REPEATABLE READ
-- sees the data as it appeared at the time the transaction began.

-- READ COMMITTED:
-- Each SELECT takes a new look at committed data.

-- REPEATABLE READ:
-- The entire transaction looks at one stable snapshot of data.

-- =====================================================
-- Reset test data before READ UNCOMMITTED
-- =====================================================

TRUNCATE TABLE isolation_lab.isolation_orders RESTART IDENTITY;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Anna', 100.00, 'PAID'),
('Jan', 200.00, 'PAID'),
('Maria', 50.00, 'PENDING');

-- =====================================================
-- 3. READ UNCOMMITTED
-- =====================================================

-- Session B
BEGIN;

UPDATE isolation_lab.isolation_orders
SET amount = 9999.00
WHERE customer_name = 'Anna';

-- Do not COMMIT yet.

-- Session A
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT *
FROM isolation_lab.isolation_orders
WHERE customer_name = 'Anna';

-- Result:
-- Session A still sees amount = 100.00, not 9999.00.

COMMIT;

-- Session B
ROLLBACK;

-- Explanation:
-- PostgreSQL does not allow dirty reads.
-- Even with READ UNCOMMITTED, PostgreSQL behaves like READ COMMITTED.
-- Therefore, Session A cannot see uncommitted changes from Session B.

-- =====================================================
-- Reset test data before SERIALIZABLE
-- =====================================================

TRUNCATE TABLE isolation_lab.isolation_orders RESTART IDENTITY;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Anna', 100.00, 'PAID'),
('Jan', 200.00, 'PAID'),
('Maria', 50.00, 'PENDING');

-- =====================================================
-- 4. SERIALIZABLE
-- =====================================================

-- Session A
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 2

-- Session B
BEGIN;

INSERT INTO isolation_lab.isolation_orders (
customer_name,
amount,
status
)
VALUES
('Kacper', 150.00, 'PAID');

COMMIT;

-- Session A
SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 2

COMMIT;

-- After Session A commits, run a new SELECT outside the old transaction:

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
AND amount >= 100;

-- Result: 3

-- Explanation:
-- SERIALIZABLE is the strongest isolation level.
-- In this transaction, Session A does not see the row inserted by Session B.
-- PostgreSQL behaves as if transactions were executed one after another.
-- In more complex conflicting write scenarios, PostgreSQL may abort one
-- transaction with a serialization error, and the application should retry it.

-- =====================================================
-- Summary
-- =====================================================

-- READ UNCOMMITTED:
-- PostgreSQL does not show dirty data, so it behaves like READ COMMITTED.

-- READ COMMITTED:
-- Phantom read occurred: 2 -> 3.

-- REPEATABLE READ:
-- Phantom read did not occur: 2 -> 2.

-- SERIALIZABLE:
-- Strongest isolation level.
-- Phantom read did not appear in this transaction.
-- Conflicting transactions may require retry.
--In PostgreSQL, SERIALIZABLE provides the strongest isolation. In simple read scenarios it
--behaves similarly to REPEATABLE READ by keeping a stable snapshot, but in conflicting concurrent write scenarios
--PostgreSQL may abort one transaction with a serialization error and the application should retry it.