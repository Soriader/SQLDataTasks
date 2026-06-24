--Create schema

CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS oltp;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS metadata;


CREATE TABLE oltp.customers(
customer_id BIGSERIAL PRIMARY KEY,
full_name TEXT NOT NULL,
email CITEXT UNIQUE NOT NULL,
country TEXT,
segment TEXT NOT NULL CHECK (
    segment IN ('RETAIL', 'PREMIUM', 'BUSINESS')
),
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE oltp.authors(
author_id BIGSERIAL PRIMARY KEY,
author_name TEXT NOT NULL,
author_country TEXT NOT NULL,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE oltp.books(
book_id BIGSERIAL PRIMARY KEY,
author_id  BIGINT NOT NULL REFERENCES oltp.authors(author_id),
title TEXT NOT NULL,
isbn TEXT UNIQUE NOT NULL CHECK (length(isbn) = 13),
genre TEXT NOT NULL,
publisher TEXT NOT NULL,
price NUMERIC(9, 2) NOT NULL CHECK (price > 0),
published_at DATE NOT NULL,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE oltp.orders(
order_id BIGSERIAL PRIMARY KEY,
customer_id BIGINT NOT NULL REFERENCES oltp.customers(customer_id),
order_status TEXT NOT NULL CHECK (
    order_status IN ('NEW', 'PAID', 'SHIPPED', 'CANCELLED', 'REFUNDED')
),
placed_at TIMESTAMPTZ NOT NULL,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE oltp.order_items(
order_item_id BIGSERIAL PRIMARY KEY,
order_id BIGINT NOT NULL REFERENCES oltp.orders(order_id),
book_id BIGINT NOT NULL REFERENCES oltp.books(book_id),
quantity INT NOT NULL CHECK (quantity > 0),
price_each NUMERIC(9, 2) NOT NULL CHECK (price_each > 0),
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
UNIQUE (order_id, book_id)
);

CREATE INDEX idx_books_authors ON oltp.books(author_id);
CREATE INDEX idx_orders_customers ON oltp.orders(customer_id);
CREATE INDEX idx_order_items_orders ON oltp.order_items(order_id);
CREATE INDEX idx_order_items_books ON oltp.order_items(book_id);

ALTER TABLE oltp.customers REPLICA IDENTITY FULL;
ALTER TABLE oltp.authors REPLICA IDENTITY FULL;
ALTER TABLE oltp.books REPLICA IDENTITY FULL;
ALTER TABLE oltp.orders REPLICA IDENTITY FULL;
ALTER TABLE oltp.order_items REPLICA IDENTITY FULL;

--bronze schema

CREATE TABLE bronze.orders_raw (
raw_event_id BIGSERIAL PRIMARY KEY,
source_slot TEXT NOT NULL,
source_lsn TEXT NOT NULL,
source_xid TEXT NOT NULL,
source_schema TEXT NOT NULL,
source_table TEXT NOT NULL,

operation TEXT NOT NULL CHECK (
	operation IN ('INSERT', 'UPDATE', 'DELETE')
),

order_id BIGINT,
customer_id BIGINT,
order_status TEXT,
placed_at TIMESTAMPTZ,
created_at TIMESTAMPTZ,
updated_at TIMESTAMPTZ,
raw_change TEXT NOT NULL,
change_hash TEXT NOT NULL,
ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

CONSTRAINT uq_orders_raw_idempotent
UNIQUE (
source_slot,
source_lsn,
source_xid,
change_hash
)
);

CREATE INDEX idx_orders_raw_lsn
    ON bronze.orders_raw(source_lsn);

CREATE INDEX idx_orders_raw_operation
    ON bronze.orders_raw(operation);

CREATE INDEX idx_orders_raw_order_id
    ON bronze.orders_raw(order_id);

CREATE INDEX idx_orders_raw_ingested_at
    ON bronze.orders_raw(ingested_at);

CREATE TABLE bronze.customers_raw (
    raw_event_id BIGSERIAL PRIMARY KEY,

    source_slot TEXT NOT NULL,
    source_lsn TEXT NOT NULL,
    source_xid TEXT NOT NULL,
    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,

    operation TEXT NOT NULL CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    customer_id BIGINT,
    full_name TEXT,
    email TEXT,
    country TEXT,
    segment TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    raw_change TEXT NOT NULL,
    change_hash TEXT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_customers_raw_idempotent
        UNIQUE (
            source_slot,
            source_lsn,
            source_xid,
            change_hash
        )
);

CREATE INDEX idx_customers_raw_lsn
    ON bronze.customers_raw(source_lsn);

CREATE INDEX idx_customers_raw_operation
    ON bronze.customers_raw(operation);

CREATE INDEX idx_customers_raw_customer_id
    ON bronze.customers_raw(customer_id);

CREATE INDEX idx_customers_raw_ingested_at
    ON bronze.customers_raw(ingested_at);


CREATE TABLE bronze.books_raw (
    raw_event_id BIGSERIAL PRIMARY KEY,

    source_slot TEXT NOT NULL,
    source_lsn TEXT NOT NULL,
    source_xid TEXT NOT NULL,
    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,

    operation TEXT NOT NULL CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    book_id BIGINT,
    author_id BIGINT,
    title TEXT,
    isbn TEXT,
    genre TEXT,
    publisher TEXT,
    price NUMERIC(9, 2) CHECK (price IS NULL OR price > 0),
    published_at DATE,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    raw_change TEXT NOT NULL,
    change_hash TEXT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_books_raw_idempotent
        UNIQUE (
            source_slot,
            source_lsn,
            source_xid,
            change_hash
        )
);

CREATE INDEX idx_books_raw_lsn
    ON bronze.books_raw(source_lsn);

CREATE INDEX idx_books_raw_operation
    ON bronze.books_raw(operation);

CREATE INDEX idx_books_raw_book_id
    ON bronze.books_raw(book_id);

CREATE INDEX idx_books_raw_author_id
    ON bronze.books_raw(author_id);

CREATE INDEX idx_books_raw_ingested_at
    ON bronze.books_raw(ingested_at);

CREATE TABLE bronze.authors_raw (
    raw_event_id BIGSERIAL PRIMARY KEY,

    source_slot TEXT NOT NULL,
    source_lsn TEXT NOT NULL,
    source_xid TEXT NOT NULL,
    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,

    operation TEXT NOT NULL CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    author_id BIGINT,
    author_name TEXT,
    author_country TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    raw_change TEXT NOT NULL,
    change_hash TEXT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_authors_raw_idempotent
        UNIQUE (
            source_slot,
            source_lsn,
            source_xid,
            change_hash
        )
);

CREATE INDEX idx_authors_raw_lsn
    ON bronze.authors_raw(source_lsn);

CREATE INDEX idx_authors_raw_operation
    ON bronze.authors_raw(operation);

CREATE INDEX idx_authors_raw_author_id
    ON bronze.authors_raw(author_id);

CREATE INDEX idx_authors_raw_ingested_at
    ON bronze.authors_raw(ingested_at);

CREATE TABLE bronze.order_items_raw (
    raw_event_id BIGSERIAL PRIMARY KEY,

    source_slot TEXT NOT NULL,
    source_lsn TEXT NOT NULL,
    source_xid TEXT NOT NULL,
    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,

    operation TEXT NOT NULL CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    order_item_id BIGINT,
    order_id BIGINT,
    book_id BIGINT,
    quantity INT CHECK (quantity IS NULL OR quantity > 0),
    price_each NUMERIC(9, 2) CHECK (price_each IS NULL OR price_each > 0),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    raw_change TEXT NOT NULL,
    change_hash TEXT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_order_items_raw_idempotent
        UNIQUE (
            source_slot,
            source_lsn,
            source_xid,
            change_hash
        )
);

CREATE INDEX idx_order_items_raw_lsn
    ON bronze.order_items_raw(source_lsn);

CREATE INDEX idx_order_items_raw_operation
    ON bronze.order_items_raw(operation);

CREATE INDEX idx_order_items_raw_order_item_id
    ON bronze.order_items_raw(order_item_id);

CREATE INDEX idx_order_items_raw_order_id
    ON bronze.order_items_raw(order_id);

CREATE INDEX idx_order_items_raw_book_id
    ON bronze.order_items_raw(book_id);

CREATE INDEX idx_order_items_raw_ingested_at
    ON bronze.order_items_raw(ingested_at);

--metadata schema

CREATE TABLE metadata.cdc_consumer_offsets (
    consumer_name TEXT NOT NULL,
    slot_name TEXT NOT NULL,

    last_lsn TEXT,
    last_xid TEXT,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (consumer_name, slot_name)
);

CREATE TABLE metadata.pipeline_runs (
    run_id BIGSERIAL PRIMARY KEY,

    pipeline_name TEXT NOT NULL,

    status TEXT NOT NULL CHECK (
        status IN ('RUNNING', 'SUCCESS', 'FAILED', 'PARTIAL')
    ),

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,

    rows_read BIGINT NOT NULL DEFAULT 0,
    rows_written BIGINT NOT NULL DEFAULT 0,
    rows_failed BIGINT NOT NULL DEFAULT 0,

    error_message TEXT
);

CREATE INDEX idx_pipeline_runs_pipeline_name
    ON metadata.pipeline_runs(pipeline_name);

CREATE INDEX idx_pipeline_runs_status
    ON metadata.pipeline_runs(status);

CREATE INDEX idx_pipeline_runs_started_at
    ON metadata.pipeline_runs(started_at);

CREATE TABLE metadata.data_quality_errors (
    error_id BIGSERIAL PRIMARY KEY,

    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,

    raw_event_id BIGINT,
    business_key TEXT,

    error_type TEXT NOT NULL CHECK (
        error_type IN (
            'MISSING_REQUIRED_FIELD',
            'INVALID_STATUS',
            'INVALID_PRICE',
            'INVALID_QUANTITY',
            'INVALID_DATE',
            'INVALID_EMAIL',
            'DUPLICATE_BUSINESS_KEY',
            'FK_NOT_FOUND',
            'PARSE_ERROR',
            'UNKNOWN_OPERATION',
            'SCHEMA_MISMATCH'
        )
    ),

    error_message TEXT NOT NULL,
    raw_payload TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_data_quality_errors_source
    ON metadata.data_quality_errors(source_schema, source_table);

CREATE INDEX idx_data_quality_errors_error_type
    ON metadata.data_quality_errors(error_type);

CREATE INDEX idx_data_quality_errors_created_at
    ON metadata.data_quality_errors(created_at);

CREATE INDEX idx_data_quality_errors_business_key
    ON metadata.data_quality_errors(business_key);

-- silver schema

CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE silver.customers (
    customer_id BIGINT PRIMARY KEY,

    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    country TEXT,

    segment TEXT NOT NULL CHECK (
        segment IN ('RETAIL', 'PREMIUM', 'BUSINESS')
    ),

    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    source_raw_event_id BIGINT NOT NULL,
    source_lsn TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_customers_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

CREATE TABLE silver.authors (
    author_id BIGINT PRIMARY KEY,

    author_name TEXT NOT NULL,
    author_country TEXT NOT NULL,

    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    source_raw_event_id BIGINT NOT NULL,
    source_lsn TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_authors_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

CREATE TABLE silver.books (
    book_id BIGINT PRIMARY KEY,

    author_id BIGINT NOT NULL,
    title TEXT NOT NULL,
    isbn TEXT NOT NULL CHECK (length(isbn) = 13),
    genre TEXT NOT NULL,
    publisher TEXT NOT NULL,
    price NUMERIC(9, 2) NOT NULL CHECK (price > 0),
    published_at DATE NOT NULL,

    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    source_raw_event_id BIGINT NOT NULL,
    source_lsn TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_books_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

CREATE TABLE silver.orders (
    order_id BIGINT PRIMARY KEY,

    customer_id BIGINT NOT NULL,

    order_status TEXT NOT NULL CHECK (
        order_status IN ('NEW', 'PAID', 'SHIPPED', 'CANCELLED', 'REFUNDED')
    ),

    placed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    source_raw_event_id BIGINT NOT NULL,
    source_lsn TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_orders_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

CREATE TABLE silver.order_items (
    order_item_id BIGINT PRIMARY KEY,

    order_id BIGINT NOT NULL,
    book_id BIGINT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_each NUMERIC(9, 2) NOT NULL CHECK (price_each > 0),

    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,

    source_raw_event_id BIGINT NOT NULL,
    source_lsn TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_order_items_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

ALTER TABLE silver.books
ADD CONSTRAINT fk_silver_books_author
FOREIGN KEY (author_id)
REFERENCES silver.authors(author_id);

ALTER TABLE silver.orders
ADD CONSTRAINT fk_silver_orders_customer
FOREIGN KEY (customer_id)
REFERENCES silver.customers(customer_id);

ALTER TABLE silver.order_items
ADD CONSTRAINT fk_silver_order_items_order
FOREIGN KEY (order_id)
REFERENCES silver.orders(order_id);

ALTER TABLE silver.order_items
ADD CONSTRAINT fk_silver_order_items_book
FOREIGN KEY (book_id)
REFERENCES silver.books(book_id);

CREATE INDEX idx_silver_customers_source_lsn
    ON silver.customers(source_lsn);

CREATE INDEX idx_silver_customers_loaded_at
    ON silver.customers(loaded_at);

CREATE INDEX idx_silver_customers_is_deleted
    ON silver.customers(is_deleted);

CREATE INDEX idx_silver_customers_email
    ON silver.customers(email);

CREATE UNIQUE INDEX uq_silver_customers_email_active
    ON silver.customers(email)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_silver_authors_source_lsn
    ON silver.authors(source_lsn);

CREATE INDEX idx_silver_authors_loaded_at
    ON silver.authors(loaded_at);

CREATE INDEX idx_silver_authors_is_deleted
    ON silver.authors(is_deleted);

CREATE INDEX idx_silver_books_author_id
    ON silver.books(author_id);

CREATE INDEX idx_silver_books_source_lsn
    ON silver.books(source_lsn);

CREATE INDEX idx_silver_books_loaded_at
    ON silver.books(loaded_at);

CREATE INDEX idx_silver_books_is_deleted
    ON silver.books(is_deleted);

CREATE UNIQUE INDEX uq_silver_books_isbn_active
    ON silver.books(isbn)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_silver_orders_customer_id
    ON silver.orders(customer_id);

CREATE INDEX idx_silver_orders_source_lsn
    ON silver.orders(source_lsn);

CREATE INDEX idx_silver_orders_loaded_at
    ON silver.orders(loaded_at);

CREATE INDEX idx_silver_orders_is_deleted
    ON silver.orders(is_deleted);

CREATE INDEX idx_silver_orders_order_status
    ON silver.orders(order_status);

CREATE INDEX idx_silver_orders_placed_at
    ON silver.orders(placed_at);

CREATE INDEX idx_silver_order_items_order_id
    ON silver.order_items(order_id);

CREATE INDEX idx_silver_order_items_book_id
    ON silver.order_items(book_id);

CREATE INDEX idx_silver_order_items_source_lsn
    ON silver.order_items(source_lsn);

CREATE INDEX idx_silver_order_items_loaded_at
    ON silver.order_items(loaded_at);

CREATE INDEX idx_silver_order_items_is_deleted
    ON silver.order_items(is_deleted);

CREATE UNIQUE INDEX uq_silver_order_items_order_book_active
    ON silver.order_items(order_id, book_id)
    WHERE is_deleted = FALSE;


--gold schema

CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE gold.dim_customer (
    customer_key BIGSERIAL PRIMARY KEY,

    customer_id BIGINT NOT NULL,
    full_name TEXT NOT NULL,
    email CITEXT NOT NULL,
    country TEXT,

    segment TEXT NOT NULL CHECK (
        segment IN ('RETAIL', 'PREMIUM', 'BUSINESS')
    ),

    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,

    source_lsn TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dim_customer_validity
        CHECK (
            (is_current = TRUE AND valid_to IS NULL)
            OR
            (is_current = FALSE AND valid_to IS NOT NULL)
        ),

    CONSTRAINT chk_dim_customer_valid_range
        CHECK (
            valid_to IS NULL
            OR valid_to > valid_from
        )
);

CREATE UNIQUE INDEX uq_gold_dim_customer_current
    ON gold.dim_customer(customer_id)
    WHERE is_current = TRUE;

CREATE UNIQUE INDEX uq_gold_dim_customer_email_current
    ON gold.dim_customer(email)
    WHERE is_current = TRUE;

CREATE INDEX idx_gold_dim_customer_customer_id
    ON gold.dim_customer(customer_id);

CREATE INDEX idx_gold_dim_customer_segment
    ON gold.dim_customer(segment);

CREATE INDEX idx_gold_dim_customer_is_current
    ON gold.dim_customer(is_current);

CREATE TABLE gold.dim_book (
    book_key BIGSERIAL PRIMARY KEY,

    book_id BIGINT NOT NULL,
    author_id BIGINT NOT NULL,

    title TEXT NOT NULL,
    isbn TEXT NOT NULL CHECK (length(isbn) = 13),
    genre TEXT NOT NULL,
    publisher TEXT NOT NULL,

    author_name TEXT NOT NULL,
    author_country TEXT NOT NULL,

    published_at DATE,
    list_price NUMERIC(9, 2) CHECK (list_price IS NULL OR list_price > 0),

    source_lsn TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT chk_dim_book_deleted_at
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL)
            OR
            (is_deleted = TRUE AND deleted_at IS NOT NULL)
        )
);

CREATE UNIQUE INDEX uq_gold_dim_book_book_id_active
    ON gold.dim_book(book_id)
    WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX uq_gold_dim_book_isbn_active
    ON gold.dim_book(isbn)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_gold_dim_book_book_id
    ON gold.dim_book(book_id);

CREATE INDEX idx_gold_dim_book_author_id
    ON gold.dim_book(author_id);

CREATE INDEX idx_gold_dim_book_genre
    ON gold.dim_book(genre);

CREATE INDEX idx_gold_dim_book_author_name
    ON gold.dim_book(author_name);

CREATE INDEX idx_gold_dim_book_is_deleted
    ON gold.dim_book(is_deleted);


CREATE TABLE gold.dim_date (
    date_key INT PRIMARY KEY,

    full_date DATE NOT NULL UNIQUE,

    year INT NOT NULL,
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name TEXT NOT NULL,

    day INT NOT NULL CHECK (day BETWEEN 1 AND 31),
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_name TEXT NOT NULL,

    week_of_year INT NOT NULL CHECK (week_of_year BETWEEN 1 AND 53),
    is_weekend BOOLEAN NOT NULL
);

CREATE INDEX idx_gold_dim_date_full_date
    ON gold.dim_date(full_date);

CREATE INDEX idx_gold_dim_date_year_month
    ON gold.dim_date(year, month);

CREATE INDEX idx_gold_dim_date_year_quarter
    ON gold.dim_date(year, quarter);


INSERT INTO gold.dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name,
    week_of_year,
    is_weekend
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INT AS date_key,
    d::DATE AS full_date,
    EXTRACT(YEAR FROM d)::INT AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(MONTH FROM d)::INT AS month,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    EXTRACT(DAY FROM d)::INT AS day,
    EXTRACT(ISODOW FROM d)::INT AS day_of_week,
    TRIM(TO_CHAR(d, 'Day')) AS day_name,
    EXTRACT(WEEK FROM d)::INT AS week_of_year,
    EXTRACT(ISODOW FROM d)::INT IN (6, 7) AS is_weekend
FROM generate_series(
    '2020-01-01'::DATE,
    '2035-12-31'::DATE,
    INTERVAL '1 day'
) AS g(d)
ON CONFLICT (date_key) DO NOTHING;

CREATE TABLE gold.fact_order_line (
    order_line_key BIGSERIAL PRIMARY KEY,

    order_item_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,

    customer_key BIGINT NOT NULL,
    book_key BIGINT NOT NULL,
    date_key INT NOT NULL,

    order_status TEXT NOT NULL CHECK (
        order_status IN ('NEW', 'PAID', 'SHIPPED', 'CANCELLED', 'REFUNDED')
    ),

    quantity INT NOT NULL CHECK (quantity > 0),
    price_each NUMERIC(9, 2) NOT NULL CHECK (price_each > 0),

    line_total NUMERIC(12, 2)
        GENERATED ALWAYS AS (quantity * price_each) STORED,

    placed_at TIMESTAMPTZ NOT NULL,

    source_order_lsn TEXT,
    source_order_item_lsn TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_fact_order_line_customer
        FOREIGN KEY (customer_key)
        REFERENCES gold.dim_customer(customer_key),

    CONSTRAINT fk_fact_order_line_book
        FOREIGN KEY (book_key)
        REFERENCES gold.dim_book(book_key),

    CONSTRAINT fk_fact_order_line_date
        FOREIGN KEY (date_key)
        REFERENCES gold.dim_date(date_key)
);

CREATE UNIQUE INDEX uq_gold_fact_order_line_order_item
    ON gold.fact_order_line(order_item_id);

CREATE INDEX idx_gold_fact_order_line_order_id
    ON gold.fact_order_line(order_id);

CREATE INDEX idx_gold_fact_order_line_customer_key
    ON gold.fact_order_line(customer_key);

CREATE INDEX idx_gold_fact_order_line_book_key
    ON gold.fact_order_line(book_key);

CREATE INDEX idx_gold_fact_order_line_date_key
    ON gold.fact_order_line(date_key);

CREATE INDEX idx_gold_fact_order_line_order_status
    ON gold.fact_order_line(order_status);

CREATE INDEX idx_gold_fact_order_line_loaded_at
    ON gold.fact_order_line(loaded_at);