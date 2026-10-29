🌐 [English](../README.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Français](README.fr.md) · [Italiano](README.it.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · **Polski**

# M365 MFA Administration Tool

To narzędzie pozwala administratorom i pracownikom helpdesku konfigurować **uwierzytelnianie wieloskładnikowe (MFA) w imieniu innych użytkowników** – na przykład klucz FIDO2, kartę TOTP lub tymczasowy kod dostępu. Dodatkowo pokazuje na pierwszy rzut oka, jak dobrze chronione jest konto użytkownika.

> [!NOTE]
> Zrzuty ekranu przedstawiają interfejs w języku angielskim. Interfejs można przełączyć na język polski w prawym górnym rogu.

![Okno główne M365 MFA Administration Tool](images/en/main-window.png)

## Spis treści

- [W skrócie](#w-skrócie)
- [Szybki start](#szybki-start)
- [Instrukcja krok po kroku](#instrukcja-krok-po-kroku)
- [Którą metodę wybrać](#którą-metodę-wybrać)
- [Tworzenie konta awaryjnego](#tworzenie-konta-awaryjnego)
- [Instrukcja MFA e-mailem](#instrukcja-mfa-e-mailem)
- [Raport MFA dzierżawy](#raport-mfa-dzierżawy)
- [Masowy import tokenów TOTP](#masowy-import-tokenów-totp)
- [Inwentarz tokenów](#inwentarz-tokenów)
- [Masowy Temporary Access Pass](#masowy-temporary-access-pass)
- [Masowy offboarding](#masowy-offboarding)
- [Pomoc, ustawienia i aktualizacje](#pomoc-ustawienia-i-aktualizacje)
- [Często zadawane pytania i rozwiązywanie problemów](#często-zadawane-pytania-i-rozwiązywanie-problemów)
- [Bezpieczeństwo](#bezpieczeństwo)
- [Wymagania i uprawnienia dla administratorów](#wymagania-i-uprawnienia-dla-administratorów)
- [Struktura projektu](#struktura-projektu)
- [Dodawanie języka](#dodawanie-języka)

---

## W skrócie

| | Funkcja |
|---|---|
| 🔍 | **Wyszukiwanie użytkowników** – według nazwy, adresu e-mail, UPN lub identyfikatora obiektu |
| 🚦 | **Sygnalizator MFA** – od razu pokazuje, czy konto jest chronione dobrze, słabo czy wcale, wraz z zaleceniem |
| 👑 | **Role administratora** – pokazuje, czy użytkownik ma uprawnienia administracyjne |
| 📋 | **Przeglądanie i usuwanie metod MFA** – wszystkie zarejestrowane metody z datą i szczegółami |
| ➕ | **Konfigurowanie metod** – klucz FIDO2, karty TOTP, Temporary Access Pass i pozorne MFA |
| ✉️ | **Instrukcja MFA e-mailem** – wysyła użytkownikom bez MFA lub ze słabym MFA instrukcję krok po kroku dla aplikacji Microsoft Authenticator, w ich języku i z podglądem |
| 📊 | **Raport MFA dzierżawy** – stan MFA i ostatnie logowanie wszystkich użytkowników jako sygnalizacja świetlna, z wyszukiwaniem, filtrami i kolorowym eksportem do Excela |
| 📥 | **Masowy import TOTP** – import sprzętowych tokenów TOTP (SHA-1 lub SHA-256) z pliku CSV, z importem testowym, eksportem do Excela i cofaniem |
| 🗂️ | **Inwentarz tokenów** – wszystkie sprzętowe tokeny TOTP dzierżawy: przypisywanie wolnych tokenów, usuwanie przypisań, usuwanie |
| 🎫 | **Masowy TAP** – Temporary Access Pass dla wielu użytkowników naraz (CSV lub grupa) z eksportem do Excela |
| 🆘 | **Konto awaryjne** – tworzenie dostępu awaryjnego (break-glass) z kluczem FIDO2 i nieznanym hasłem |
| 🌐 | **Wielojęzyczność** – angielski (domyślnie), niemiecki, hiszpański, francuski, włoski, portugalski, niderlandzki i polski |

---

## Szybki start

1. Skopiuj cały folder na swój komputer (pliki muszą pozostać razem).
2. **Kliknij dwukrotnie `Start.cmd`.**
3. W prawym górnym rogu ustaw język na **Polski** i kliknij **„Zaloguj”**. Zaloguj się własnym kontem administratora.

> [!TIP]
> Aby mieć szybki dostęp, utwórz na pulpicie skrót do `Start.cmd` (prawy przycisk myszy → *Utwórz skrót*).

Przy pierwszym logowaniu narzędzie sprawdza, czy brakuje wymaganych składników. Jeśli tak, wyświetla ich listę i jednorazowo pyta, czy je zainstalować – instalacja odbywa się w tle (ok. minuty lub dwóch) i jest widoczna w dzienniku. Następnie Microsoft jednorazowo prosi o zgodę na uprawnienia narzędzia.

---

## Instrukcja krok po kroku

### 1. Wybór języka i logowanie

Interfejs uruchamia się w języku **angielskim**. Za pomocą pola wyboru w prawym górnym rogu, obok „Sign in”, można w każdej chwili zmienić język – bez ponownego uruchamiania. Wybór zostaje zapisany dla Twojego użytkownika Windows i zastosowany przy kolejnym uruchomieniu.

Kliknij **„Zaloguj”** w prawym górnym rogu. Po udanym logowaniu na zielono pojawi się *„Połączono jako …”* oraz dzierżawa. **„Wyloguj”** kończy sesję – dzieje się to również automatycznie po zamknięciu okna.

### 2. Wyszukiwanie użytkownika

W polu **„1. Wyszukaj użytkownika”** wpisz początek nazwy, adresu e-mail lub UPN i naciśnij **Enter** (lub kliknij **„Szukaj”**).

- **Jeden wynik:** użytkownik otwiera się od razu.
- **Kilka wyników:** pod polem wyszukiwania rozwija się lista – kliknij wybranego użytkownika. Klawisz **Esc** lub kliknięcie obok zamyka listę.

### 3. Odczytywanie stanu MFA

Po prawej stronie, w sekcji **„Wybrany użytkownik”**, **sygnalizator MFA** pokazuje, jak dobrze chronione jest konto:

| Sygnalizator | Znaczenie | Co zrobić? |
|---|---|---|
| 🟢 **Silne MFA (odporne na phishing)** | Jest klucz FIDO2, klucz dostępu lub Windows Hello | Wszystko w porządku. |
| 🟢 **Silne MFA** | Jest aplikacja Authenticator lub karta/aplikacja TOTP | W porządku. Dla administratorów zalecany jest dodatkowo FIDO2. |
| 🟡 **Tylko słabe MFA** | Tylko SMS lub połączenie | Skonfiguruj lepszą metodę, a następnie usuń SMS/połączenie. |
| 🟡 **Tylko pozorne MFA** | Konto jest zablokowane dla ochrony (zob. [pozorne MFA](#którą-metodę-wybrać)) | Skonfiguruj rzeczywistą metodę, aby z niego korzystać. |
| 🟡 **Tylko Temporary Access Pass** | Tylko tymczasowy kod dostępu | Użytkownik powinien teraz użyć go do skonfigurowania stałej metody. |
| 🔴 **Brak MFA – tylko hasło** | Brak drugiego składnika | Pilnie skonfiguruj metodę. |

Pod sygnalizatorem pojawiają się konkretne zalecenia, np. *„SMS/połączenie jest również zarejestrowane i można je usunąć”*.

Niżej sekcja **„Role administracyjne”** pokazuje, czy użytkownik ma uprawnienia administratora. Przycisk **„Pokaż”** rozwija listę. Dla każdej roli widać również, czy jest aktywna na stałe, przypisana przez grupę, czy tylko możliwa do aktywowania przez PIM.

### 4. Przeglądanie i usuwanie metod MFA

Po lewej stronie, w sekcji **„2. Zarejestrowane metody MFA”**, znajdują się wszystkie metody użytkownika. Kliknięcie metody wyświetla pod spodem **wszystkie szczegóły** (np. model urządzenia, numer seryjny, datę utworzenia).

Aby usunąć metodę, zaznacz ją i kliknij **„Usuń metodę”**. Przed usunięciem pojawi się prośba o potwierdzenie. Hasła nie można usunąć.

> [!NOTE]
> Microsoft wprowadza zmiany z kilkusekundowym opóźnieniem. Narzędzie automatycznie czeka, aż lista pokaże nowy stan. W razie potrzeby kliknij **„Odśwież”**.

### 5. Konfigurowanie nowej metody

Po prawej stronie, w sekcji **„3. Skonfiguruj metodę”**, wybierz odpowiednią metodę:

![Wybór metody MFA](images/en/select-method.png)

W zależności od metody pojawią się odpowiednie pola (np. numer seryjny) i krótka wskazówka. Następnie kliknij **„Rozpocznij konfigurację”** i potwierdź. Wynik pojawi się w **dzienniku**, a lista metod zostanie automatycznie odświeżona.

---

## Którą metodę wybrać

| Metoda | Kiedy używać? | Co się dzieje? |
|---|---|---|
| **Klucz zabezpieczeń FIDO2** | Użytkownik otrzymuje klucz FIDO2 (np. YubiKey). Najbezpieczniejsza metoda – zwłaszcza dla administratorów. | Podłącz klucz i wpisz numer seryjny. Windows poprosi o **PIN** klucza i jego **dotknięcie**. Klucz otrzyma nazwę `FIDO2-<numer seryjny>`. |
| **Karta TOTP ze stałym sekretem** | Użytkownik otrzymuje kartę z kodami, której sekret dostarczył producent. | Wpisz numer seryjny i sekret. Karta zostanie utworzona, przypisana do użytkownika i od razu aktywowana. |
| **Programowalna karta TOTP** | Użytkownik otrzymuje kartę z kodami, którą programuje się samodzielnie (np. aplikacją producenta). | Wpisz numer seryjny. Narzędzie wygeneruje nowy sekret i pokaże **kod QR oraz sekret**. Zaprogramuj nimi kartę, a następnie zamknij widok przyciskiem ✕. |
| **Temporary Access Pass (TAP)** | Użytkownik ma sam skonfigurować Authenticator lub klucz dostępu, ale nie ma jeszcze żadnej metody – lub ją utracił. | Generowany jest kod **ważny od razu przez 2 godziny** i wielokrotnego użytku. Pojawia się dużą czcionką w żółtej ramce i można go skopiować. Istniejący TAP zostaje zastąpiony. |
| **Pozorne MFA** | Trzeba zabezpieczyć konto, z którego (jeszcze) nikt nie korzysta – np. nowe konto awaryjne lub usługowe. | Rejestrowana jest metoda z kodem, której klucz zostaje natychmiast zniszczony. Przy logowaniu wymagane jest MFA, którego nikt nie może spełnić – dzięki temu konto jest chronione. |

> [!IMPORTANT]
> **TAP, sekrety i kody QR są wyświetlane tylko raz.** Nie trafiają do dziennika i nie można ich później odczytać. Jeśli kod QR zostanie zapisany przez „Zapisz kod QR …”, plik zawiera sekret – usuń go po zaprogramowaniu karty.

### Fałszywe MFA z hrdnr

Jeśli dzierżawa jest zarządzana za pomocą hrdnr, sekret tokenu fałszywego MFA można **zapisać w postaci zaszyfrowanej** zamiast go odrzucać. W razie potrzeby hrdnr może wtedy wyświetlić aktualny 6-cyfrowy kod bez konfigurowania innej metody.

- **Klucz hrdnr (opcjonalnie):** pojawia się po wybraniu „Fałszywe MFA”. Wklej klucz publiczny z hrdnr (**Użytkownicy i MFA → Klucz dla M365 MFA Manager**, format `hrdnr-fakemfa:1:…`) albo kliknij **„Wczytaj z dzierżawy”**, jeśli hrdnr zapisał go w dzierżawie (rozszerzenie `com.hrdnr.fakeMfaKey` organizacji). Narzędzie zapamiętuje klucz dla każdej dzierżawy.
- Sekret jest szyfrowany tym kluczem (RSA-OAEP-SHA256) i zapisywany w otwartym rozszerzeniu `com.hrdnr.fakeMfa` użytkownika (numer seryjny, ID klucza, zaszyfrowany sekret). Klucz prywatny ma tylko hrdnr; samo narzędzie nie może odczytać sekretu.
- Bez klucza fałszywe MFA działa jak dotychczas: sekret jest natychmiast odrzucany.

---

## Tworzenie konta awaryjnego

**Konto awaryjne (break-glass)** to dostęp awaryjny, który pozwala dostać się do dzierżawy nawet wtedy, gdy zwykłe dostępy administratora nie działają (np. z powodu błędnej zasady dostępu warunkowego).

Otwórz u góry **Narzędzia ▾ → „Konto awaryjne …”**:

![Okno „Utwórz konto awaryjne”](images/en/breakglass-dialog.png)

1. Wybierz **domenę**, w której zostanie utworzone konto.
2. Zdecyduj, czy konto otrzyma rolę **Global Administrator** (zalecane, zaznaczone domyślnie).
3. Podłącz **klucz FIDO2** i wpisz jego numer seryjny.
4. Kliknij **„Utwórz konto”**.

Następnie narzędzie automatycznie:

- tworzy konto z **losowym hasłem** (255 znaków – nigdy nie jest wyświetlane ani zapisywane, nikt go nie zna)
- zmienia nazwę konta na unikatowy identyfikator obiektu
- przypisuje rolę Global Administrator
- od razu zabezpiecza konto **pozornym MFA**
- **rejestruje klucz FIDO2** (Windows prosi o PIN i dotknięcie), a następnie ponownie usuwa pozorne MFA

Na koniec podsumowanie pokazuje wykonane kroki, a nowe konto zostaje od razu wyświetlone.

> [!WARNING]
> **Następnie wykonaj ręcznie:**
> - **Wyklucz** konto **ze wszystkich zasad dostępu warunkowego**.
> - Skonfiguruj **alert logowania**, aby każde użycie zostało zauważone.
> - Przechowuj klucz FIDO2 w bezpiecznym miejscu (np. w sejfie).

Jeśli rejestracja FIDO2 nie powiedzie się lub zostanie anulowana, konto pozostaje chronione pozornym MFA. Klucz można dodać później przez **„3. Skonfiguruj metodę → Klucz zabezpieczeń FIDO2”**.

---

## Instrukcja MFA e-mailem

Jeśli użytkownik **nie ma MFA lub ma tylko słabe MFA** (sygnalizacja czerwona lub żółta), obok stanu MFA pojawia się przycisk **"Wyślij instrukcję …"**. Wysyła on użytkownikowi e-mail z prostą instrukcją krok po kroku: otworzyć aka.ms/mfasetup, dodać aplikację Microsoft Authenticator, zeskanować kod QR. Jeśli użytkownik nie może lub nie chce używać aplikacji, wiadomość prosi o kontakt z działem IT – wystarczy na nią odpowiedzieć.

![Podgląd instrukcji MFA](images/en/mfa-guide-dialog.png)

- **Najpierw podgląd:** wiadomość jest wyświetlana dokładnie tak, jak zostanie wysłana. Jest wysyłana dopiero po kliknięciu **"Wyślij e-mail"** i potwierdzeniu.
- **Język użytkownika:** wiadomość jest pisana w preferowanym języku użytkownika z Entra ID (w przeciwnym razie w języku dzierżawy, a w ostateczności po angielsku) i można go zmienić w podglądzie.
- **Nadawca:** domyślnie własna skrzynka pocztowa. Można też podać skrzynkę udostępnioną (np. działu IT), do której masz uprawnienie *Wyślij jako* – odpowiedzi trafią wtedy tam. Ostatni nadawca jest zapamiętywany.
- **Obrazy:** zrzuty ekranu są osadzone w wiadomości jako załączniki wbudowane (Base64) – nic nie jest pobierane z internetu, a obrazy wyświetlają się także w Outlooku.
- **Data wysłania w obiekcie użytkownika:** po wysłaniu data, nadawca i język są zapisywane w open extension użytkownika (`com.m365mfatool.mfaGuide`). Open extensions istnieją tylko w Entra ID: można je zapisywać także dla użytkowników synchronizowanych (hybrydowych) i nigdy nie są nadpisywane przez Entra Connect / Cloud Sync – w przeciwieństwie do `extensionAttribute1–15`. Data jest pokazywana pod sygnalizacją i w raporcie MFA (kolumna **"Instrukcja wysłana"**).
- **Historia wysyłek (liczba i godziny):** druga open extension `com.m365mfatool.mfaGuideHistory` zlicza każdą wysyłkę (`sentCount`) i zapisuje godziny ostatnich 20 wysyłek z nadawcą i językiem (`entries` oraz `firstSentDateTime`/`lastSentDateTime`). Historia jest widoczna jako podpowiedź przy statusie instrukcji i w raporcie MFA tenanta (kolumna **„Liczba”**). hrdnr odczytuje i zapisuje to samo rozszerzenie.

Zrzuty ekranu smartfona w wiadomości pochodzą z dokumentacji Microsoft (MicrosoftDocs/entra-docs, licencja MIT); wszystkie zrzuty ekranu są zanonimizowane.

---

## Raport MFA dzierżawy

Kliknij **"Raport MFA …"** w lewym górnym rogu, aby za jednym razem sprawdzić stan MFA **wszystkich użytkowników dzierżawy** (lub członków grupy, w tym grup zagnieżdżonych).

![Raport stanu MFA dzierżawy](images/en/tenant-report.png)

1. Wybierz zakres: **"Wszyscy użytkownicy"** lub **"Członkowie grupy (w tym grupy zagnieżdżone)"** (wyszukaj grupę po początku nazwy lub po identyfikatorze obiektu). Domyślnie uwzględniane są tylko włączone konta, bez kont gości.
2. Kliknij **"Utwórz raport"**. Lista wypełnia się w trakcie odczytu metod (20 użytkowników na jedno żądanie Graph). **"Anuluj"** zatrzymuje po bieżącym bloku.
3. Kafelki pokazują liczbę dla każdego koloru sygnalizacji – **kliknięcie kafelka filtruje** listę. Dodatkowo można **wyszukiwać** (nazwa, UPN, e-mail, role, metody, ocena, dział) i pokazać **"Tylko administratorzy"**.
   Kolumny **"Ostatnie logowanie"** i **"Dni od"** pokazują, czy konto jest faktycznie używane. Konta bez logowania od ponad 90 dni lub takie, które nigdy się nie logowały, są wyróżnione na czerwono, liczone na osobnym kafelku i można je pokazać za pomocą **"Tylko nieaktywne (> 90 dni lub nigdy)"**.
4. **"Eksport do Excela …"** zapisuje aktualnie wyświetlane wpisy jako plik `.xlsx` w kolorach sygnalizacji, wraz z arkuszem podsumowania. Nie jest potrzebny ani Excel, ani dodatkowy moduł.
5. **Dwukrotne kliknięcie** użytkownika zamyka raport i otwiera użytkownika w oknie głównym do edycji. Raport jest zachowywany do wylogowania.

| Sygnalizacja | Znaczenie |
|---|---|
| 🔴 **Czerwony** | Brak MFA (tylko hasło) **lub** rola administracyjna tylko z niebezpiecznym MFA (SMS/połączenie, TAP lub fałszywe MFA) |
| 🟡 **Żółty** | Tylko niebezpieczne MFA (SMS/połączenie, TAP lub fałszywe MFA) **lub** administrator bez MFA odpornego na phishing (FIDO2, passkey, Windows Hello) |
| 🟢 **Zielony** | Silne MFA – dla administratorów odporne na phishing |

Za role administracyjne uznawane są role aktywne i kwalifikujące się przez PIM (oznaczone „(PIM)”), a także role przypisane przez grupy.

**Bez interfejsu** (np. jako comiesięczne zadanie zaplanowane) raport można utworzyć z wiersza poleceń; logowanie pozostaje interaktywne:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1 -Report -OutFile C:\Raporty\MFA.xlsx
```

Opcje: `-Group "<nazwa lub ID obiektu>"` (członkowie grupy zamiast wszystkich użytkowników), `-IncludeDisabled`, `-IncludeGuests`, `-Language pl`. Kod wyjścia 0 przy powodzeniu, 1 przy błędzie.

---

## Masowy import tokenów TOTP

W przypadku sprzętowych tokenów TOTP z plikiem seed od producenta (np. tokeny z wyświetlaczem w formie breloka) otwórz u góry **Narzędzia ▾ → „Import TOTP …”**.

1. **„Przykład”** zapisuje przykładowy plik CSV z oczekiwanymi kolumnami. Jeden wiersz na token:

   ```csv
   Secret;SerialNumber;UPN
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000001;anna.przyklad@contoso.com
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000002;
   ```

   Separator `;` lub `,`; kolejność kolumn nie ma znaczenia. **UPN jest opcjonalny**: wiersz bez UPN dodaje token tylko do inwentarza – przypisz go później w [inwentarzu tokenów](#inwentarz-tokenów) albo wybierz w polu **Tokeny bez UPN** **członków grupy** lub **użytkowników z listy CSV**: sprawdzenie rozdziela wtedy tokeny w kolejności pliku, po jednym na użytkownika, a import je aktywuje. Kolumny opcjonalne: `Manufacturer`, `Model`.
2. **„Wybierz CSV …”** wczytuje plik. Wybierz **algorytm** (SHA-1 lub SHA-256) i **interwał czasu** (30 lub 60 sekund) – oba muszą pasować do tokenów (patrz zamówienie lub plik seed).
3. **„Sprawdź”** sprawdza każdy wiersz, niczego nie zmieniając: sekret Base32, powtórzone numery seryjne, istnienie użytkownika i czy numer seryjny jest już przypisany w dzierżawie. Wiersze są oznaczone na zielono/żółto/czerwono.
4. **„Importuj”** tworzy bezbłędne tokeny w inwentarzu, przypisuje je użytkownikom i od razu aktywuje. Wiersze z błędami są pomijane; nieudany token jest wycofywany. Każdy token trafia do dziennika (bez sekretu).
5. **„Eksport do Excela …”** zapisuje listę wyników (numer seryjny → użytkownik) jako potwierdzenie i dokument przekazania. **„Cofnij”** ponownie usuwa tokeny utworzone w ostatnim przebiegu od użytkowników i z inwentarza (możliwe do następnego importu testowego).

Zmiana pliku, algorytmu, interwału lub rozdziału wymaga nowego sprawdzenia.

---

## Inwentarz tokenów

**Narzędzia ▾ → „Inwentarz tokenów …”** wyświetla wszystkie sprzętowe tokeny TOTP dzierżawy: wolne (żółte), przypisane i aktywowane (zielone), z modelem, algorytmem, interwałem i przypisanym użytkownikiem. Z wyszukiwaniem i filtrem wolne/przypisane.

- **„Przypisz …”**: najpierw wybierz użytkownika w oknie głównym, potem wolny token. Wpisz kod aktualnie wyświetlany na tokenie – zostanie przypisany i aktywowany w jednym kroku (jak w portalu Entra).
- **„Rozdziel …”**: rozdziela wszystkie wolne tokeny członkom grupy lub użytkownikom z listy CSV, po jednym w kolejności numerów seryjnych – **bez aktywacji**, bo sekrety nie są już znane. Każdy użytkownik aktywuje token na [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo), wpisując wyświetlany kod, albo robisz to Ty przyciskiem **„Aktywuj …”**. Lista przypisań (numer seryjny → użytkownik) jest od razu proponowana jako Excel.
- **„Aktywuj …”**: aktywuje przypisany, ale jeszcze nieaktywowany token kodem wyświetlanym na tokenie.
- **„Odłącz”**: użytkownik nie może już logować się tym tokenem; pozostaje on w inwentarzu jako wolny.
- **„Usuń”**: usuwa token z inwentarza (przypisany token jest najpierw usuwany od użytkownika).

---

## Masowy Temporary Access Pass

**Narzędzia ▾ → „Masowy TAP …”** tworzy Temporary Access Pass dla wielu użytkowników naraz, np. dla fali onboardingu.

1. Wybierz użytkowników: **plik CSV** (kolumna `UPN` lub jeden UPN w wierszu) albo **członków grupy** (łącznie z grupami zagnieżdżonymi).
2. Ustaw **ważność** (10–43200 minut) i czy hasło ma być **jednorazowe**.
3. **„Sprawdź”** rozwiązuje użytkowników, niczego nie zmieniając. **„Utwórz”** tworzy następnie po jednym haśle na użytkownika; istniejące hasło użytkownika zostaje zastąpione.
4. **„Eksport do Excela …”** zapisuje listę z hasłami – zawiera je w postaci jawnej, więc zapisuj ją tylko w chronionym miejscu i usuń po przekazaniu. Hasła nigdy nie trafiają do dziennika.

## Masowy offboarding

**Narzędzia ▾ → „Masowy offboarding …”** usuwa naraz metody MFA wielu użytkowników, np. przy odejściach lub po przejęciu kont.

1. Wybierz użytkowników: **plik CSV** (kolumna `UPN` lub jeden UPN w wierszu) albo **członków grupy**.
2. Wybierz akcje: **usuń wszystkie metody MFA**, **unieważnij sesje** (użytkownik zostaje wszędzie wylogowany) i opcjonalnie **wyłącz konto**.
3. **„Sprawdź”** rozwiązuje użytkowników i pokazuje, ile metod i ról administracyjnych ma każdy – niczego nie zmienia. Własne konto jest zawsze pomijane.
4. **„Wykonaj offboarding”** – po potwierdzeniu podsumowania.
5. **„Eksport do Excela …”** zapisuje listę wyników jako potwierdzenie.

> [!WARNING]
> Usuniętych metod nie da się przywrócić. Użytkownicy muszą je zarejestrować ponownie, np. przez Temporary Access Pass.

---

## Pomoc, ustawienia i aktualizacje

- **„Pomoc”** na górze każdego okna otwiera panel boczny: *co robi, kiedy używać, czego potrzebujesz, krok po kroku* i *wynik*. Każdy przycisk i pole ma też podpowiedź.
- Przy pierwszym uruchomieniu **ekran powitalny** objaśnia trzy kroki (można wyłączyć).
- **Narzędzia ▾ → „Ustawienia …”**: domyślny algorytm i interwał tokenów TOTP, domyślna ważność i jednorazowość TAP, skrzynka nadawcy instrukcji MFA oraz opcjonalnie **dzierżawa** (ID lub domena) dla kont gościa.
- Okno główne pokazuje **ostatnie logowanie**, **historię** z dziennika inspekcji, **potwierdzenie Excel** użytkownika oraz dla administratorów **„Sprawdź wykluczenie CA”**.
- Jeśli metoda jest wyłączona w zasadach metod uwierzytelniania dzierżawy, przed rozpoczęciem pojawia się żółte ostrzeżenie.
- Gdy jest nowsza wersja, u góry pojawia się przycisk **„Aktualizacja …”**: pobiera i instaluje wersję (dzienniki i ustawienia zostają); potem uruchom narzędzie ponownie.

---

## Często zadawane pytania i rozwiązywanie problemów

**Dwukrotne kliknięcie `Start.cmd` nic nie robi lub wyświetla błąd.**
Narzędzie działa tylko w systemie Windows. Jeśli folder skopiowano z Internetu, z Teams lub z pliku ZIP, pliki mogą być zablokowane. Uruchom jednorazowo w PowerShell w tym folderze: `Get-ChildItem -Recurse | Unblock-File`.

**Logowanie ponownie prosi o zgodę.**
Dzieje się tak jednorazowo po aktualizacji, gdy narzędzie potrzebuje nowych uprawnień. Wszystkie uprawnienia są żądane przy logowaniu; później nie pojawia się już żadne okno logowania.

**W dzienniku jest informacja o nowszej wersji.**
Przy starcie narzędzie porównuje swoją wersję z najnowszym wydaniem na GitHubie (tylko wpis w dzienniku, nic nie jest pobierane). Pobierz nową wersję ze strony wydań i zastąp folder.

**Nowo utworzona lub usunięta metoda nie pojawia się od razu.**
Microsoft potrzebuje na to kilku sekund. Narzędzie automatycznie czeka do ok. 16 sekund; potem w razie potrzeby kliknij **„Odśwież”**.

**FIDO2: „Fido credential policy …” lub „nie jest włączone”.**
FIDO2 nie jest włączone w dzierżawie. Administrator musi je włączyć w zasadach metod uwierzytelniania (zob. [wymagania](#wymagania-i-uprawnienia-dla-administratorów)).

**FIDO2: „UPN jest za długi”.**
FIDO2 dopuszcza maksymalnie 64 znaki nazwy logowania (UPN).

**Karta TOTP: „Token o numerze seryjnym … jest już przypisany do …”.**
Karta należy już do innego użytkownika. Najpierw usuń ją u niego.

**Komunikat o błędzie z „Authorization_RequestDenied” lub „Forbidden”.**
Twojemu kontu brakuje roli administratora (zob. [role](#wymagania-i-uprawnienia-dla-administratorów)).

Każda czynność jest zapisywana z godziną w **dzienniku** w prawym dolnym rogu. Dodatkowo jest od razu zapisywana w dziennym pliku dziennika w folderze narzędzia, np. `Logs\2026-10-12.log` (jeśli folder nie jest zapisywalny: `%LOCALAPPDATA%\M365MfaTool\Logs`) – przydatne przy zgłoszeniach.

**Raport MFA: kolumny ostatniego logowania są puste.**
Wymagane są licencja **Entra ID P1/P2**, uprawnienie `AuditLog.Read.All` oraz rola, która może odczytywać dane logowania (np. **Czytelnik raportów**). Bez nich raport i tak zostanie utworzony, ale bez tych informacji; przyczyna jest podana w dzienniku.

---

## Bezpieczeństwo

- **Brak sekretów w dzienniku:** TAP, sekrety i hasła nigdy nie są zapisywane w dzienniku ani na dysku.
- **Nieznane hasła:** hasła kont awaryjnych są generowane losowo i nigdy nie są wyświetlane.
- **Potwierdzenia:** każda zmiana wymaga potwierdzenia; domyślnie zaznaczona jest odpowiedź „Nie”.
- **Sprzątanie po błędach:** jeśli konfiguracja karty TOTP się nie powiedzie, narzędzie automatycznie usuwa częściowo utworzone wpisy.

> [!CAUTION]
> Działania administracyjne wykonuj wyłącznie zgodnie z wewnętrznym procesem zatwierdzania i bezpieczeństwa.

---

## Wymagania i uprawnienia dla administratorów

### Wymagania systemowe

- Windows z **Windows PowerShell 5.1** (preinstalowany; PowerShell 7 nie jest obsługiwany, ponieważ interfejs korzysta z WPF)
- Dostęp do Internetu przy pierwszym uruchomieniu w celu instalacji modułów PowerShell (tylko dla bieżącego użytkownika, bez uprawnień administratora):
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.SignIns` i `DSInternals.Passkeys` **1.0.6** (FIDO2)
  - `QRCodeGenerator` (kody QR dla programowalnych kart TOTP)

  Można je też zainstalować wcześniej za pomocą `Install-Prerequisites.ps1`.
- W przypadku FIDO2 klucz musi być podłączony do **komputera lokalnego** (przez RDP tylko z przekierowaniem WebAuthn).

### Uprawnienia Graph (delegowane)

Wszystkie uprawnienia są żądane jednorazowo przy logowaniu, dzięki czemu podczas pracy nie pojawia się już żadne okno logowania:

| Uprawnienie | Do czego |
|---|---|
| `User.Read.All` | Wyszukiwanie użytkowników |
| `UserAuthenticationMethod.Read.All` | Wyświetlanie metod MFA |
| `UserAuthenticationMethod.ReadWrite.All` | Konfigurowanie i usuwanie metod MFA |
| `Policy.ReadWrite.AuthenticationMethod` | Inwentarz tokenów: tworzenie, przypisywanie i usuwanie kart TOTP, importowanych tokenów TOTP i pozornego MFA |
| `RoleManagement.Read.Directory` | Wyświetlanie ról administratora użytkownika |
| `User.ReadWrite.All` | Konto awaryjne; zapis daty wysłania instrukcji MFA i zaszyfrowanego sekretu pozornego MFA w obiekcie użytkownika |
| `Domain.Read.All` | Konto awaryjne: wyświetlanie domen do wyboru |
| `RoleManagement.ReadWrite.Directory` | Konto awaryjne: przypisanie roli Global Administrator |
| `GroupMember.Read.All` | Raport MFA: wybór grupy jako zakresu, rozwiązywanie ról przypisanych przez grupy |
| `AuditLog.Read.All` | Raport MFA: ostatnie logowanie |
| `Policy.Read.All` | Ostrzeżenie, gdy metoda jest wyłączona w dzierżawie; sprawdzenie dostępu warunkowego |
| `Mail.Send` | Instrukcja MFA z własnej skrzynki |
| `Mail.Send.Shared` | Instrukcja MFA ze skrzynki współdzielonej |
| `Organization.Read.All` | Wczytanie klucza hrdnr z dzierżawy |

Jeśli uprawnienie nie zostało przyznane (odrzucona zgoda), zgłasza to dana funkcja; wyloguj się i zaloguj ponownie, aby je przyznać.

Ostatnie logowanie wymaga dodatkowo licencji **Entra ID P1/P2** i roli z dostępem do danych logowania, np. **Reports Reader**, **Security Reader** lub **Global Reader**. Wyświetlane jest ostatnie udane logowanie (interaktywne lub nieinteraktywne); Microsoft rejestruje je od grudnia 2023, starsze wartości to ostatnia próba logowania.

Zapis daty wysłania instrukcji MFA wymaga roli mogącej modyfikować użytkowników, np. **User Administrator**.

### Wymagane role Entra dla własnego konta

| Zadanie | Rola |
|---|---|
| Zarządzanie metodami zwykłych użytkowników, TAP | **Authentication Administrator** |
| Zarządzanie metodami administratorów | **Privileged Authentication Administrator** |
| Karty TOTP, import TOTP i pozorne MFA | dodatkowo **Authentication Policy Administrator** |
| Konto awaryjne | **Global Administrator** (lub Privileged Role Administrator + User Administrator) |

### Ustawienia dzierżawy

W **zasadach metod uwierzytelniania** (Centrum administracyjne Entra → Ochrona → Metody uwierzytelniania) muszą być włączone używane metody:

- **Klucz dostępu (FIDO2)**
- **Sprzętowe tokeny OATH** (dla kart TOTP i pozornego MFA)
- **Temporary Access Pass** – maksymalny czas ważności co najmniej 2 godziny

### Uwagi

- Niektóre funkcje korzystają z **interfejsu API w wersji beta** Microsoft Graph (np. dla sprzętowych tokenów OATH), który może się zmieniać.
- Role kwalifikujące się przez PIM są wyświetlane tylko z Entra ID P2.
- Wybrany język jest zapisywany w `%APPDATA%\M365MfaTool\settings.json`.

---

## Struktura projektu

| Plik | Zawartość |
|---|---|
| `Start.cmd` | Uruchamianie dwukrotnym kliknięciem |
| `Start-M365MfaTool.ps1` | Interfejs, zarządzanie stanem i zdarzenia |
| `UI/Theme.xaml` | Wspólny wygląd wszystkich okien |
| `UI/MainWindow.xaml` | Układ okna głównego |
| `UI/BreakGlassDialog.xaml` | Okno dla nowych kont awaryjnych |
| `UI/TenantReportWindow.xaml` | Okno raportu MFA |
| `UI/TotpImportWindow.xaml` | Okno masowego importu TOTP |
| `UI/TokenInventoryWindow.xaml` | Okno inwentarza tokenów |
| `UI/BulkTapWindow.xaml` | Okno masowego Temporary Access Pass |
| `UI/MfaGuideDialog.xaml` | Okno podglądu instrukcji MFA |
| `UI/BulkOffboardWindow.xaml` | Okno masowego offboardingu |
| `UI/SettingsDialog.xaml` | Okno ustawień |
| `UI/HistoryDialog.xaml` | Historia użytkownika (dziennik inspekcji) |
| `Modules/Graph.psm1` | Logowanie, żądania Graph, użytkownicy, domeny, role, sygnalizator MFA, odczyt/usuwanie metod |
| `Modules/Provisioning.psm1` | Konfiguracja FIDO2, kart TOTP, pozornego MFA, TAP i kont awaryjnych |
| `Modules/TenantReport.psm1` | Raport MFA: użytkownicy, role, zbiorcze zapytania o metody, ocena w formie sygnalizacji, eksport do Excela |
| `Modules/Xlsx.psm1` | Lekki generator plików Excel (.xlsx bez Excela i dodatkowych modułów) |
| `Modules/MfaGuideMail.psm1` | Instrukcja MFA: wiadomość w języku użytkownika, wysyłka przez Graph, data wysłania w obiekcie użytkownika |
| `Modules/Localization.psm1` | Wielojęzyczność: wczytuje pliki językowe i dostarcza teksty |
| `Languages/*.json` | Teksty dla każdego języka (`en.json` jest wzorcem) |
| `Mail/Images/` | Zanonimizowane zrzuty ekranu do wiadomości |
| `Install-Prerequisites.ps1` | Opcjonalna wcześniejsza instalacja wszystkich modułów |
| `docs/` | Przetłumaczona dokumentacja i zrzuty ekranu |
| `Logs/` | Dzienne pliki dziennika (tworzone automatycznie, nie są przechowywane w Git) |

---

## Dodawanie języka

1. Skopiuj `Languages/en.json` i nazwij plik kodem języka, np. `sv.json` dla szwedzkiego.
2. Ustaw `"_language"` na nazwę języka w tym języku (np. `"Svenska"`) i przetłumacz wszystkie teksty. Symbole zastępcze, takie jak `{0}`, muszą zostać zachowane.
3. Uruchom narzędzie ponownie – język pojawi się automatycznie na liście wyboru. Brakujące teksty są wyświetlane po angielsku.
4. Opcjonalnie: dodaj przetłumaczoną dokumentację jako `docs/README.<kod>.md` i dodaj link na pasku języków na górze wszystkich plików README.
