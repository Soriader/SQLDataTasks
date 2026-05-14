CREATE TABLE authors (
 id BIGSERIAL PRIMARY KEY,
 name TEXT NOT NULL,
 country TEXT,
 born_year INT CHECK (born_year > 1000)
);
CREATE TABLE books (
 id BIGSERIAL PRIMARY KEY,
 author_id BIGINT NOT NULL REFERENCES authors(id) ON DELETE
RESTRICT,
 title TEXT NOT NULL,
 isbn CHAR(13) UNIQUE,
 price NUMERIC(8,2) CHECK (price >= 0),
 published_at DATE NOT NULL
);
CREATE TABLE customers (
 id BIGSERIAL PRIMARY KEY,
 email CITEXT UNIQUE NOT NULL,
 country TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE orders (
 id BIGSERIAL PRIMARY KEY,
 customer_id BIGINT NOT NULL REFERENCES customers(id),
 placed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 status TEXT NOT NULL
);
CREATE TABLE order_items (
 order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE
CASCADE,
 book_id BIGINT NOT NULL REFERENCES books(id),
 quantity INT NOT NULL CHECK (quantity > 0),
 price_each NUMERIC(8,2) NOT NULL CHECK (price_each >= 0),
 PRIMARY KEY (order_id, book_id)
);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_placed ON orders(placed_at);
CREATE INDEX idx_books_author ON books(author_id);