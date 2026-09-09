# ZbiorKom Baza TV

ZbiorKom Baza TV to aplikacja na Apple TV, która zamienia telewizor w pełnoekranową tablicę odjazdów krakowskiej komunikacji miejskiej. Użytkownik wybiera przystanek i słupek, a aplikacja wyświetla najbliższe planowane odjazdy autobusów i tramwajów.

Projekt powstał jako telewizyjna wersja ZbiorKom Baza, z interfejsem dostosowanym do obsługi pilotem Apple TV.

## Podgląd

### Tablica odjazdów

### Ustawienia i wybór przystanku

## Funkcje

* Pełnoekranowa tablica odjazdów z czarnym tłem i bursztynowymi napisami.
* Wybór przystanku z listy i wyszukiwanie po nazwie.
* Wybór konkretnego słupka lub wszystkich słupków danego przystanku.
* Wspólna tablica odjazdów autobusów i tramwajów.
* Wyświetlanie numeru linii, kierunku i czasu pozostałego do odjazdu.
* Zegar aktualizowany na bieżąco.
* Ulubione tablice zapisujące parę: przystanek + słupek.
* Szybkie przełączanie między ulubionymi tablicami.
* Zapamiętywanie ostatnio wybranego przystanku i słupka.
* Ręczne odświeżanie odjazdów.
* Pobieranie aktualnych rozkładów GTFS.
* Interfejs ustawień dostosowany do obsługi pilotem.

## Jak działa

Po uruchomieniu aplikacja wyświetla ostatnio wybraną tablicę. Przycisk **Ustawienia** pozwala zmienić przystanek i słupek, wybrać jedną z ulubionych tablic lub pobrać aktualne rozkłady.

Odliczanie jest aktualizowane na bieżąco, natomiast lista najbliższych odjazdów jest okresowo przeliczana na podstawie zapisanych danych GTFS.

## Źródło danych

Aplikacja korzysta z danych GTFS udostępnianych przez Zarząd Transportu Publicznego w Krakowie:

[gtfs.ztp.krakow.pl](https://gtfs.ztp.krakow.pl)

**Uwaga:** obecna wersja wyświetla planowane odjazdy wynikające z rozkładu jazdy. Nie są to dane o rzeczywistych opóźnieniach pojazdów.

## Technologie

* Swift
* SwiftUI
* tvOS
* GTFS
* ZIPFoundation
* UserDefaults

## Uruchomienie projektu

1. Otwórz projekt w Xcode.
2. Upewnij się, że pakiet `ZIPFoundation` jest dodany do targetu tvOS.
3. Wybierz symulator Apple TV lub podłączone urządzenie.
4. Uruchom aplikację.
5. Pobierz rozkłady i wybierz przystanek oraz słupek.

## Status

Projekt jest w trakcie rozwoju. Obecnie skupia się na wyświetlaniu planowanych odjazdów i wygodnej obsłudze tablicy na Apple TV.

## Autor

Jan Doniec
