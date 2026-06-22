ALTER TABLE cdc_lab.customers_cdc_test
REPLICA IDENTITY FULL;

--created slot
SELECT *
FROM pg_create_logical_replication_slot(
    'cdc_lab_slot',
    'test_decoding'
);

-- changed table

INSERT INTO cdc_lab.customers_cdc_test (
    customer_name,
    email,
    status
)
VALUES
    ('Anna Kowalska', 'anna@example.com', 'ACTIVE'),
    ('Jan Nowak', 'jan@example.com', 'ACTIVE');

UPDATE cdc_lab.customers_cdc_test
SET
    status = 'INACTIVE',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 2;

DELETE FROM cdc_lab.customers_cdc_test
WHERE id = 1;

--odczytaj zmiany z WAL-a

SELECT *
FROM pg_logical_slot_get_changes(
    'cdc_lab_slot',
    NULL,
    NULL
);

"0/6303DB0"	"903"	"BEGIN 903"
"0/6303E50"	"903"	"table cdc_lab.customers_cdc_test: INSERT: id[bigint]:1 customer_name[text]:'Anna Kowalska' email[text]:'anna@example.com' status[text]:'ACTIVE' created_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' updated_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02'"
"0/6303F68"	"903"	"table cdc_lab.customers_cdc_test: INSERT: id[bigint]:2 customer_name[text]:'Jan Nowak' email[text]:'jan@example.com' status[text]:'ACTIVE' created_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' updated_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02'"
"0/6304038"	"903"	"table cdc_lab.customers_cdc_test: UPDATE: old-key: id[bigint]:2 customer_name[text]:'Jan Nowak' email[text]:'jan@example.com' status[text]:'ACTIVE' created_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' updated_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' new-tuple: id[bigint]:2 customer_name[text]:'Jan Nowak' email[text]:'jan@example.com' status[text]:'INACTIVE' created_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' updated_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02'"
"0/6304100"	"903"	"table cdc_lab.customers_cdc_test: DELETE: id[bigint]:1 customer_name[text]:'Anna Kowalska' email[text]:'anna@example.com' status[text]:'ACTIVE' created_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02' updated_at[timestamp with time zone]:'2026-06-22 15:12:25.875452+02'"
"0/63041B0"	"903"	"COMMIT 903"