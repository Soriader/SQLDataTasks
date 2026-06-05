--bronze schema

CREATE SCHEMA IF NOT EXISTS bronze;

CREATE TABLE bronze.customers_raw (
    source_customer_id BIGINT,
    full_name TEXT,
    email TEXT,
    country TEXT,
    segment TEXT,
    created_at TEXT,

    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    batch_id TEXT,
    source_system TEXT
);

CREATE TABLE bronze.authors_raw (
    source_author_id BIGINT,
    author_name TEXT,
    author_country TEXT,

    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    batch_id TEXT,
    source_system TEXT
);

CREATE TABLE bronze.books_raw (
    source_book_id BIGINT,
    source_author_id BIGINT,
    title TEXT,
    isbn TEXT,
    price TEXT,
    published_at TEXT,

    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    batch_id TEXT,
    source_system TEXT
);

CREATE TABLE bronze.orders_raw (
    source_order_id BIGINT,
    source_customer_id BIGINT,
    placed_at TEXT,
    status TEXT,

    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    batch_id TEXT,
    source_system TEXT
);

CREATE TABLE bronze.order_items_raw (
    source_order_id BIGINT,
    source_book_id BIGINT,
    quantity TEXT,
    price_each TEXT,

    ingested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    batch_id TEXT,
    source_system TEXT
);

--test

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'bronze'
ORDER BY table_name;

--silver schema

CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE silver.customers (
    customer_id BIGINT PRIMARY KEY,

    full_name TEXT,
    email CITEXT,
    country TEXT,
    segment TEXT,

    created_at TIMESTAMPTZ,

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE silver.authors (
    author_id BIGINT PRIMARY KEY,

    author_name TEXT NOT NULL,
    author_country TEXT,

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE silver.books (
    book_id BIGINT PRIMARY KEY,

    author_id BIGINT REFERENCES silver.authors(author_id),

    title TEXT NOT NULL,
    isbn TEXT,
    price NUMERIC(10, 2),
    published_at DATE,

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_silver_books_price
        CHECK (price IS NULL OR price >= 0)
);


CREATE TABLE silver.orders (
    order_id BIGINT PRIMARY KEY,

    customer_id BIGINT REFERENCES silver.customers(customer_id),

    placed_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL,

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE silver.order_items (
    order_id BIGINT NOT NULL REFERENCES silver.orders(order_id),
    book_id BIGINT NOT NULL REFERENCES silver.books(book_id),

    quantity INT NOT NULL,
    price_each NUMERIC(10, 2) NOT NULL,

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_silver_order_items
        PRIMARY KEY (order_id, book_id),

    CONSTRAINT chk_silver_order_items_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_silver_order_items_price_each
        CHECK (price_each >= 0)
);

--gold schema

CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE gold.dim_customer (
    customer_key BIGSERIAL PRIMARY KEY,

    customer_id BIGINT NOT NULL,

    full_name TEXT,
    email TEXT,
    country TEXT,
    segment TEXT,

    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE gold.dim_book (
    book_key BIGSERIAL PRIMARY KEY,

    book_id BIGINT NOT NULL,

    title TEXT,
    isbn TEXT,

    author_name TEXT,
    author_country TEXT,

    genre TEXT,
    publisher TEXT
);

CREATE TABLE gold.dim_date (
    date_key INT PRIMARY KEY,

    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name TEXT NOT NULL,
    day INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name TEXT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE gold.fact_order_line (
    order_line_key BIGSERIAL PRIMARY KEY,

    order_id BIGINT NOT NULL,

    customer_key BIGINT NOT NULL,
    book_key BIGINT NOT NULL,
    date_key INT NOT NULL,

    quantity INT NOT NULL,
    price_each NUMERIC(10, 2) NOT NULL,

    line_total NUMERIC(12, 2)
        GENERATED ALWAYS AS (quantity * price_each) STORED,

    CONSTRAINT fk_fact_order_line_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer(customer_key),

    CONSTRAINT fk_fact_order_line_book
        FOREIGN KEY (book_key)
        REFERENCES gold.dim_book(book_key),

    CONSTRAINT fk_fact_order_line_date
        FOREIGN KEY (date_key)
        REFERENCES gold.dim_date(date_key),

    CONSTRAINT chk_fact_order_line_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_fact_order_line_price_each
        CHECK (price_each >= 0)
);