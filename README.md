# NaviMot GO

**NaviMot GO** — nawigacja i planowanie malowniczych tras motocyklowych z pogodą i miejscami ważnymi dla motocyklisty.

Aplikacja działa w przeglądarce (Flutter Web). Można ją też uruchomić lokalnie na Androida/iOS.

## ✨ Funkcje

- **Planowanie trasy** — wyznaczanie trasy motocyklowej (OSRM, profil rowerowy/scenic), punkty pośrednie
- **Mapa** — podgląd trasy z animacją rysowania, znaczniki miejsc, panel podsumowania
- **Przegląd offline** — zapisane trasy przeglądasz bez internetu (widok rysowany lokalnie, trasy trwają między uruchomieniami)
- **Nawigacja** — widok 2D drogi z komunikatem głosowym (TTS) i obrotem wg kierunku jazdy
- **Pogoda** — prognoza wzdłuż trasy (temperatura, wiatr, opady, warunki)
- **Miejsca dla motocyklisty** — punkty widokowe, przełęcze górskie, malownicze drogi, stacje paliw, serwisy motocyklowe, noclegi i restauracje w promieniu 10 km od trasy (OpenStreetMap/Overpass); z listy możesz pokazać wybrane miejsce na mapie
- **Zapisywanie tras** — zapis ulubionych tras na urządzeniu
- **Ocena malowniczości** — punktacja trasy na podstawie charakteru dróg

## 🔗 Testuj online

Aplikacja działa w przeglądarce na **GitHub Pages** — kliknij i testuj bez instalowania czegokolwiek:

**👉 https://Jc0o0b.github.io/NaviMot-GO/**

To zawsze najnowsza wersja z gałęzi `main`. Zgłaszaj uwagi i pomysły w zakładce **Issues**.

> 💡 Jeśli otworzysz aplikację w telefonie przez przeglądarkę, działa ona również jako aplikacja (Add to Home Screen).

## 🛠 Technologie

- Flutter (Material 3, motyw deepOrange)
- `flutter_map` + OpenStreetMap
- OSRM (wyznaczanie trasy)
- Open-Meteo (pogoda)
- Overpass API / OpenStreetMap (POI)
- provider (zarządzanie stanem)

## 🚀 Uruchomienie lokalnie

```bash
# 1. Zainstaluj zależności
flutter pub get

# 2. Uruchom w przeglądarce
flutter run -d web-server --web-port 8088
```

Następnie otwórz http://localhost:8088

### Wersja produkcyjna (web)

```bash
flutter build web --release --base-href=/NaviMot-GO/
```

### Android

```bash
flutter build apk --release
```

## 📁 Struktura projektu

```
lib/
├── main.dart                 # Wejście aplikacji, splash, motyw
├── models/                   # Modele: trasa, pogoda, POI, krok nawigacji
├── providers/                # Stan: trasa, pogoda, POI, ustawienia
├── screens/                  # Ekrany: splash, mapa, planowanie, nawigacja, pogoda, miejsca, zapisane
├── services/                 # Integracje: OSRM, Open-Meteo, Overpass, TTS, GPS, geokodowanie
├── utils/                    # Pomocnicze: skala trasy, ocena malowniczości, stałe
└── widgets/                  # Komponenty: logo, widok drogi 2D, markery, ikony pogody
```

## 📦 Deploy na GitHub Pages

Workflow `.github/workflows/pages.yml` automatycznie buduje wersję web i publikuje ją po każdym `push` na gałąź `main`. Wymaga włączonego źródła **GitHub Actions** w ustawieniach repozytorium (Settings → Pages).

## 📄 Licencja

Projekt bez licencji — dostępny do celów testowych i nauki.
