# Databricks notebook source
# MAGIC %md
# MAGIC # Lesson 8: PySpark Foundations Workshop
# MAGIC
# MAGIC Zadania wykonuj według `pyspark_foundations_live_coding.md`.
# MAGIC Komórki z `TODO` uzupełnia student.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql import types as T

# COMMAND ----------

order_schema = T.StructType(
    [
        T.StructField("order_id", T.StringType(), False),
        T.StructField("customer_id", T.StringType(), True),
        T.StructField("order_date", T.StringType(), True),
        T.StructField("status", T.StringType(), True),
        T.StructField("channel", T.StringType(), True),
        T.StructField("amount", T.StringType(), True),
    ]
)

orders_data = [
    ("O-101", "C-01", "2026-07-01", " paid ", " WEB ", "120.50"),
    ("O-102", "C-02", "2026-07-01", "PENDING", "mobile", None),
    ("O-103", "C-99", "2026-07-02", "paid", "web", "210.25"),
    ("O-104", "C-01", "2026-07-02", "cancelled", "store", "80.00"),
    ("O-105", "C-03", "2026-07-02", "PAID", " STORE", "310.00"),
    ("O-106", "C-01", "2026-07-03", "PAID", None, "99.99"),
]

orders_raw_df = spark.createDataFrame(orders_data, schema=order_schema)

# COMMAND ----------

customer_schema = T.StructType(
    [
        T.StructField("customer_id", T.StringType(), False),
        T.StructField("customer_name", T.StringType(), False),
        T.StructField("country", T.StringType(), False),
    ]
)

customers_data = [
    ("C-01", "Northwind Labs", "PL"),
    ("C-02", "Blue Meadow", "PL"),
    ("C-03", "Rhein Handel", "DE"),
]

customers_df = spark.createDataFrame(customers_data, schema=customer_schema)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 1: Dane I Schema

# COMMAND ----------

orders_raw_df.printSchema()
display(orders_raw_df)
(
    orders_raw_df
    .select(F.spark_partition_id().alias("partition_id"))
    .distinct()
    .show()
)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 2: Czyszczenie

# COMMAND ----------

# TODO: uzupełnij transformations zgodnie z wymaganiami Task 2.
orders_clean_df = orders_raw_df

display(orders_clean_df)
orders_clean_df.printSchema()

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 3: Reguły Biznesowe

# COMMAND ----------

# TODO: dodaj amount_band, is_paid i processed_at.
orders_enriched_df = orders_clean_df

# TODO: pozostaw tylko poprawne opłacone zamówienia.
paid_orders_df = orders_enriched_df

display(paid_orders_df)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 4: Lazy Evaluation I Plan

# COMMAND ----------

high_value_df = paid_orders_df.filter(F.col("amount") >= 200)

# TODO: uruchom bezpieczną action i obejrzyj wynik.

# COMMAND ----------

high_value_df.explain(mode="formatted")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 5: Samodzielny Join

# COMMAND ----------

# TODO: wykonaj left join i dodaj customer_match_status.
enriched_orders_df = paid_orders_df

display(enriched_orders_df)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 6: Samodzielna Agregacja

# COMMAND ----------

# TODO: przygotuj agregat o grain: jeden dzień i jeden kraj.
daily_country_sales_df = enriched_orders_df

display(daily_country_sales_df)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 7: Spark SQL - Opcjonalnie

# COMMAND ----------

# TODO: zarejestruj temporary view.

# COMMAND ----------

# MAGIC %sql
# MAGIC -- TODO: policz opłacone zamówienia per kraj.
