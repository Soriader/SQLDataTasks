--Phantom Read

--session A
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
  AND amount >= 100;

--session B

BEGIN;

INSERT INTO isolation_lab.isolation_orders (
    customer_name,
    amount,
    status
)
VALUES
    ('Kacper', 150.00, 'PAID');

COMMIT;

--session A

SELECT COUNT(*) AS paid_big_orders
FROM isolation_lab.isolation_orders
WHERE status = 'PAID'
  AND amount >= 100;

COMMIT;