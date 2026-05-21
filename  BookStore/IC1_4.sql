--0.1. IC1.4 — Window Frames: Running Totals and Trailing Averages

WITH daily_sales AS (
	SELECT
		SUM(oi.quantity * oi.price_each) AS daily_revenue,
		DATE(o.placed_at) AS order_date
	FROM orders as o
	JOIN order_items AS oi on oi.order_id = o.id
	GROUP BY DATE(o.placed_at)
)
SELECT
	order_date,
	daily_revenue,
	SUM(daily_revenue) OVER (
    		ORDER BY order_date
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			) AS cumulative_revenue,
	AVG(daily_revenue) OVER(
		ORDER BY order_date
			ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
			) AS moving_avg_7d
FROM daily_sales
ORDER BY order_date