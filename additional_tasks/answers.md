Task 1: Sprawdź Dane I Schema

1.Dlaczego amount i order_date są początkowo typu string?
Ponieważ podczas tworzenia orders_raw_df schemat został zdefiniowany ręcznie 
i dla obu kolumn użyto StringType(). 
Spark nie próbuje wtedy automatycznie rozpoznać daty ani liczby.

2.Jakie identyfikatory partitions występują w małym DataFrame?
partition_id = 0 czyli wszystkie 6 rekordów znajduje się więc w jednej partycji.

3.Dlaczego liczba partitions może być inna u innej osoby albo w innym środowisku?
Liczba partycji zależy między innymi od:

rodzaju compute, np. serverless albo klasyczny cluster,
liczby dostępnych rdzeni,
konfiguracji Sparka,
sposobu utworzenia DataFrame,
rozmiaru i źródła danych,
wcześniejszych operacji takich jak repartition lub coalesce.

W tym przypadku dane pochodzą z małej listy utworzonej bezpośrednio w notebooku, 
dlatego jedna partycja jest normalnym wynikiem. 
Nie należy jednak zakładać, że zawsze będzie to partition_id = 0.