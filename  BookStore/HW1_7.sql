--test table

DROP TABLE IF EXISTS window_frame_test;

CREATE TABLE window_frame_test (
    id INT PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL,
    amount NUMERIC(10,2) NOT NULL
);

INSERT INTO window_frame_test (id, event_time, amount) VALUES
(1, '2024-01-01 10:00:00+01', 10.00),
(2, '2024-01-01 10:00:00+01', 20.00),
(3, '2024-01-01 10:05:00+01', 30.00),
(4, '2024-01-01 10:10:00+01', 40.00),
(5, '2024-01-01 10:10:00+01', 50.00),
(6, '2024-01-01 10:15:00+01', 60.00);


SELECT
	id,
	event_time,
	amount,
	SUM(amount) OVER(ORDER BY event_time

	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

	) AS running_sum_rows,

	SUM(amount) OVER(ORDER BY event_time

	RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	) AS running_sum_range
FROM window_frame_test
ORDER BY event_time, id;

--conclusions:
--ROWS = frame calculated by the number of physical rows.
--RANGE = frame calculated by the ORDER BY value; for duplicates, includes all rows with the same ORDER BY value.

--If you have duplicates in ORDER BY and want the result to grow exactly row by row,
--use ROWS or add a stable tie-breaker, e.g. ORDER BY event_time, id.