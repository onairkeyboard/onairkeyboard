<p align="center">
  <img src="assets/logo-on-dark.svg" alt="OnAirKey" height="90">
</p>

<h3 align="center">Jeden klawisz. Zero zgadywania.</h3>

<p align="center">
  Dioda na klawiaturze świeci na czerwono, gdy Wispr Flow nagrywa.
</p>

<p align="center">
  <a href="https://github.com/onairkey/onairkey/releases/latest"><img src="https://img.shields.io/badge/Pobierz-OnAirKey.exe-1F1E1D?logo=windows&logoColor=white" alt="Pobierz"></a>
  <a href="https://onairkey.com"><img src="https://img.shields.io/badge/onairkey.com-strona-E24B4A" alt="Strona"></a>
  <a href="https://buycoffee.to/onairkey"><img src="https://img.shields.io/badge/Buycoffee.to-wesprzyj-6F4E37?logo=buymeacoffee&logoColor=white" alt="Buycoffee.to"></a>
  <a href="https://github.com/sponsors/onairkey"><img src="https://img.shields.io/badge/GitHub_Sponsors-wesprzyj-ea4aaa?logo=githubsponsors&logoColor=white" alt="GitHub Sponsors"></a>
  <img src="https://img.shields.io/badge/licencja-MIT-blue" alt="Licencja MIT">
</p>

<p align="center">Polski · <a href="README.md">English</a></p>

---

## Po co to

Dyktowanie z [Wispr Flow](https://wisprflow.ai) i podobnymi programami potrafi kilkukrotnie
przyspieszyć pracę. Ale skróty w stylu `Ctrl+Win+Space` to gimnastyka dla palców, a brak sygnału,
czy nagrywanie trwa, kończy się klasyką: kilka minut monologu, który nigdy się nie nagrał, albo
rozmowa, która nagrywa się w najlepsze.

OnAirKey zamienia małą klawiaturę makro w pilota do dyktowania: osobny klawisz na każdą funkcję
i lampka, która świeci na czerwono dokładnie wtedy, gdy jesteś „na antenie”. Jedno naciśnięcie
i od razu wiesz, co się dzieje.

<p align="center"><img src="docs/img/settings-howto-pl.png" alt="Ustawienia OnAirKey: Jak to działa" width="600"></p>

## Co potrafi

- **Dioda klawiatury jako lampka „na antenie”.** Działa z każdą klawiaturą, której diody umieją
  pokazywać stan Locka (np. klawiatury makro SayoDevice): domyślnie Scroll Lock, do wyboru Num Lock
  albo Caps Lock.
- **Czerwona ikona w zasobniku podczas nagrywania**, więc OnAirKey pomaga także bez diody.
- **Wszystkie akcje nagrywania Wispr Flow:** Push to talk, Hands-free, Cancel i Command Mode.
- **Skróty nagrywasz, naciskając je**, także F13–F24 i domyślne skróty Wispr, np. `Ctrl+Win`.
- **Po polsku i po angielsku**, uruchamia się z Windows, jeden mały plik EXE bez instalatora.
- **Prywatny z założenia:** OnAirKey tylko nasłuchuje Twoich skrótów. Niczego nie blokuje, nie czyta
  tekstu, nie zbiera danych i nie łączy się z internetem.

## Wymagania

- Windows 10 lub 11
- [Wispr Flow](https://wisprflow.ai) na komputer
- Opcjonalnie: klawiatura, której diody mogą pokazywać stan Locka (bez niej działa ikona w zasobniku)

## Pierwsze kroki

**0. Pobierz** `OnAirKey.exe` z [Releases](https://github.com/onairkey/onairkey/releases/latest)
i uruchom. Przy pierwszym starcie okno ustawień otworzy się na zakładce *Jak to działa*.

> Windows może pokazać „System Windows ochronił ten komputer”, bo plik nie ma jeszcze podpisu
> cyfrowego. Kliknij **Więcej informacji → Uruchom mimo to**. Zobacz
> [SmartScreen i antywirusy](#smartscreen-i-antywirusy).

**1. Klawiatura.** W programie klawiatury przypisz każdemu klawiszowi skrót, a diody ustaw na
wskaźnik Locka. Przykład dla 4-klawiszowej klawiatury SayoDevice:

| Klawisz | Skrót | Akcja w Wispr Flow | Dioda |
|---|---|---|---|
| 1 | `Ctrl+Shift+F16` | Cancel | Indicator → Scroll Lock |
| 2 | `Ctrl+Shift+F15` | Paste last transcript | Indicator → Scroll Lock |
| 3 | `Ctrl+Shift+F13` | Push to talk | Indicator → Scroll Lock |
| 4 | `Ctrl+Shift+F14` | Hands-free | Indicator → Scroll Lock |

Klawisze F13–F24 istnieją w standardzie USB, ale nie ma ich na zwykłych klawiaturach, więc nie
kolidują z innymi programami.

> **Masz SayoDevice 2x2?** Pomiń ręczną konfigurację: pobierz
> [WisprFlow_2x2.sayobak](presets/WisprFlow_2x2.sayobak), kopię zapasową z dokładnie takimi
> klawiszami i diodami jak w tabeli powyżej.
>
> 1. Otwórz [sayodevice.com](https://sayodevice.com) w Chrome albo Edge (inne przeglądarki nie
>    połączą się z klawiaturą) i podłącz klawiaturę makro.
> 2. Wejdź w **Backup & Restore → Restore**, wybierz pobrany plik, zaznacz, co przywrócić
>    (klawisze i podświetlenie), i potwierdź.
>
> Jeśli program ostrzeże, że kopia nie pasuje do urządzenia, masz inny model: anuluj i ustaw
> klawisze ręcznie.

**2. OnAirKey.** W zakładce *Skróty* kliknij **Nagraj** przy każdej akcji i naciśnij klawisz na
klawiaturze makro. Paste last transcript nie trzeba nagrywać, bo nie zmienia stanu nagrywania.

<p align="center"><img src="docs/img/settings-shortcuts-pl.png" alt="Ustawienia OnAirKey: Skróty" width="600"></p>

**3. Wispr Flow.** W *Settings → General → Shortcuts* ustaw te same skróty dla Push to talk,
Hands-free i Cancel.

Gotowe: naciśnij Push to talk albo Hands-free, a dioda zaświeci na czerwono.

## Dlaczego tylko cztery przyciski?

Umówmy się: Wispr Flow potrafi dużo więcej. Ale większość ludzi nie korzysta z tych bajerów, tylko
rozmawia ze swoim AI za pomocą podstaw: **Push to talk, Hands-free i Cancel**. Jest jeszcze Command
Mode i OnAirKey też go obsługuje, ale na pewno używa się go dużo rzadziej. Czwarty klawisz na
klawiaturze trafia do **Paste last transcript** (o tym niżej).

OnAirKey to konkretne rozwiązanie konkretnego problemu dla konkretnej grupy użytkowników, a nie
uniwersalny kombajn do wszystkiego. Może kiedyś pokusimy się o bardziej uniwersalną wersję, ale na
pewno nie teraz, bo to nie jest teraz istotne.

## Dlaczego Wispr Flow?

Korzystałem z kilku alternatywnych narzędzi i uważam, że Wispr Flow działa najlepiej ze wszystkich.
Sam używam go na co dzień, a OnAirKey powstał dokładnie pod to, jak z nim pracuję.

## Dlaczego Paste last transcript na czwartym klawiszu?

Każdemu się zdarza: dyktujesz, ale kursor nie stał w polu tekstowym (albo okno straciło fokus)
i tekst nigdzie nie trafił. Wispr Flow go pamięta. Kliknij w pole, naciśnij czwarty klawisz i ostatnie
dyktowanie się pojawi. Bez przepisywania, bez mówienia wszystkiego od nowa i bez zapamiętywania skrótu.

OnAirKey nie musi znać tego klawisza: wklejanie nie zmienia stanu nagrywania.

## Dlaczego nie Escape?

Domyślny Cancel w Wispr Flow to `Escape`, ale Escape przerywa też inne programy. Jeśli Claude Code
czy ChatGPT właśnie pracuje, jednym naciśnięciem anulujesz dyktowanie i zatrzymasz pracę AI.
Przypisz Cancel do osobnego klawisza na klawiaturze makro. OnAirKey obsługuje Escape, ale ostrzega
przed nim.

## Warto wiedzieć

- **OnAirKey śledzi Twoje skróty, a nie samego Wispr.** Jeśli nagrywanie zmieni się inaczej
  (podwójne naciśnięcie Push to talk, zatrzymanie myszką w Flow Bar, automatyczny koniec po
  20 minutach), dioda może zostać zapalona. Naciśnij Cancel i wszystko wraca do normy.
- **Lock naprawdę się przełącza.** Gdy wskaźnikiem jest Scroll Lock, strzałki w Excelu przewijają
  arkusz podczas dyktowania. Przy Caps Locku litery będą wielkie.
- Skrót może mieć jeden klawisz oprócz Ctrl / Alt / Shift / Win (Wispr pozwala też na dwa, np.
  `Ctrl+A+B`; OnAirKey jeszcze nie).
- Jeśli wyskakuje powiadomienie „Scroll Lock włączony”, pochodzi ono z programu myszy lub
  klawiatury (np. Logitech SetPoint), a nie z Windows. Wyłączysz je w tamtym programie.

## SmartScreen i antywirusy

OnAirKey jest napisany w [AutoHotkey](https://www.autohotkey.com) i skompilowany do pliku EXE.
Takie pliki nie mają jeszcze podpisu cyfrowego, więc Windows SmartScreen ostrzega przed nimi,
a niektóre antywirusy mylnie je oznaczają, zwłaszcza że program nasłuchuje klawiatury. Pełny kod
źródłowy jest w tym repozytorium i możesz [zbudować EXE samodzielnie](#budowanie-ze-źródeł).

## Ustawienia i odinstalowanie

Ustawienia są w `%APPDATA%\OnAirKey\config.ini` (ścieżkę pokazuje zakładka *O programie*). Żeby
usunąć OnAirKey: odznacz *Uruchamiaj z Windows*, zamknij program z menu w zasobniku, a potem usuń
`OnAirKey.exe` i folder `%APPDATA%\OnAirKey`.

## Budowanie ze źródeł

Wymagania: [AutoHotkey v2.0](https://www.autohotkey.com) i Ahk2Exe 1.1.37 lub nowszy
(instaluje go AutoHotkey Dash → Compile).

```powershell
powershell -ExecutionPolicy Bypass -File tests\run.ps1      # testy
powershell -ExecutionPolicy Bypass -File build.ps1          # dist\OnAirKey.exe
powershell -ExecutionPolicy Bypass -File tests\run.ps1 -Exe # testy łącznie z EXE
powershell -ExecutionPolicy Bypass -File tools\run-demo.ps1 # uruchomienie ze źródeł
```

Ikony powstają z `assets/src` poleceniem `python -I assets/build_icons.py` (wymaga Inkscape).

## Wesprzyj

Cześć, tu Patryk Szulczewski. Stworzyłem OnAirKey, aby uprościć sobie życie. Jeśli udało mi się
uprościć również Twoje, to poniżej masz okazję, aby mi się odwdzięczyć:

<a href="https://buycoffee.to/onairkey"><img src="https://img.shields.io/badge/Buycoffee.to-wesprzyj-6F4E37?logo=buymeacoffee&logoColor=white" alt="Buycoffee.to"></a>
<a href="https://github.com/sponsors/onairkey"><img src="https://img.shields.io/badge/GitHub_Sponsors-wesprzyj-ea4aaa?logo=githubsponsors&logoColor=white" alt="GitHub Sponsors"></a>

Więcej o OnAirKey: [onairkey.com](https://onairkey.com)

## Licencja

[MIT](LICENSE) © 2026 Patryk Szulczewski

OnAirKey to niezależny projekt, niepowiązany z Wispr AI (Wispr Flow) ani z SayoDevice.
