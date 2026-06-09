ORDERS = [
    {
        "order_id": 1,
        "customer_id": 10,
        "country": "PL",
        "status": "paid",
        "quantity": 2,
        "price_each": 25.00,
        "placed_at": "2026-05-01T09:00:00"
    }
]


# (a)
total = sum(
    order["quantity"]
    for order in ORDERS
    if order["status"] == "paid"
)

# (b)
by_country = {}

for order in ORDERS:
    country = order["country"]
    by_country.setdefault(country, []).append(order["order_id"])

# (c)
match = next(
    (
        order
        for order in ORDERS
        if order["status"] == "paid"
        and order["quantity"] * order["price_each"] > 100
    ),
    None
)

# (d)
countries = sorted(
    set(order["country"] for order in ORDERS)
)

# (e)
revenue = {}

for order in ORDERS:
    country = order["country"]
    row_revenue = order["quantity"] * order["price_each"]
    revenue[country] = revenue.get(country, 0) + row_revenue