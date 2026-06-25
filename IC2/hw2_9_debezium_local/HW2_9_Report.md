# HW2.9 -- Set Up Debezium Locally

## Goal

The goal of this exercise was to set up a local CDC environment with:

- PostgreSQL,
- Kafka,
- Debezium Connect,
- Debezium PostgreSQL connector.

The expected result was to verify that changes written to PostgreSQL are captured by Debezium and delivered to Kafka topics.

---

## Architecture

```text
PostgreSQL write
    -> PostgreSQL WAL / logical replication
    -> Debezium PostgreSQL Connector
    -> Kafka topic
    -> Kafka consumer
```

The local environment used three Docker containers:

| Component | Container | Purpose |
|---|---|---|
| PostgreSQL | `postgres_cdc` | Source database with logical replication enabled |
| Kafka | `kafka` | Broker for CDC events |
| Debezium Connect | `debezium_connect` | Kafka Connect worker running the Debezium PostgreSQL connector |

---

## Project Files

```text
hw2_9_debezium_local/
├── docker-compose.yml
├── init.sql
└── register-postgres-connector.json
```

---

## PostgreSQL CDC Test Table

The monitored table was created in the `cdc_lab` schema:

```sql
CREATE SCHEMA IF NOT EXISTS cdc_lab;

CREATE TABLE IF NOT EXISTS cdc_lab.customers_cdc_test (
    id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    email TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE cdc_lab.customers_cdc_test
REPLICA IDENTITY FULL;

INSERT INTO cdc_lab.customers_cdc_test (
    customer_name,
    email,
    status
)
VALUES
    ('Anna Nowak', 'anna@example.com', 'ACTIVE'),
    ('Jan Kowalski', 'jan@example.com', 'ACTIVE');
```

`REPLICA IDENTITY FULL` was used so that Debezium could capture a fuller row image for update and delete events.

---

## Debezium Connector Configuration

The PostgreSQL connector was registered through the Kafka Connect REST API.

Important connector settings:

```json
{
  "name": "fantasticbookstore-postgres-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",

    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "fantasticbookstore",

    "topic.prefix": "fb",
    "schema.include.list": "cdc_lab",
    "table.include.list": "cdc_lab.customers_cdc_test",

    "plugin.name": "pgoutput",
    "slot.name": "fb_slot",
    "publication.name": "fb_publication",
    "publication.autocreate.mode": "filtered",

    "snapshot.mode": "initial",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
  }
}
```

Connector registration command used in PowerShell:

```powershell
curl.exe -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ --data-binary "@register-postgres-connector.json"
```

---

## Issue Encountered and Fix

At first, the connector was created, but the task failed:

```text
connector state: RUNNING
task state: FAILED
```

The important error was:

```text
No table filters found for filtered publication fb_publication
```

The cause was that the schema/table used by the connector did not exist inside the PostgreSQL Docker container.

The connector expected this table:

```text
cdc_lab.customers_cdc_test
```

A check against the Docker PostgreSQL instance returned no tables:

```powershell
docker exec -it postgres_cdc psql -U postgres -d fantasticbookstore -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'cdc_lab';"
```

Result before the fix:

```text
(0 rows)
```

The fix was to create the schema and table directly inside the `postgres_cdc` container, then delete and register the connector again.

Cleanup before re-registering:

```sql
DROP PUBLICATION IF EXISTS fb_publication;

SELECT pg_drop_replication_slot('fb_slot')
WHERE EXISTS (
    SELECT 1
    FROM pg_replication_slots
    WHERE slot_name = 'fb_slot'
);
```

---

## Connector Status After Fix

After re-registering the connector, both the connector and the task reached `RUNNING` state:

```json
{
  "name": "fantasticbookstore-postgres-connector",
  "connector": {
    "state": "RUNNING"
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING"
    }
  ],
  "type": "source"
}
```

This confirmed that Debezium successfully connected to PostgreSQL and started streaming CDC events.

---

## Kafka Topic Verification

Kafka topics were listed with:

```powershell
docker exec -it kafka /kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list
```

Observed topics:

```text
__consumer_offsets
fb.cdc_lab.customers_cdc_test
my_connect_configs
my_connect_offsets
my_connect_statuses
```

The relevant Debezium topic was:

```text
fb.cdc_lab.customers_cdc_test
```

---

## Kafka Consumer Verification

A Kafka console consumer was started with:

```powershell
docker exec -it kafka /kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic fb.cdc_lab.customers_cdc_test --from-beginning
```

Because `snapshot.mode` was set to `initial`, Debezium first emitted snapshot events for the two existing rows.

Snapshot events had:

```json
"op":"r"
```

The two snapshot rows were:

- `Anna Nowak`,
- `Jan Kowalski`.

---

## Live CDC Verification

The following changes were executed in PostgreSQL from a second terminal window.

### INSERT

```sql
INSERT INTO cdc_lab.customers_cdc_test (
    customer_name,
    email,
    status
)
VALUES (
    'Maria Test',
    'maria.test@example.com',
    'ACTIVE'
);
```

Kafka consumer received an event with:

```json
"op":"c"
```

This confirmed that Debezium captured the INSERT.

---

### UPDATE

```sql
UPDATE cdc_lab.customers_cdc_test
SET
    status = 'INACTIVE',
    updated_at = NOW()
WHERE email = 'maria.test@example.com';
```

Kafka consumer received an event with:

```json
"op":"u"
```

The event contained both:

```json
"before": { ... },
"after": { ... }
```

This confirmed that Debezium captured the UPDATE and showed the state before and after the change.

---

### DELETE

```sql
DELETE FROM cdc_lab.customers_cdc_test
WHERE email = 'maria.test@example.com';
```

Kafka consumer received an event with:

```json
"op":"d"
```

The event had:

```json
"before": { ... },
"after": null
```

After the delete event, a `null` message was also emitted. This is a tombstone message and is normal for Debezium delete handling.

---

## Debezium Operation Codes

| Operation code | Meaning |
|---|---|
| `r` | Snapshot/read event |
| `c` | Create / INSERT |
| `u` | UPDATE |
| `d` | DELETE |

---

## Final Evidence

The experiment confirmed that:

1. Docker Compose started PostgreSQL, Kafka and Debezium Connect.
2. The PostgreSQL connector was registered through Kafka Connect REST API.
3. The connector and its task reached `RUNNING` state.
4. Debezium created the topic `fb.cdc_lab.customers_cdc_test`.
5. Initial snapshot events arrived in Kafka with `op = r`.
6. PostgreSQL INSERT produced a Kafka event with `op = c`.
7. PostgreSQL UPDATE produced a Kafka event with `op = u`.
8. PostgreSQL DELETE produced a Kafka event with `op = d`.

---

## Conclusion

The local Debezium CDC environment was successfully set up.

PostgreSQL writes were captured by the Debezium PostgreSQL connector and delivered to Kafka topic `fb.cdc_lab.customers_cdc_test`.

The experiment verified CDC for initial snapshot, INSERT, UPDATE and DELETE operations.

This proves that the pipeline:

```text
PostgreSQL -> Debezium -> Kafka
```

works correctly in the local Docker Compose environment.
