-- test table

DROP TABLE IF EXISTS deadlock_demo;

CREATE TABLE deadlock_demo (
    id INT PRIMARY KEY,
    name TEXT,
    balance NUMERIC(10,2)
);

INSERT INTO deadlock_demo (id, name, balance) VALUES
(1, 'Account A', 1000.00),
(2, 'Account B', 1000.00);

--first lock
UPDATE deadlock_demo
SET balance = balance - 100
WHERE id = 1;

--second lock
UPDATE deadlock_demo
SET balance = balance - 200
WHERE id = 2;

--cross lock

--Session 1
UPDATE deadlock_demo
SET balance = balance - 50
WHERE id = 2;

--Session 2

UPDATE deadlock_demo
SET balance = balance - 70
WHERE id = 1;

--Situation
--Session 1 hold id=1 and wait for id=2.
--Session 2 hold id=2 and wait for id=1.

