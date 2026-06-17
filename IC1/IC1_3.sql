--Top 3 most expensive orders per customer.

WITH ranked_orders AS (

SELECT
	c.id AS customer_id,
	c.email,
	o.id AS order_id,
	o.placed_at,
	SUM(oi.quantity * oi.price_each) AS order_price,
		ROW_NUMBER() OVER(
		PARTITION BY c.id
		ORDER BY SUM(oi.quantity * oi.price_each) DESC
	) AS order_rank
FROM orders AS o
JOIN order_items AS oi on oi.order_id = o.id
JOIN customers AS c on c.id = o.customer_id
GROUP BY c.id, o.id, c.email, o.placed_at

)
SELECT *
FROM ranked_orders
WHERE order_rank <= 3;