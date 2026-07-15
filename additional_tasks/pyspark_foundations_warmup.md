# Warmup: Przewidź Zachowanie Pipeline'u

Nie uruchamiaj jeszcze kodu. Najpierw przeanalizuj go wspólnie z mentorem.

## Dane

```text
order_id | customer_id | status       | amount
O-101    | C-01        | " paid "     | "120.50"
O-102    | C-02        | "PENDING"    | null
O-103    | C-99        | "paid"       | "210.25"
O-104    | C-01        | "cancelled"  | "80.00"
```

Tabela klientów zawiera `C-01`, `C-02` i `C-03`. Nie zawiera `C-99`.

## Fragment Kodu

```python
result_df = (
    orders_df
    .withColumn("status", F.upper(F.trim(F.col("status"))))
    .withColumn("amount", F.col("amount").cast("double"))
    .filter(F.col("status") == "PAID")
    .join(customers_df, on="customer_id", how="left")
)
```

## Pytania

1. Ile rekordów znajdzie się w `result_df`?
2. Jakie `order_id` pozostaną?
3. Co stanie się z rekordem `O-103`, jeśli klient `C-99` nie istnieje?
4. Jaki typ będzie miała kolumna `amount`?
5. Czy sam zapis `result_df = (...)` musi już uruchomić przetwarzanie danych?
6. Które operacje są transformations?
7. Podaj action, którym bezpiecznie podejrzysz maksymalnie 10 rekordów.
8. Dlaczego `left join` może być bezpieczniejszy niż `inner join` w tym przypadku?

## Decyzja Data Engineera

Czy brak klienta dla `O-103` powinien:

- usunąć zamówienie,
- zatrzymać cały pipeline,
- pozostawić zamówienie i zostać zmierzony jako problem jakości?

Nie ma jednej odpowiedzi dla każdego systemu. Uzasadnij decyzję dla raportu sprzedaży.

