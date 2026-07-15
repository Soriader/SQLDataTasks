# Task 1: Sprawdź dane i schema

## 1. Dlaczego `amount` i `order_date` są początkowo typu `string`?

Ponieważ podczas tworzenia `orders_raw_df` schemat został zdefiniowany ręcznie i dla obu kolumn użyto `StringType()`.

Spark nie próbuje wtedy automatycznie rozpoznać daty ani liczby.

## 2. Jakie identyfikatory partitions występują w małym DataFrame?

```text
partition_id = 0
```

Oznacza to, że wszystkie 6 rekordów znajduje się w jednej partycji.

## 3. Dlaczego liczba partitions może być inna u innej osoby albo w innym środowisku?

Liczba partycji zależy między innymi od:

- rodzaju compute, np. serverless albo klasyczny cluster,
- liczby dostępnych rdzeni,
- konfiguracji Sparka,
- sposobu utworzenia DataFrame,
- rozmiaru i źródła danych,
- wcześniejszych operacji takich jak `repartition()` lub `coalesce()`.

W tym przypadku dane pochodzą z małej listy utworzonej bezpośrednio w notebooku, dlatego jedna partycja jest normalnym wynikiem.

Nie należy jednak zakładać, że zawsze będzie to `partition_id = 0`.

---

# Task 4: Transformation czy Action?

## Transformation

```python
high_value_df = paid_orders_df.filter(F.col("amount") >= 200)
```

## Actions

```python
high_value_df.count()
high_value_df.show(10, truncate=False)
high_value_df.collect()
```

## 1. Która linia po raz pierwszy uruchomi obliczenia?

```python
high_value_df.count()
```

## 2. Gdzie trafiają dane zwrócone przez `collect()`?

`collect()` pobiera wszystkie rekordy DataFrame do pamięci procesu sterującego.

## 3. Dlaczego `collect()` może być niebezpieczne przy dużym DataFrame?

Ponieważ dane przestają być rozproszone.

Spark może mieć dane rozłożone na wielu workerach, ale `collect()` próbuje zgromadzić całość w jednej pamięci.

Przy dużym DataFrame może to spowodować:

- przekroczenie pamięci,
- błąd `OutOfMemory`,
- bardzo duży transfer przez sieć,
- zawieszenie lub spowolnienie notebooka,
- przerwanie sesji.

## 4. Co stałoby się z `O-103` po użyciu `inner join`?

Po użyciu `inner join` rekord `O-103` zostałby całkowicie usunięty, ponieważ nie ma dopasowania po `customer_id`.


## Pytania Na Koniec

1. Która operacja zmieniła typ kolumny amount?
`.cast(T.DecimalType(12, 2))` 

2. Dlaczego po joinie sprawdziliśmy liczbę rekordów?
Po joinie sprawdziliśmy liczbę rekordów, aby upewnić się, że left join nie usunął żadnego zamówienia oraz 
nie powielił rekordów z powodu wielu dopasowań po customer_id.

   
3. Co oznacza jeden rekord agregatu?
oznacza jedną unikalną kombinację: order_date + country czyli 

Dla kraju PL w dniu 2026-07-01 wystąpiło jedno unikalne zamówienie, a łączny przychód wyniósł 120.50.

4. Która linia po raz pierwszy wymusiła wykonanie planu?
`display(orders_raw_df)` 

5. Dlaczego nie używamy collect() do zwykłego podglądu dużych danych?

collect() pobiera wszystkie rekordy z rozproszonych partycji do pamięci drivera lub klienta notebooka. Przy dużym DataFrame może to spowodować duży transfer sieciowy, przekroczenie pamięci, spowolnienie notebooka albo błąd OutOfMemory.

