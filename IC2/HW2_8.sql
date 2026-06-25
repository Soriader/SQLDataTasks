--1) Dirty read
--Dirty read is impossible to do. PostgreSQL behaves practically like READ COMMITTED anyway.
--I can show an attempted dirty read, but the result will still be: dirty read not possible in PostgreSQL.

--created new schema for training

CREATE SCHEMA IF NOT EXISTS isolation_lab;

DROP TABLE IF EXISTS isolation_lab.isolation_orders;

CREATE TABLE isolation_lab.isolation_orders (
    id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL
);

INSERT INTO isolation_lab.isolation_orders (
    customer_name,
    amount,
    status
)
VALUES
    ('Anna', 100.00, 'PAID'),
    ('Jan', 200.00, 'PAID'),
    ('Maria', 50.00, 'PENDING');

--2) Non-repeatable read

--A

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT amount
FROM isolation_lab.isolation_orders
WHERE id = 1;

--B

BEGIN;

UPDATE isolation_lab.isolation_orders
SET amount = 150.00
WHERE id = 1;

COMMIT;

--A

SELECT amount
FROM isolation_lab.isolation_orders
WHERE id = 1;

COMMIT;

--RESULT:
--Non-repeatable read was reproduced under READ COMMITTED.
--The same transaction read the same row twice and received different values.

--3) Phantom read

--A

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*) AS paid_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID';

--B

BEGIN;

INSERT INTO isolation_lab.isolation_orders (
    customer_name,
    amount,
    status
)
VALUES (
    'Phantom Customer',
    300.00,
    'PAID'
);

COMMIT;

--A

SELECT COUNT(*) AS paid_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID';

COMMIT;

--RESULT:
--Phantom read was reproduced under READ COMMITTED.
--The same predicate returned a different set of rows after another transaction inserted a matching row.

--4) Serialization failure

--A
BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT amount
FROM isolation_lab.isolation_orders
WHERE id = 1;

--B

BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

UPDATE isolation_lab.isolation_orders
SET amount = amount + 10
WHERE id = 1;

COMMIT;

--A

UPDATE isolation_lab.isolation_orders
SET amount = amount + 20
WHERE id = 1;

COMMIT;

--PostgreSQL show me error ERROR: could not serialize access due to concurrent update

--RESULT:
--Serialization failure was reproduced under SERIALIZABLE.
--PostgreSQL rejected one transaction
--because another concurrent transaction changed the same data in a way that made serial execution impossible.


