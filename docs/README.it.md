🌐 [English](../README.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Français](README.fr.md) · **Italiano** · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Polski](README.pl.md)

# M365 MFA Administration Tool

Con questo strumento, amministratori e help desk configurano l'**autenticazione a più fattori (MFA) per conto di altri utenti** – ad esempio una chiave FIDO2, una scheda TOTP o un codice di accesso temporaneo. Inoltre mostra a colpo d'occhio quanto è protetto un account utente.

> [!NOTE]
> Gli screenshot mostrano l'interfaccia in inglese. L'interfaccia può essere impostata in italiano in alto a destra.

![Finestra principale di M365 MFA Administration Tool](images/en/main-window.png)

## Indice

- [In breve](#in-breve)
- [Avvio rapido](#avvio-rapido)
- [Guida passo per passo](#guida-passo-per-passo)
- [Quale metodo scegliere](#quale-metodo-scegliere)
- [Creare un account di emergenza](#creare-un-account-di-emergenza)
- [Guida MFA via e-mail](#guida-mfa-via-e-mail)
- [Report MFA del tenant](#report-mfa-del-tenant)
- [Importazione massiva di token TOTP](#importazione-massiva-di-token-totp)
- [Inventario dei token](#inventario-dei-token)
- [Temporary Access Pass di massa](#temporary-access-pass-di-massa)
- [Campagna MFA e classificazione degli account](#campagna-mfa-e-classificazione-degli-account)
- [Offboarding di massa](#offboarding-di-massa)
- [Guida, impostazioni e aggiornamenti](#guida-impostazioni-e-aggiornamenti)
- [Domande frequenti e risoluzione dei problemi](#domande-frequenti-e-risoluzione-dei-problemi)
- [Sicurezza](#sicurezza)
- [Requisiti e autorizzazioni per gli amministratori](#requisiti-e-autorizzazioni-per-gli-amministratori)
- [Struttura del progetto](#struttura-del-progetto)
- [Aggiungere una lingua](#aggiungere-una-lingua)

---

## In breve

| | Funzione |
|---|---|
| 🔍 | **Cercare utenti** – per nome, indirizzo e-mail, UPN o ID oggetto |
| 🚦 | **Semaforo MFA** – mostra subito se un account è protetto bene, debolmente o per niente, con una raccomandazione |
| 👑 | **Ruoli di amministratore** – mostra se l'utente ha diritti amministrativi |
| 📋 | **Visualizzare ed eliminare metodi MFA** – tutti i metodi registrati con data e dettagli |
| ➕ | **Configurare metodi** – chiave FIDO2, schede TOTP, Temporary Access Pass e MFA fittizia |
| ✉️ | **Guida MFA via e-mail** – invia agli utenti senza MFA o con MFA debole una guida passo per passo per l'app Microsoft Authenticator, nella loro lingua e con anteprima |
| 📊 | **Report MFA del tenant** – stato MFA e ultimo accesso di tutti gli utenti come semaforo, con ricerca, filtri ed esportazione Excel a colori |
| 📥 | **Importazione massiva TOTP** – importare token TOTP hardware (SHA-1 o SHA-256) da un file CSV, con importazione di prova, esportazione Excel e annullamento |
| 🗂️ | **Inventario dei token** – tutti i token TOTP hardware del tenant: assegnare i token liberi, rimuovere assegnazioni, eliminare |
| 🎫 | **TAP di massa** – Temporary Access Pass per molti utenti in una volta (CSV o gruppo) con esportazione Excel |
| 🆘 | **Account di emergenza** – creare un accesso di emergenza (break-glass) con chiave FIDO2 e password sconosciuta |
| 🌐 | **Multilingue** – inglese (predefinito), tedesco, spagnolo, francese, italiano, portoghese, olandese e polacco |

---

## Avvio rapido

1. Copiare l'intera cartella sul proprio computer (i file devono restare insieme).
2. **Fare doppio clic su `Start.cmd`.**
3. In alto a destra impostare la lingua su **Italiano** e fare clic su **"Accedi"**. Accedere con il proprio account amministratore.

> [!TIP]
> Per un accesso rapido, creare un collegamento sul desktop a `Start.cmd` (clic destro → *Crea collegamento*).

Al primo accesso lo strumento verifica se mancano componenti necessari. In tal caso li elenca e chiede una sola volta se installarli – l'installazione avviene in background (circa uno o due minuti) ed è visibile nel log. Poi Microsoft chiede una sola volta il consenso alle autorizzazioni dello strumento.

---

## Guida passo per passo

### 1. Scegliere la lingua e accedere

L'interfaccia si avvia in **inglese**. Con la casella di selezione in alto a destra, accanto a "Sign in", la lingua può essere cambiata in qualsiasi momento, senza riavvio. La scelta viene salvata per il proprio utente Windows e applicata all'avvio successivo.

Fare clic su **"Accedi"** in alto a destra. Dopo l'accesso viene mostrato in verde *"Connesso come …"* insieme al tenant. **"Esci"** termina la sessione – ciò avviene anche automaticamente alla chiusura della finestra.

### 2. Cercare un utente

Nella casella **"1. Cerca utente"** digitare l'inizio di un nome, di un indirizzo e-mail o dell'UPN e premere **Invio** (oppure fare clic su **"Cerca"**).

- **Un risultato:** l'utente viene aperto direttamente.
- **Più risultati:** sotto la casella di ricerca si apre un elenco – fare clic sull'utente desiderato. Con **Esc** o un clic altrove l'elenco si chiude.

### 3. Capire lo stato MFA

A destra, in **"Utente selezionato"**, il **semaforo MFA** mostra quanto è protetto l'account:

| Semaforo | Significato | Cosa fare? |
|---|---|---|
| 🟢 **MFA forte (resistente al phishing)** | Chiave FIDO2, passkey o Windows Hello presente | Tutto a posto. |
| 🟢 **MFA forte** | App Authenticator o scheda/app TOTP presente | Va bene. Per gli amministratori è consigliato anche FIDO2. |
| 🟡 **Solo MFA debole** | Solo SMS o chiamata | Configurare un metodo migliore, poi rimuovere SMS/chiamata. |
| 🟡 **Solo MFA fittizia** | L'account è bloccato per sicurezza (vedi [MFA fittizia](#quale-metodo-scegliere)) | Configurare un metodo reale per poterlo usare. |
| 🟡 **Solo Temporary Access Pass** | Solo un codice di accesso temporaneo | L'utente deve ora usarlo per configurare un metodo permanente. |
| 🔴 **Nessuna MFA – solo password** | Nessun secondo fattore | Configurare un metodo con urgenza. |

Sotto il semaforo compaiono raccomandazioni concrete, ad esempio *"Sono registrati anche SMS/chiamata, che possono essere rimossi"*.

Più in basso, **"Ruoli amministrativi"** indica se l'utente ha diritti di amministratore. **"Mostra"** espande l'elenco. Per ogni ruolo è indicato anche se è attivo in modo permanente, assegnato tramite un gruppo o solo attivabile tramite PIM.

### 4. Visualizzare ed eliminare i metodi MFA

A sinistra, in **"2. Metodi MFA registrati"**, sono elencati tutti i metodi dell'utente. Facendo clic su un metodo vengono mostrati sotto **tutti i dettagli** (ad es. modello del dispositivo, numero di serie, data di creazione).

Per eliminare un metodo, selezionarlo e fare clic su **"Elimina metodo"**. Prima dell'eliminazione viene chiesta una conferma. La password non può essere eliminata.

> [!NOTE]
> Microsoft applica le modifiche con alcuni secondi di ritardo. Lo strumento attende automaticamente che l'elenco mostri il nuovo stato. Se necessario, fare clic su **"Aggiorna"**.

### 5. Configurare un nuovo metodo

A destra, in **"3. Configura metodo"**, scegliere il metodo desiderato:

![Selezione del metodo MFA](images/en/select-method.png)

A seconda del metodo compaiono i campi appropriati (ad es. il numero di serie) e una breve indicazione. Fare quindi clic su **"Avvia configurazione"** e confermare. Il risultato appare nel **log** e l'elenco dei metodi viene aggiornato automaticamente.

---

## Quale metodo scegliere

| Metodo | Quando usarlo? | Cosa succede? |
|---|---|---|
| **Chiave di sicurezza FIDO2** | L'utente riceve una chiave FIDO2 (ad es. YubiKey). Il metodo più sicuro – soprattutto per gli amministratori. | Inserire la chiave e il numero di serie. Windows chiede il **PIN** della chiave e di **toccarla**. La chiave si chiamerà `FIDO2-<numero di serie>`. |
| **Scheda TOTP con segreto fisso** | L'utente riceve una scheda di codici il cui segreto è fornito dal produttore. | Inserire numero di serie e segreto. La scheda viene creata, assegnata all'utente e attivata subito. |
| **Scheda TOTP programmabile** | L'utente riceve una scheda di codici da programmare in autonomia (ad es. con l'app del produttore). | Inserire il numero di serie. Lo strumento genera un nuovo segreto e mostra **codice QR e segreto**. Programmare la scheda, poi chiudere la visualizzazione con ✕. |
| **Temporary Access Pass (TAP)** | L'utente deve configurare da sé Authenticator o una passkey ma non ha ancora alcun metodo – oppure l'ha perso. | Viene generato un codice **valido da subito per 2 ore** e utilizzabile più volte. È mostrato in grande in un riquadro giallo e può essere copiato. Un TAP esistente viene sostituito. |
| **MFA fittizia** | Si vuole proteggere un account che (ancora) nessuno usa – ad es. un nuovo account di emergenza o di servizio. | Viene registrato un metodo a codice la cui chiave viene distrutta subito. All'accesso viene richiesta un'MFA che nessuno può soddisfare – così l'account è protetto. |

> [!IMPORTANT]
> **TAP, segreti e codici QR vengono mostrati una sola volta.** Non compaiono nel log e non possono essere recuperati in seguito. Se un codice QR viene salvato con "Salva codice QR …", il file contiene il segreto – eliminarlo dopo la programmazione.

### MFA fittizia con hrdnr

Se il tenant è gestito con hrdnr, il segreto di un token di MFA fittizia può essere **salvato cifrato** invece di essere eliminato. In caso di emergenza hrdnr può così mostrare il codice attuale a 6 cifre senza dover configurare un altro metodo.

- **Chiave hrdnr (facoltativa):** compare quando è selezionata «MFA fittizia». Incollare la chiave pubblica di hrdnr (**Utenti e MFA → Chiave per M365 MFA Manager**, formato `hrdnr-fakemfa:1:…`) oppure fare clic su **«Carica dal tenant»** se hrdnr l'ha salvata nel tenant (estensione `com.hrdnr.fakeMfaKey` dell'organizzazione). Lo strumento memorizza la chiave per tenant.
- Il segreto viene cifrato con questa chiave (RSA-OAEP-SHA256) e salvato nell'estensione aperta `com.hrdnr.fakeMfa` dell'utente (numero di serie, ID chiave, segreto cifrato). Solo hrdnr possiede la chiave privata; lo strumento stesso non può rileggere il segreto.
- Senza chiave la MFA fittizia funziona come prima: il segreto viene eliminato subito.

---

## Creare un account di emergenza

Un **account di emergenza (break-glass)** è un accesso di emergenza che consente di entrare nel tenant anche quando i normali accessi amministrativi non funzionano (ad es. per un criterio di accesso condizionale errato).

Aprire in alto **Strumenti ▾ → "Account di emergenza …"**:

![Finestra "Crea account di emergenza"](images/en/breakglass-dialog.png)

1. Selezionare il **dominio** in cui creare l'account.
2. Decidere se l'account riceve il ruolo **Global Administrator** (consigliato, preselezionato).
3. Inserire la **chiave FIDO2** e il suo numero di serie.
4. Fare clic su **"Crea account"**.

Lo strumento esegue poi automaticamente:

- crea l'account con una **password casuale** (255 caratteri – non viene mai mostrata né salvata, nessuno la conosce)
- imposta come nome dell'account l'ID oggetto univoco
- assegna il ruolo Global Administrator
- protegge subito l'account con una **MFA fittizia**
- **registra la chiave FIDO2** (Windows chiede PIN e tocco) e poi rimuove di nuovo la MFA fittizia

Alla fine un riepilogo mostra le operazioni eseguite e il nuovo account viene visualizzato direttamente.

> [!WARNING]
> **Poi completare manualmente:**
> - **Escludere** l'account **da tutti i criteri di accesso condizionale**.
> - Configurare un **avviso di accesso** per notare ogni utilizzo.
> - Conservare la chiave FIDO2 in un luogo sicuro (ad es. in cassaforte).

Se la registrazione FIDO2 non riesce o viene annullata, l'account resta protetto dalla MFA fittizia. La chiave può essere aggiunta in seguito tramite **"3. Configura metodo → Chiave di sicurezza FIDO2"**.

---

## Guida MFA via e-mail

Se un utente **non ha MFA o ha solo una MFA debole** (semaforo rosso o giallo), accanto allo stato MFA compare il pulsante **"Invia guida …"**. Invia all'utente un'e-mail con una semplice guida passo per passo: aprire aka.ms/mfasetup, aggiungere l'app Microsoft Authenticator, scansionare il codice QR. Se l'utente non può o non vuole usare l'app, l'e-mail gli chiede di contattare il reparto IT – semplicemente rispondendo all'e-mail.

![Anteprima della guida MFA](images/en/mfa-guide-dialog.png)

- **Prima l'anteprima:** l'e-mail viene mostrata esattamente come verrà inviata. Viene inviata solo dopo **"Invia e-mail"** e una conferma.
- **Lingua dell'utente:** l'e-mail è scritta nella lingua preferita dell'utente in Entra ID (altrimenti in quella del tenant, altrimenti in inglese) e può essere cambiata nell'anteprima.
- **Mittente:** per impostazione predefinita la propria cassetta postale. In alternativa una cassetta condivisa (ad es. quella dell'IT) per cui si dispone dell'autorizzazione *Invia come* – le risposte arrivano lì. L'ultimo mittente viene memorizzato.
- **Immagini:** gli screenshot sono incorporati nell'e-mail come allegati inline (Base64) – non viene caricato nulla da Internet e vengono mostrati anche in Outlook.
- **Data di invio nell'oggetto utente:** dopo l'invio, data, mittente e lingua vengono salvati in una open extension dell'utente (`com.m365mfatool.mfaGuide`). Le open extension esistono solo in Entra ID: sono scrivibili anche per gli utenti sincronizzati (ibridi) e non vengono mai sovrascritte da Entra Connect / Cloud Sync – a differenza di `extensionAttribute1–15`. La data è mostrata sotto il semaforo e nel report MFA (colonna **"Guida inviata"**).
- **Cronologia degli invii (numero e orari):** una seconda open extension `com.m365mfatool.mfaGuideHistory` conta ogni invio (`sentCount`) e salva gli orari degli ultimi 20 invii con mittente e lingua (`entries`, oltre a `firstSentDateTime`/`lastSentDateTime`). La cronologia appare come tooltip sullo stato della guida e nel report MFA del tenant (colonna **"Numero"**). hrdnr legge e scrive la stessa estensione.

Gli screenshot dello smartphone nell'e-mail provengono dalla documentazione Microsoft (MicrosoftDocs/entra-docs, licenza MIT); tutti gli screenshot sono anonimizzati.

---

## Report MFA del tenant

Fare clic su **"Report MFA …"** in alto a sinistra per verificare in un colpo solo lo stato MFA di **tutti gli utenti del tenant** (o dei membri di un gruppo, inclusi i gruppi annidati).

![Report stato MFA del tenant](images/en/tenant-report.png)

1. Scegliere l'ambito: **"Tutti gli utenti"** oppure **"Membri di un gruppo (inclusi gruppi annidati)"** (cercare il gruppo tramite l'inizio del nome o l'ID oggetto). Per impostazione predefinita vengono considerati solo gli account abilitati e nessun account guest.
2. Fare clic su **"Crea report"**. L'elenco si riempie mentre vengono letti i metodi (20 utenti per richiesta Graph). **"Annulla"** si interrompe dopo il blocco corrente.
3. I riquadri mostrano il numero per colore del semaforo – **un clic su un riquadro filtra** l'elenco. Inoltre è possibile **cercare** (nome, UPN, e-mail, ruoli, metodi, valutazione, reparto) e mostrare **"Solo amministratori"**.
   Le colonne **"Ultimo accesso"** e **"Giorni da"** mostrano se un account viene effettivamente usato. Gli account senza accesso da oltre 90 giorni o che non hanno mai effettuato l'accesso sono evidenziati in rosso, conteggiati in un riquadro dedicato e possono essere mostrati con **"Solo inattivi (> 90 giorni o mai)"**.
4. **"Esporta in Excel …"** salva le voci attualmente visualizzate come file `.xlsx` nei colori del semaforo, con un foglio di riepilogo. Non servono né Excel né moduli aggiuntivi.
5. Un **doppio clic** su un utente chiude il report e apre l'utente nella finestra principale per la modifica. Il report resta disponibile fino alla disconnessione.

| Semaforo | Significato |
|---|---|
| 🔴 **Rosso** | Nessuna MFA (solo password), **oppure** ruolo amministrativo con sola MFA non sicura (SMS/chiamata, TAP o MFA fittizia) |
| 🟡 **Giallo** | Solo MFA non sicura (SMS/chiamata, TAP o MFA fittizia), **oppure** amministratore senza MFA resistente al phishing (FIDO2, passkey, Windows Hello) |
| 🟢 **Verde** | MFA forte – per gli amministratori resistente al phishing |

Come ruoli amministrativi contano i ruoli attivi e quelli idonei tramite PIM (contrassegnati con "(PIM)"), nonché i ruoli assegnati tramite gruppi.

**Senza interfaccia** (ad es. come attività pianificata mensile) il report può essere creato dalla riga di comando; l'accesso resta interattivo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1 -Report -OutFile C:\Report\MFA.xlsx
```

Opzioni: `-Group "<nome o ID oggetto>"` (membri di un gruppo invece di tutti gli utenti), `-IncludeDisabled`, `-IncludeGuests`, `-Language it`. Codice di uscita 0 in caso di successo, 1 in caso di errore.

---

## Importazione massiva di token TOTP

Per token TOTP hardware con file dei seed del produttore (ad es. token con display a portachiavi), aprire in alto **Strumenti ▾ → "Importa TOTP …"**.

1. **"Esempio"** salva un CSV di esempio con le colonne previste. Una riga per token:

   ```csv
   Secret;SerialNumber;UPN
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000001;anna.esempio@contoso.com
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000002;
   ```

   Separatore `;` o `,`; l'ordine delle colonne è libero. **UPN è facoltativo**: una riga senza UPN aggiunge il token solo all'inventario; assegnarlo poi nell'[inventario dei token](#inventario-dei-token), oppure scegliere in **Token senza UPN** i **membri di un gruppo** o gli **utenti di un elenco CSV**: la verifica distribuisce allora i token nell'ordine del file, uno per utente, e l'importazione li attiva. Colonne facoltative: `Manufacturer`, `Model`.
2. **"Seleziona CSV …"** carica il file. Scegliere l'**algoritmo** (SHA-1 o SHA-256) e l'**intervallo** (30 o 60 secondi): entrambi devono corrispondere ai token (vedere l'ordine o il file dei seed).
3. **"Verifica"** controlla ogni riga senza modificare nulla: secret Base32, numeri di serie duplicati, esistenza dell'utente e numero di serie già assegnato nel tenant. Le righe sono mostrate in verde/giallo/rosso.
4. **"Importa"** crea i token senza errori nell'inventario, li assegna agli utenti e li attiva subito. Le righe con errori vengono saltate; un token non riuscito viene annullato. Ogni token compare nel log (senza secret).
5. **"Esporta in Excel …"** salva l'elenco dei risultati (numero di serie → utente) come prova e documento di consegna. **"Annulla"** rimuove di nuovo i token creati nell'ultima esecuzione dagli utenti e dall'inventario (possibile fino alla prossima importazione di prova).

Cambiare file, algoritmo, intervallo o distribuzione richiede una nuova verifica.

---

## Inventario dei token

**Strumenti ▾ → "Inventario token …"** elenca tutti i token TOTP hardware del tenant: token liberi (giallo), assegnati e attivati (verde), con modello, algoritmo, intervallo e utente assegnato. Con ricerca e filtro libero/assegnato.

- **"Assegna …"**: selezionare prima un utente nella finestra principale, poi un token libero. Inserire il codice mostrato in quel momento sul token: viene assegnato e attivato in un solo passaggio (come nel portale Entra).
- **"Distribuisci …"**: distribuisce tutti i token liberi ai membri di un gruppo o agli utenti di un elenco CSV, uno ciascuno in ordine di numero di serie – **senza attivazione**, perché i secret non sono più noti. Ogni utente attiva il token su [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo) inserendo il codice mostrato, oppure lo si fa con **"Attiva …"**. L'elenco delle assegnazioni (numero di serie → utente) viene proposto subito dopo come Excel.
- **"Attiva …"**: attiva un token assegnato ma non ancora attivato con il codice mostrato sul token.
- **"Rimuovi"**: l'utente non può più accedere con il token; resta nell'inventario come token libero.
- **"Elimina"**: rimuove il token dall'inventario (un token assegnato viene prima rimosso dal suo utente).

---

## Temporary Access Pass di massa

**Strumenti ▾ → "TAP di massa …"** crea un Temporary Access Pass per molti utenti in una volta, ad es. per un'ondata di onboarding.

1. Scegliere gli utenti: un **file CSV** (colonna `UPN` o un UPN per riga) oppure i **membri di un gruppo** (inclusi i gruppi nidificati).
2. Impostare la **validità** (10–43200 minuti) e se il pass è a **uso singolo**.
3. **"Verifica"** risolve gli utenti senza modificare nulla. **"Crea"** crea poi un pass per utente; un pass esistente dell'utente viene sostituito.
4. **"Esporta in Excel …"** salva l'elenco con i pass: li contiene in chiaro, quindi salvarlo solo in un luogo protetto ed eliminarlo dopo la consegna. I pass non vengono mai scritti nel log.

## Campagna MFA e classificazione degli account

**Strumenti ▾ → "Campagna MFA …"** (o **"Classifica account …"**) apre una finestra con due schede che usa gli stessi dati del report MFA (oppure **"Carica utenti"**).

- **"Classifica account"**: segnare come **"Non è una persona"** ogni account senza una persona dietro (casella condivisa, account di servizio, sala o test). Viene salvato sull'oggetto utente (open extension `com.m365mfatool.accountClass`) e mostrato anche nella finestra principale (**"Tipo di account"**) e nel report MFA. La campagna salta questi account. Dubbi? Segnarlo **"Da chiarire"** con una nota e filtrarlo durante la revisione con il cliente.
- **"Campagna"**: contatori (gruppo target, mai contattati, contattati), filtri per semaforo e ultimo contatto; selezionare gli utenti e inviare la guida per **e-mail** e/o **Teams** (messaggio chat 1:1 dal vostro account).

Ogni invio viene salvato sull'utente: numero, prima e ultima data e gli ultimi 20 invii con data, mittente, lingua e canale.

---

## Offboarding di massa

**Strumenti ▾ → "Offboarding di massa …"** rimuove in una volta i metodi MFA di molti utenti, ad es. per uscite di personale o dopo account compromessi.

1. Scegliere gli utenti: un **file CSV** (colonna `UPN` o un UPN per riga) oppure i **membri di un gruppo**.
2. Scegliere le azioni: **rimuovi tutti i metodi MFA**, **revoca sessioni** (l'utente viene disconnesso ovunque) e facoltativamente **disattiva account**.
3. **"Verifica"** risolve gli utenti e mostra quanti metodi e ruoli admin ha ciascuno – senza modificare nulla. Il proprio account viene sempre saltato.
4. **"Esegui offboarding"** – dopo aver confermato il riepilogo.
5. **"Esporta in Excel …"** salva l'elenco dei risultati come prova.

> [!WARNING]
> I metodi rimossi non si possono ripristinare. Gli utenti devono registrarli di nuovo, ad es. con un Temporary Access Pass.

---

## Guida, impostazioni e aggiornamenti

- **"Guida"** in alto in ogni finestra apre un pannello laterale: *cosa fa, quando usarlo, cosa serve, passo per passo* e *risultato*. Ogni pulsante e campo ha anche un suggerimento.
- Al primo avvio una **schermata di benvenuto** spiega i tre passi (disattivabile).
- **Strumenti ▾ → "Impostazioni …"**: algoritmo e intervallo predefiniti dei token TOTP, validità e uso singolo predefiniti dei TAP, casella mittente della guida MFA e, facoltativamente, un **tenant** (ID o dominio) per account ospiti.
- La finestra principale mostra l'**ultimo accesso**, la **cronologia** dal registro di controllo, una **prova Excel** dell'utente e, per gli amministratori, **"Verifica esclusione CA"**.
- Se il metodo è disattivato nel criterio dei metodi di autenticazione del tenant, prima di iniziare compare un avviso giallo.
- Quando esiste una nuova versione, in alto compare il pulsante **"Aggiorna …"**: scarica e installa la versione (log e impostazioni restano); poi riavviare lo strumento.

---

## Domande frequenti e risoluzione dei problemi

**Il doppio clic su `Start.cmd` non fa nulla o mostra un errore.**
Lo strumento funziona solo su Windows. Se la cartella è stata copiata da Internet, Teams o un file ZIP, i file potrebbero essere bloccati. Eseguire una volta in PowerShell nella cartella: `Get-ChildItem -Recurse | Unblock-File`.

**L'accesso chiede di nuovo il consenso.**
Succede una volta dopo un aggiornamento, quando lo strumento ha bisogno di nuove autorizzazioni. Tutte le autorizzazioni vengono richieste all'accesso; in seguito non compare più alcuna finestra di accesso.

**Il log indica che è disponibile una versione più recente.**
All'avvio lo strumento confronta la propria versione con l'ultima release su GitHub (solo una riga di log, non viene scaricato nulla). Scaricare la nuova versione dalla pagina delle release e sostituire la cartella.

**Un metodo appena creato o eliminato non viene mostrato subito.**
Microsoft ha bisogno di alcuni secondi. Lo strumento attende automaticamente fino a circa 16 secondi; poi, se necessario, fare clic su **"Aggiorna"**.

**FIDO2: "Fido credential policy …" o "non abilitato".**
FIDO2 non è abilitato nel tenant. Un amministratore deve abilitarlo nei criteri dei metodi di autenticazione (vedi [requisiti](#requisiti-e-autorizzazioni-per-gli-amministratori)).

**FIDO2: "L'UPN è troppo lungo".**
FIDO2 consente al massimo 64 caratteri per il nome di accesso (UPN).

**Scheda TOTP: "Un token con il numero di serie … è già assegnato a …".**
La scheda appartiene già a un altro utente. Rimuoverla prima da lì.

**Messaggio di errore con "Authorization_RequestDenied" o "Forbidden".**
Al proprio account manca un ruolo di amministratore (vedi [ruoli](#requisiti-e-autorizzazioni-per-gli-amministratori)).

Ogni azione è riportata con l'ora nel **log** in basso a destra. Viene inoltre salvata subito in un file di log giornaliero nella cartella dello strumento, ad es. `Logs\2026-10-12.log` (se la cartella non è scrivibile: `%LOCALAPPDATA%\M365MfaTool\Logs`) – utile in caso di domande.

**Report MFA: le colonne dell'ultimo accesso sono vuote.**
Servono una licenza **Entra ID P1/P2**, l'autorizzazione `AuditLog.Read.All` e un ruolo che possa leggere i dati di accesso (ad es. **Lettore report**). In caso contrario il report viene comunque creato, ma senza queste informazioni; il log ne indica il motivo.

---

## Sicurezza

- **Nessun segreto nel log:** TAP, segreti e password non vengono mai registrati né salvati su disco.
- **Password sconosciute:** le password degli account di emergenza sono generate casualmente e mai mostrate.
- **Conferme:** ogni modifica deve essere confermata; le conferme sono impostate su "No" per impostazione predefinita.
- **Pulizia in caso di errore:** se la configurazione di una scheda TOTP non riesce, lo strumento rimuove automaticamente le voci create a metà.

> [!CAUTION]
> Eseguire azioni amministrative solo secondo il proprio processo interno di approvazione e sicurezza.

---

## Requisiti e autorizzazioni per gli amministratori

### Requisiti di sistema

- Windows con **Windows PowerShell 5.1** (preinstallato; PowerShell 7 non è supportato perché l'interfaccia usa WPF)
- Accesso a Internet al primo avvio per installare i moduli PowerShell (solo per l'utente corrente, senza diritti di amministratore):
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.SignIns` e `DSInternals.Passkeys` **1.0.6** (FIDO2)
  - `QRCodeGenerator` (codici QR per schede TOTP programmabili)

  In alternativa installarli in anticipo con `Install-Prerequisites.ps1`.
- Per FIDO2 la chiave deve essere collegata al **computer locale** (tramite RDP solo con reindirizzamento WebAuthn).

### Autorizzazioni Graph (delegate)

Tutte le autorizzazioni vengono richieste una sola volta all'accesso, quindi durante il lavoro non compare più alcuna finestra di accesso:

| Autorizzazione | Scopo |
|---|---|
| `User.Read.All` | Cercare utenti |
| `UserAuthenticationMethod.Read.All` | Mostrare i metodi MFA |
| `UserAuthenticationMethod.ReadWrite.All` | Configurare ed eliminare metodi MFA |
| `Policy.ReadWrite.AuthenticationMethod` | Inventario dei token: creare, assegnare ed eliminare schede TOTP, token TOTP importati e MFA fittizia |
| `RoleManagement.Read.Directory` | Mostrare i ruoli di amministratore di un utente |
| `User.ReadWrite.All` | Account di emergenza; salvare la data di invio della guida MFA e il secret cifrato della MFA fittizia nell'oggetto utente |
| `Domain.Read.All` | Account di emergenza: mostrare i domini per la selezione |
| `RoleManagement.ReadWrite.Directory` | Account di emergenza: assegnare Global Administrator |
| `GroupMember.Read.All` | Report MFA: scegliere un gruppo come ambito, risolvere i ruoli assegnati tramite gruppi |
| `AuditLog.Read.All` | Report MFA: ultimo accesso |
| `Policy.Read.All` | Avviso se un metodo è disattivato nel tenant; verifica dell'accesso condizionale |
| `Chat.Create` | Guida MFA come messaggio Teams: chat 1:1 con l'utente |
| `ChatMessage.Send` | Guida MFA come messaggio Teams: invio del messaggio |
| `Mail.Send` | Guida MFA dalla propria casella di posta |
| `Mail.Send.Shared` | Guida MFA da una casella condivisa |
| `Organization.Read.All` | Caricare la chiave hrdnr dal tenant |

Se un'autorizzazione non è stata concessa (consenso rifiutato), la funzione interessata lo segnala; disconnettersi e accedere di nuovo per concederla.

L'ultimo accesso richiede inoltre una licenza **Entra ID P1/P2** e un ruolo che possa leggere i dati di accesso, ad es. **Reports Reader**, **Security Reader** o **Global Reader**. Viene mostrato l'ultimo accesso riuscito (interattivo o non interattivo); Microsoft lo registra da dicembre 2023, i valori precedenti sono l'ultimo tentativo.

Salvare la data di invio della guida MFA richiede un ruolo che possa modificare gli utenti, ad es. **User Administrator**.

### Ruoli Entra necessari per il proprio account

| Attività | Ruolo |
|---|---|
| Gestire i metodi degli utenti normali, TAP | **Authentication Administrator** |
| Gestire i metodi degli amministratori | **Privileged Authentication Administrator** |
| Schede TOTP, importazione TOTP e MFA fittizia | in aggiunta **Authentication Policy Administrator** |
| Account di emergenza | **Global Administrator** (oppure Privileged Role Administrator + User Administrator) |

### Impostazioni del tenant

Nei **criteri dei metodi di autenticazione** (Interfaccia di amministrazione di Entra → Protezione → Metodi di autenticazione) devono essere abilitati i metodi usati:

- **Passkey (FIDO2)**
- **Token OATH hardware** (per schede TOTP e MFA fittizia)
- **Temporary Access Pass** – durata massima di almeno 2 ore

### Note

- Alcune funzioni usano l'**API beta** di Microsoft Graph (ad es. per i token OATH hardware), che può cambiare.
- I ruoli idonei tramite PIM vengono mostrati solo con Entra ID P2.
- La lingua scelta viene salvata in `%APPDATA%\M365MfaTool\settings.json`.

---

## Struttura del progetto

| File | Contenuto |
|---|---|
| `Start.cmd` | Avvio con doppio clic |
| `Start-M365MfaTool.ps1` | Interfaccia, gestione dello stato ed eventi |
| `UI/Theme.xaml` | Aspetto comune di tutte le finestre |
| `UI/MainWindow.xaml` | Layout della finestra principale |
| `UI/BreakGlassDialog.xaml` | Finestra per i nuovi account di emergenza |
| `UI/TenantReportWindow.xaml` | Finestra del report MFA |
| `UI/TotpImportWindow.xaml` | Finestra dell'importazione massiva TOTP |
| `UI/TokenInventoryWindow.xaml` | Finestra dell'inventario dei token |
| `UI/BulkTapWindow.xaml` | Finestra del Temporary Access Pass di massa |
| `UI/MfaGuideDialog.xaml` | Finestra di anteprima della guida MFA |
| `UI/BulkOffboardWindow.xaml` | Finestra dell'offboarding di massa |
| `UI/CampaignWindow.xaml` | Finestra della campagna MFA e della classificazione degli account |
| `UI/SettingsDialog.xaml` | Finestra delle impostazioni |
| `UI/HistoryDialog.xaml` | Cronologia di un utente (registro di controllo) |
| `Modules/Graph.psm1` | Accesso, richieste Graph, utenti, domini, ruoli, semaforo MFA, lettura/eliminazione dei metodi |
| `Modules/Provisioning.psm1` | Configurazione di FIDO2, schede TOTP, MFA fittizia, TAP e account di emergenza |
| `Modules/TenantReport.psm1` | Report MFA: utenti, ruoli, richieste di metodi raggruppate, valutazione a semaforo, esportazione Excel |
| `Modules/Xlsx.psm1` | Writer Excel leggero (.xlsx senza Excel né moduli aggiuntivi) |
| `Modules/MfaGuideMail.psm1` | Guida MFA: e-mail nella lingua dell'utente, invio tramite Graph, data di invio nell'oggetto utente |
| `Modules/Localization.psm1` | Multilingua: carica i file di lingua e fornisce i testi |
| `Languages/*.json` | Testi per lingua (`en.json` è il riferimento) |
| `Mail/Images/` | Screenshot anonimizzati per l'e-mail |
| `Install-Prerequisites.ps1` | Installazione preliminare facoltativa di tutti i moduli |
| `docs/` | Documentazione tradotta e screenshot |
| `Logs/` | File di log giornalieri (creati automaticamente, non salvati in Git) |

---

## Aggiungere una lingua

1. Copiare `Languages/en.json` e rinominarlo con il codice della lingua, ad es. `sv.json` per lo svedese.
2. Impostare `"_language"` sul nome della lingua nella lingua stessa (ad es. `"Svenska"`) e tradurre tutti i testi. I segnaposto come `{0}` devono essere mantenuti.
3. Riavviare lo strumento – la lingua compare automaticamente nella selezione. I testi mancanti vengono mostrati in inglese.
4. Facoltativo: aggiungere una documentazione tradotta come `docs/README.<codice>.md` e collegarla nella barra delle lingue in cima a tutti i file README.
