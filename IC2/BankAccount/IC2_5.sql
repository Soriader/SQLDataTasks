--FIRST TRANSACTION

BEGIN;

WITH new_transfer AS (
    INSERT INTO transfers (
        from_account_id,
        to_account_id,
        amount,
        status
    )
    VALUES (
        1,
        2,
        100.00,
        'PENDING'
    )
    RETURNING
        id,
        from_account_id,
        to_account_id,
        amount
)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'TransferRequested',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount
    ),
    'NEW'
FROM new_transfer;

COMMIT;

--Save event to outbox

BEGIN;

WITH transfer_to_debit AS (
    SELECT
        t.id,
        t.from_account_id,
        t.to_account_id,
        t.amount
    FROM transfers AS t
    WHERE t.id = 1
      AND t.status = 'PENDING'
),
debited_account AS (
    UPDATE accounts AS a
    SET balance = a.balance - t.amount
    FROM transfer_to_debit AS t
    WHERE a.id = t.from_account_id
      AND a.balance >= t.amount
    RETURNING
        t.id AS transfer_id,
        t.from_account_id,
        t.to_account_id,
        t.amount
),
updated_transfer AS (
    UPDATE transfers AS tr
    SET
        status = 'DEBITED',
        updated_at = CURRENT_TIMESTAMP
    FROM debited_account AS d
    WHERE tr.id = d.transfer_id
    RETURNING
        tr.id,
        tr.from_account_id,
        tr.to_account_id,
        tr.amount
)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'MoneyDebited',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount
    ),
    'NEW'
FROM updated_transfer;

COMMIT;

--adding money to the recipient's account

BEGIN;

WITH transfer_to_credit AS (
    SELECT
        t.id,
        t.from_account_id,
        t.to_account_id,
        t.amount
    FROM transfers AS t
    WHERE t.id = 1
      AND t.status = 'DEBITED'
),
credited_account AS (
    UPDATE accounts AS a
    SET balance = a.balance + t.amount
    FROM transfer_to_credit AS t
    WHERE a.id = t.to_account_id
    RETURNING
        t.id AS transfer_id,
        t.from_account_id,
        t.to_account_id,
        t.amount
),
updated_transfer AS (
    UPDATE transfers AS tr
    SET
        status = 'COMPLETED',
        updated_at = CURRENT_TIMESTAMP
    FROM credited_account AS c
    WHERE tr.id = c.transfer_id
    RETURNING
        tr.id,
        tr.from_account_id,
        tr.to_account_id,
        tr.amount
)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'MoneyCredited',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount
    ),
    'NEW'
FROM updated_transfer;

COMMIT;

--simulation of the event publishing process

BEGIN;

UPDATE outbox_events
SET
    status = 'PUBLISHED',
    published_at = CURRENT_TIMESTAMP
WHERE status = 'NEW';

COMMIT;


--Saga's fallback path - compensation

BEGIN;

WITH new_transfer AS (
	INSERT INTO transfers (
		from_account_id ,
		to_account_id,
		amount,
		status
	)
	VALUES (
		1,
		2,
		75.00,
		'PENDING'
	)
	RETURNING
		id,
		from_account_id ,
		to_account_id,
		amount

)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'TransferRequested',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount
    ),
    'NEW'
FROM new_transfer;

COMMIT;


BEGIN;

WITH transfer_to_debit AS (
    SELECT
        t.id,
        t.from_account_id,
        t.to_account_id,
        t.amount
    FROM transfers AS t
    WHERE t.id = 3
      AND t.status = 'PENDING'
),
debited_account AS (
    UPDATE accounts AS a
    SET balance = a.balance - t.amount
    FROM transfer_to_debit AS t
    WHERE a.id = t.from_account_id
      AND a.balance >= t.amount
    RETURNING
        t.id AS transfer_id,
        t.from_account_id,
        t.to_account_id,
        t.amount
),
updated_transfer AS (
    UPDATE transfers AS tr
    SET
        status = 'DEBITED',
        updated_at = CURRENT_TIMESTAMP
    FROM debited_account AS d
    WHERE tr.id = d.transfer_id
    RETURNING
        tr.id,
        tr.from_account_id,
        tr.to_account_id,
        tr.amount
)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'MoneyDebited',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount
    ),
    'NEW'
FROM updated_transfer;

COMMIT;

BEGIN;

WITH transfer_to_refund AS (
    SELECT
        t.id,
        t.from_account_id,
        t.to_account_id,
        t.amount
    FROM transfers AS t
    WHERE t.id = 3
      AND t.status = 'DEBITED'
),
refunded_account AS (
    UPDATE accounts AS a
    SET balance = t.amount + a.balance
    FROM transfer_to_refund AS t
    WHERE a.id = t.from_account_id
    RETURNING
        t.id AS transfer_id,
        t.from_account_id,
        t.to_account_id,
        t.amount
),
updated_transfer AS (
    UPDATE transfers AS tr
    SET
        status = 'COMPENSATED',
        updated_at = CURRENT_TIMESTAMP
    FROM refunded_account AS r
    WHERE tr.id = r.transfer_id
    RETURNING
        tr.id,
        tr.from_account_id,
        tr.to_account_id,
        tr.amount
)
INSERT INTO outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload,
    status
)
SELECT
    'TRANSFER',
    id,
    'MoneyRefunded',
    jsonb_build_object(
        'transferId', id,
        'fromAccountId', from_account_id,
        'toAccountId', to_account_id,
        'amount', amount,
        'reason', 'Credit failed'
    ),
    'NEW'
FROM updated_transfer;

COMMIT;

UPDATE outbox_events
SET
    status = 'PUBLISHED',
    published_at = CURRENT_TIMESTAMP
WHERE status = 'NEW';


