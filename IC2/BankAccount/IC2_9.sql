--create bronze table

DROP TABLE IF EXISTS bronze.orders_raw;

CREATE TABLE bronze.orders_raw (
    raw_event_id BIGSERIAL PRIMARY KEY,

    source_slot TEXT NOT NULL,
    source_lsn TEXT NOT NULL,
    source_xid TEXT NOT NULL,

    source_schema TEXT NOT NULL,
    source_table TEXT NOT NULL,
    operation TEXT NOT NULL,

    raw_change TEXT NOT NULL,
    change_hash TEXT NOT NULL,

    ingested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_orders_raw_idempotent
        UNIQUE (
            source_slot,
            source_lsn,
            source_xid,
            change_hash
        )
);

--offset table

DROP TABLE IF EXISTS bronze.cdc_consumer_offsets;

CREATE TABLE bronze.cdc_consumer_offsets (
    slot_name TEXT PRIMARY KEY,
    last_lsn TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

--create slot

SELECT *
FROM pg_create_logical_replication_slot(
    'orders_cdc_slot',
    'test_decoding'
);

--CDC events

INSERT INTO cdc_lab.orders_source (
    customer_id,
    order_status,
    amount
)
VALUES
    (1001, 'NEW', 120.00),
    (1002, 'NEW', 250.00);

UPDATE cdc_lab.orders_source
SET
    order_status = 'PAID',
    updated_at = clock_timestamp()
WHERE order_id = 1;

DELETE FROM cdc_lab.orders_source
WHERE order_id = 2;

--WAL events

SELECT *
FROM pg_logical_slot_get_changes(
    'orders_cdc_slot',
    NULL,
    NULL
);

"0/634B510"	"907"	"BEGIN 907"
"0/634B578"	"907"	"table cdc_lab.orders_source: INSERT: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'NEW' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' updated_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02'"
"0/634B680"	"907"	"table cdc_lab.orders_source: INSERT: order_id[bigint]:2 customer_id[bigint]:1002 order_status[text]:'NEW' amount[numeric]:250.00 created_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' updated_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02'"
"0/634B758"	"907"	"COMMIT 907"
"0/634B790"	"908"	"BEGIN 908"
"0/634B790"	"908"	"table cdc_lab.orders_source: UPDATE: old-key: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'NEW' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' updated_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' new-tuple: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'PAID' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' updated_at[timestamp with time zone]:'2026-06-22 17:55:24.300695+02'"
"0/634B868"	"908"	"COMMIT 908"
"0/634B8A0"	"909"	"BEGIN 909"
"0/634B8A0"	"909"	"table cdc_lab.orders_source: DELETE: order_id[bigint]:2 customer_id[bigint]:1002 order_status[text]:'NEW' amount[numeric]:250.00 created_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02' updated_at[timestamp with time zone]:'2026-06-22 17:55:08.799614+02'"
"0/634B940"	"909"	"COMMIT 909"


--save to bronze

WITH cdc_changes AS (
    SELECT
        'orders_cdc_slot'::TEXT AS source_slot,
        lsn::TEXT AS source_lsn,
        xid::TEXT AS source_xid,
        'cdc_lab'::TEXT AS source_schema,
        'orders_source'::TEXT AS source_table,
        CASE
            WHEN data LIKE 'table cdc_lab.orders_source: INSERT:%' THEN 'INSERT'
            WHEN data LIKE 'table cdc_lab.orders_source: UPDATE:%' THEN 'UPDATE'
            WHEN data LIKE 'table cdc_lab.orders_source: DELETE:%' THEN 'DELETE'
            ELSE NULL
        END AS operation,
        data AS raw_change,
        md5(data) AS change_hash
    FROM pg_logical_slot_peek_changes(
        'orders_cdc_slot',
        NULL,
        NULL
    )
    WHERE data LIKE 'table cdc_lab.orders_source:%'
)
INSERT INTO bronze.orders_raw (
    source_slot,
    source_lsn,
    source_xid,
    source_schema,
    source_table,
    operation,
    raw_change,
    change_hash
)
SELECT
    source_slot,
    source_lsn,
    source_xid,
    source_schema,
    source_table,
    operation,
    raw_change,
    change_hash
FROM cdc_changes
WHERE operation IS NOT NULL
ON CONFLICT ON CONSTRAINT uq_orders_raw_idempotent
DO NOTHING;

--bronze events:

1	"0/637C810"	"913"	"INSERT"	"table cdc_lab.orders_source: INSERT: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'NEW' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' updated_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02'"
2	"0/637C918"	"913"	"INSERT"	"table cdc_lab.orders_source: INSERT: order_id[bigint]:2 customer_id[bigint]:1002 order_status[text]:'NEW' amount[numeric]:250.00 created_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' updated_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02'"
3	"0/637C9C0"	"913"	"UPDATE"	"table cdc_lab.orders_source: UPDATE: old-key: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'NEW' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' updated_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' new-tuple: order_id[bigint]:1 customer_id[bigint]:1001 order_status[text]:'PAID' amount[numeric]:120.00 created_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' updated_at[timestamp with time zone]:'2026-06-22 18:02:16.455244+02'"
4	"0/637CA68"	"913"	"DELETE"	"table cdc_lab.orders_source: DELETE: order_id[bigint]:2 customer_id[bigint]:1002 order_status[text]:'NEW' amount[numeric]:250.00 created_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02' updated_at[timestamp with time zone]:'2026-06-22 18:02:16.452651+02'"

--save offset

SELECT *
FROM pg_logical_slot_get_changes(
    'orders_cdc_slot',
    NULL,
    NULL
);

INSERT INTO bronze.cdc_consumer_offsets (
    slot_name,
    last_lsn,
    updated_at
)
SELECT
    'orders_cdc_slot',
    MAX(source_lsn::pg_lsn)::TEXT,
    CURRENT_TIMESTAMP
FROM bronze.orders_raw
WHERE source_slot = 'orders_cdc_slot'
ON CONFLICT (slot_name)
DO UPDATE SET
    last_lsn = EXCLUDED.last_lsn,
    updated_at = CURRENT_TIMESTAMP;

--result

SELECT *
FROM bronze.cdc_consumer_offsets;

"orders_cdc_slot"	"0/637CA68"	"2026-06-22 18:03:57.26316+02"

SELECT COUNT(*) AS bronze_events_count
FROM bronze.orders_raw;

--result : 4