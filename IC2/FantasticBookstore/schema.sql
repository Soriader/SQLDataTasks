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