CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,

    owner_name TEXT NOT NULL,

    balance NUMERIC(12, 2) NOT NULL
        CHECK (balance >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transfers (
    id BIGSERIAL PRIMARY KEY,

    from_account_id BIGINT NOT NULL,
    to_account_id BIGINT NOT NULL,

    amount NUMERIC(12, 2) NOT NULL,
    status TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_transfers_from_account
        FOREIGN KEY (from_account_id)
        REFERENCES accounts(id),

    CONSTRAINT fk_transfers_to_account
        FOREIGN KEY (to_account_id)
        REFERENCES accounts(id),

    CONSTRAINT chk_transfers_amount
        CHECK (amount > 0),

    CONSTRAINT chk_transfers_different_accounts
        CHECK (from_account_id <> to_account_id),

    CONSTRAINT chk_transfers_status
        CHECK (status IN ('PENDING', 'DEBITED', 'COMPLETED', 'FAILED', 'COMPENSATED'))
);

CREATE TABLE outbox_events (
    event_id BIGSERIAL PRIMARY KEY,

    aggregate_type TEXT NOT NULL,
    aggregate_id BIGINT NOT NULL,

    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,

    status TEXT NOT NULL DEFAULT 'NEW',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMPTZ,

    retry_count INT NOT NULL DEFAULT 0,
    last_error TEXT,

    CONSTRAINT chk_outbox_aggregate_type
        CHECK (aggregate_type IN ('TRANSFER', 'ACCOUNT')),

    CONSTRAINT chk_outbox_event_type
        CHECK (event_type IN (
            'TransferRequested',
            'MoneyDebited',
            'MoneyCredited',
            'MoneyCreditFailed',
            'TransferCompleted',
            'TransferFailed',
            'MoneyRefunded',
            'AccountBalanceChanged'
        )),

    CONSTRAINT chk_outbox_status
        CHECK (status IN ('NEW', 'PUBLISHED', 'FAILED'))
);


--for IC2.6

CREATE SCHEMA IF NOT EXISTS isolation_lab;

DROP TABLE IF EXISTS isolation_lab.isolation_orders;

CREATE TABLE isolation_lab.isolation_orders (
    id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL
);

INSERT INTO isolation_lab.isolation_orders (
    customer_name,
    amount,
    status
)
VALUES
    ('Anna', 100.00, 'PAID'),
    ('Jan', 200.00, 'PAID'),
    ('Maria', 50.00, 'PENDING');

-- for IC2.8

CREATE TABLE cdc_lab.customers_cdc_test (
    id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    email TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE cdc_lab.customers_cdc_test
REPLICA IDENTITY FULL;

--for IC2.9

CREATE SCHEMA IF NOT EXISTS cdc_lab;
CREATE SCHEMA IF NOT EXISTS bronze;

DROP TABLE IF EXISTS cdc_lab.orders_source;

CREATE TABLE cdc_lab.orders_source (
    order_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    order_status TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE cdc_lab.orders_source
REPLICA IDENTITY FULL;