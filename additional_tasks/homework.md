# Homework

## Cel

Samodzielnie rozbuduj pipeline PySpark z lekcji. Zadanie ma sprawdzić, czy potrafisz dobrać funkcje na podstawie dokumentacji, a nie tylko odtworzyć kod z zajęć.

Pracuj w kopii notebooka z lekcji.

## Minimum

### 1. Popraw Dane

Dodaj do danych wejściowych trzy rekordy:

- opłacone zamówienie z poprawną kwotą,
- zamówienie z `amount = "invalid"`,
- zamówienie z brakującym `customer_id`.

Zbuduj transformację, która:

- standaryzuje status i kanał,
- zmienia datę i kwotę na właściwe typy,
- nie usuwa po cichu błędnych rekordów,
- dodaje `data_quality_status` o wartości `VALID` albo `INVALID`.

### 2. Dodaj Metryki Jakości

Przygotuj DataFrame z jednym rekordem zawierającym:

- `input_rows`,
- `invalid_amount_rows`,
- `missing_customer_id_rows`,
- `valid_paid_rows`.

### 3. Przygotuj Agregat

Dla poprawnych opłaconych zamówień przygotuj wynik o grain:

```text
jeden dzień + jeden kanał
```

Kolumny:

- `order_date`,
- `channel`,
- `orders_count`,
- `revenue`,
- `average_order_value`.

### 4. Wyjaśnij Wykonanie

W 5-8 zdaniach odpowiedz:

1. Które operacje w Twoim pipeline są transformations?
2. Które actions uruchomiłeś?
3. Dlaczego nie użyłeś `collect()` do podglądu całego wyniku?
4. Co oznacza partition?
5. Kiedy w Twoim notebooku powstał job?

## Rozszerzenie

Znajdź w oficjalnej dokumentacji PySpark jedną funkcję, której nie używaliśmy na lekcji, i zastosuj ją sensownie w pipeline.

W komentarzu podaj:

- nazwę funkcji,
- link do dokumentacji,
- problem, który rozwiązuje,
- przykład wyniku przed i po transformacji.

Możliwe kierunki: `regexp_replace`, `date_format`, `greatest`, `least`, `count_if`.

## Kryteria Oddania

Oddaj:

- notebook możliwy do uruchomienia od początku przez `Run all`,
- wynik DataFrame z metrykami jakości,
- końcowy agregat,
- odpowiedzi dotyczące modelu wykonania,
- krótką informację, co sprawiło Ci największą trudność.

Rozwiązanie jest poprawne, jeśli:

- błędne rekordy są widoczne i mierzalne,
- agregat ma wymagany grain,
- liczby można odtworzyć z danych wejściowych,
- kod wykorzystuje funkcje wbudowane PySpark,
- ponowne wykonanie notebooka daje ten sam wynik.

