# Lab: PySpark Foundations

Pracuj w notebooku:

```text
pyspark_foundations_workshop.py
```

Zadania 1-4 wykonujecie wspólnie. Zadania 5-6 wykonujesz samodzielnie.

## Task 1: Sprawdź Dane I Schema

Uruchom komórki przygotowujące `orders_raw_df` i `customers_df`.

Sprawdź:

```python
orders_raw_df.printSchema()
display(orders_raw_df)
```

Odpowiedz:

1. Dlaczego `amount` i `order_date` są początkowo typu `string`?
2. Jakie identyfikatory partitions występują w małym DataFrame?
3. Dlaczego liczba partitions może być inna u innej osoby albo w innym środowisku?

Sprawdź:

```python
(
    orders_raw_df
    .select(F.spark_partition_id().alias("partition_id"))
    .distinct()
    .show()
)
```

Nie używamy `orders_raw_df.rdd`, ponieważ serverless compute korzysta ze Spark Connect i nie obsługuje klasycznego RDD API.

## Task 2: Wybierz I Oczyść Kolumny

Utwórz `orders_clean_df`.

Wymagania:

- wybierz kolumny potrzebne w dalszym pipeline,
- usuń spacje i zamień `status` na wielkie litery,
- usuń spacje i zamień `channel` na małe litery,
- zamień `order_date` na `date`,
- zamień `amount` na `decimal(12,2)`,
- zamień brakujący `channel` na `unknown`.

Użyj:

- `select`,
- `alias`,
- `trim`,
- `upper`,
- `lower`,
- `to_date`,
- `cast`,
- `coalesce`.

**Expected result:**

- 6 rekordów,
- `order_date` ma typ `date`,
- `amount` ma typ `decimal(12,2)`,
- statusy nie mają spacji,
- brakujący kanał ma wartość `unknown`.

## Task 3: Dodaj Reguły Biznesowe

Dodaj:

- `amount_band`:
  - `HIGH`, jeśli `amount >= 200`,
  - `STANDARD` w przeciwnym przypadku,
- `is_paid`: `true`, jeśli status to `PAID`,
- `processed_at`: aktualny timestamp.

Następnie utwórz `paid_orders_df`, zawierający tylko opłacone zamówienia z niepustym `amount`.

**Expected result:**

- 4 opłacone zamówienia,
- `O-103` ma `amount_band = HIGH`,
- `O-106` ma kanał `unknown`.

## Task 4: Transformation Czy Action?

Przed uruchomieniem kolejnych linii zdecyduj, które z nich są transformations, a które actions:

```python
high_value_df = paid_orders_df.filter(F.col("amount") >= 200)
high_value_df.count()
high_value_df.show(10, truncate=False)
high_value_df.collect()
```

Nie uruchamiaj `collect()` jako standardowego sposobu podglądu danych. Wyjaśnij, gdzie trafia wynik tej operacji.

Wyświetl plan:

```python
high_value_df.explain(mode="formatted")
```

Na tym etapie znajdź w planie nazwy operacji `Filter` i `Project`. Szczegółową analizę planu wykonamy w lekcji 9.

## Task 5: Join

Wzbogać `paid_orders_df` danymi z `customers_df`.

Wymagania:

- użyj `left join`,
- kluczem jest `customer_id`,
- wynik nazwij `enriched_orders_df`,
- dodaj `customer_match_status`:
  - `MATCHED`, jeśli znaleziono klienta,
  - `MISSING`, jeśli klienta nie znaleziono.

**Expected result:**

- wynik nadal ma 4 rekordy,
- `O-103` ma `customer_match_status = MISSING`,
- pozostałe opłacone zamówienia mają `MATCHED`.

Pytanie kontrolne:

> Co stałoby się z `O-103` po użyciu `inner join`?

## Task 6: Agregacja

Na podstawie dopasowanych rekordów przygotuj `daily_country_sales_df`.

Wymagania:

- uwzględnij tylko `customer_match_status = MATCHED`,
- grain wyniku: jeden dzień i jeden kraj,
- kolumny:
  - `order_date`,
  - `country`,
  - `orders_count`,
  - `revenue`,
- `orders_count` policz jako liczbę unikalnych `order_id`,
- `revenue` zaokrąglij do 2 miejsc,
- posortuj wynik po `order_date` i `country`.

**Expected result:**

| order_date | country | orders_count | revenue |
|---|---|---:|---:|
| 2026-07-01 | PL | 1 | 120.50 |
| 2026-07-02 | DE | 1 | 310.00 |
| 2026-07-03 | PL | 1 | 99.99 |

## Task 7: Spark SQL

1. utwórz temporary view z `enriched_orders_df`,
2. przygotuj przez Spark SQL liczbę opłaconych zamówień per kraj,
3. porównaj wynik z DataFrame API.

## Pytania Na Koniec

1. Która operacja zmieniła typ kolumny `amount`?
2. Dlaczego po joinie sprawdziliśmy liczbę rekordów?
3. Co oznacza jeden rekord agregatu?
4. Która linia po raz pierwszy wymusiła wykonanie planu?
5. Dlaczego nie używamy `collect()` do zwykłego podglądu dużych danych?
