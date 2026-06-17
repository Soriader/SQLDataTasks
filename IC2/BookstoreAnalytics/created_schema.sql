-- ============================================================
-- Facts:
--   fact_order_line - one row per order × book
--
-- Dimensions:
--   dim_customer
--   dim_book
--   dim_date
--
-- In this model dim_book is flattened:
-- author, genre and publisher data are stored directly in dim_book.
-- ============================================================


-- =========================
-- DIMENSION: Customer
-- =========================

CREATE TABLE dim_customer (
    customer_key BIGSERIAL PRIMARY KEY,

    -- Natural key from the source system
    customer_id BIGINT NOT NULL,

    email TEXT,
    country TEXT,
    segment TEXT,

    -- SCD Type 2 fields
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);


-- =========================
-- DIMENSION: Date
-- =========================

CREATE TABLE dim_date (
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


-- =========================
-- DIMENSION: Book
-- =========================

CREATE TABLE dim_book (
    book_key BIGSERIAL PRIMARY KEY,

    -- Natural key from the source system
    book_id BIGINT NOT NULL,

    title TEXT,
    isbn CHAR(13),

    -- Denormalized author data
    author_name TEXT,
    author_country TEXT,

    -- Denormalized book attributes
    genre TEXT,
    publisher TEXT
);


-- =========================
-- FACT TABLE: Order Line
-- =========================

CREATE TABLE fact_order_line (
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
        REFERENCES dim_customer (customer_key),

    CONSTRAINT fk_fact_order_line_book
        FOREIGN KEY (book_key)
        REFERENCES dim_book (book_key),

    CONSTRAINT fk_fact_order_line_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date (date_key)
);