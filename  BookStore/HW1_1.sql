--HW1.1 — Window Function Workshop

WITH customer_months AS (
	SELECT DISTINCT
    	customer_id,
    	DATE_TRUNC('month', placed_at) AS order_month
	FROM orders
),
cohorts AS (
	SELECT
		customer_id,
    	MIN(order_month) AS cohort_month
	FROM customer_months
	GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        cm.customer_id,
    	coh.cohort_month,
    	cm.order_month,
		(EXTRACT(YEAR FROM cm.order_month) - EXTRACT(YEAR FROM coh.cohort_month)) * 12
		+
		(EXTRACT(MONTH FROM cm.order_month) - EXTRACT(MONTH FROM coh.cohort_month)) AS month_number

    FROM customer_months as cm
	JOIN cohorts AS coh ON coh.customer_id = cm.customer_id
),

retention_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, month_number
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_activity
    WHERE month_number = 0
    GROUP BY cohort_month
)

SELECT
    rc.cohort_month,
    rc.month_number,
    rc.active_customers,
    cs.cohort_size,
	(rc.active_customers * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM retention_counts AS rc
JOIN cohort_size AS cs
    ON cs.cohort_month = rc.cohort_month
ORDER BY rc.cohort_month, rc.month_number;


WITH rfm_base AS (
    SELECT
        o.customer_id,
        MAX(o.placed_at) AS last_order_date,
        COUNT(DISTINCT o.id) AS frequency,
        SUM(oi.quantity * oi.price_each) AS monetary
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.customer_id
),
reference_date AS (
    SELECT
        MAX(placed_at) AS max_order_date
    FROM orders
),
rfm_metrics AS (
    SELECT
        rb.customer_id,
        rb.last_order_date,
        rd.max_order_date,
        rd.max_order_date::date - rb.last_order_date::date AS recency_days,
        rb.frequency,
        rb.monetary
    FROM rfm_base AS rb
    CROSS JOIN reference_date AS rd
)
SELECT
    customer_id,
    last_order_date,
    recency_days,
    frequency,
    monetary,

    NTILE(5) OVER (
        ORDER BY recency_days DESC
    ) AS r_score,

    NTILE(5) OVER (
        ORDER BY frequency ASC
    ) AS f_score,

    NTILE(5) OVER (
        ORDER BY monetary ASC
    ) AS m_score

FROM rfm_metrics
ORDER BY customer_id;