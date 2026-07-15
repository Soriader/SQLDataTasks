# Databricks notebook source
# MAGIC %md
# MAGIC # Lesson 8: PySpark Foundations Workshop
# MAGIC
# MAGIC Zadania wykonuj według `pyspark_foundations_live_coding.md`.
# MAGIC Komórki z `TODO` uzupełnia student.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql import types as T
from pyspark.sql.types import DecimalType
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
# TODO: uzupełnij transformations zgodnie z wymaganiami Task 2.
orders_clean_df = orders_raw_df


orders_clean_df = orders_raw_df.select(
    F.col("order_id"),
    F.col("customer_id"),
    F.upper(
        F.trim(F.col("status"))
    ).alias("status"),

    F.coalesce(
        F.lower(F.trim(F.col("channel"))),
        F.lit("unknown")
    ).alias("channel"),

    F.to_date(
        F.col("order_date"),
        "yyyy-MM-dd"
    ).alias("order_date"),

    F.col("amount")
     .cast(DecimalType(12, 2))
     .alias("amount")
)


display(orders_clean_df)
orders_clean_df.printSchema()
# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 3: Reguły Biznesowe

# COMMAND ----------

# TODO: dodaj amount_band, is_paid i processed_at.
orders_enriched_df = orders_clean_df.select(
    F.col("order_id"),
    F.col("customer_id"),
    F.col("status"),
    F.col("channel"),
    F.col("order_date"),

    "amount", F.when(
        F.col("amount") >= 200,
        F.lit("HIGH")
    ).otherwise(
        F.lit("STANDARD")
    ).alias("amount_band"),

    (F.col("status") == "PAID").alias("is_paid"),

    F.current_timestamp().alias("processed_at")
)

# TODO: pozostaw tylko poprawne opłacone zamówienia.
paid_orders_df = orders_enriched_df.filter(
    F.col("amount").isNotNull() & F.col("is_paid")
)

display(paid_orders_df)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 4: Lazy Evaluation I Plan

# COMMAND ----------

high_value_df = paid_orders_df.filter(F.col("amount") >= 200)

# TODO: uruchom bezpieczną action i obejrzyj wynik.

high_value_df.show()


# COMMAND ----------

high_value_df.explain(mode="formatted")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 5: Samodzielny Join

# COMMAND ----------

# TODO: wykonaj left join i dodaj customer_match_status.
enriched_orders_df = paid_orders_df.join(customers_df, on="customer_id", how="left")

enriched_orders_df = enriched_orders_df.withColumn(
     "customer_match_status", F.when(
    F.col("customer_name").isNull(),
    F.lit("MISSING")
    ).otherwise(
        F.lit("MATCHED")
    )
)

enriched_orders_df.count()
display(enriched_orders_df)


# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 6: Samodzielna Agregacja

# COMMAND ----------

# TODO: przygotuj agregat o grain: jeden dzień i jeden kraj.
daily_country_sales_df = (
    enriched_orders_df
    .filter(F.col("customer_match_status") == "MATCHED")
    .groupBy(
        "order_date",
        "country"
    )
    .agg(
        F.countDistinct("order_id").alias("orders_count"),
        F.round(F.sum("amount"), 2).alias("revenue")
    )
    .sort("order_date", "country")
)

display(daily_country_sales_df)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Task 7: Spark SQL - Opcjonalnie

# COMMAND ----------

# TODO: zarejestruj temporary view.

# COMMAND ----------

# MAGIC %sql
# MAGIC -- TODO: policz opłacone zamówienia per kraj.
