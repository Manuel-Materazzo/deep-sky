# Considerazioni tecniche: Deep Sky

**Versione:** 0.1 (bozza per revisione) · **Data:** 12 novembre 2026 · **Dipende da:** Project Brief v0.2, Design Brief v0.2

**Destinatario:** agente architetto, e in seguito gli agenti sviluppatori. Questo documento raccoglie le decisioni tecniche prese insieme al promotore, le motivazioni e le questioni ancora aperte. È l’input del documento architetturale, che non deve rimetterle in discussione senza segnalarlo.

**Convenzioni.** **\[Deciso\]** confermato dal promotore. **\[Proposta\]** raccomandazione non ancora validata, da confermare con un prototipo. **\[Aperto\]** questione da risolvere. Gli ID di questo documento sono **TC-xx** (decisioni), **SP-xx** (prototipi di verifica) e **AD-xx** (domande per l’architetto). Gli ID P-xx, F-xx, S-xx, N-xx, D-xx rimandano al Project Brief.

---

## 1. Contesto di partenza

- Utenti iniziali: il promotore e la sua partner, **entrambi su Android**. Nessun Mac a disposizione, nessun account Apple per ora.
- Server iniziale: una VM **Oracle Cloud (OCI) con CPU ARM Ampere**, con script di backup già esistenti da estendere a questa applicazione.
- Distribuzione: **nessun Play Store né App Store per ora**. L’app si installa come APK.
- Obiettivo di rilascio: nessuna scadenza reale. Si costruiscono le funzioni insieme, un po’ per volta, partendo soprattutto dalla grafica.
- Chi ospita la propria istanza (self-hosting) deve poter fare a meno di un servizio gestito dal progetto, entro i limiti dichiarati in questo documento.

## 2. Decisioni prese

| ID | Decisione | Stato |
| :-- | :-- | :-- |
| **TC-01** | App client in **Flutter** | Deciso |
| **TC-02** | Backend in **Java con Spring Boot** e **PostgreSQL** | Deciso |
| **TC-03** | Tutto in **Docker Compose**; immagini del backend **multi-architettura ARM64 e AMD64** | Deciso |
| **TC-04** | **Solo Android** per ora; iOS rimandato | Deciso |
| **TC-05** | **Cifratura end-to-end dalla v1**; lo stato derivato è calcolato da un dispositivo, cifrato e caricato sul server | Deciso |
| **TC-06** | Recupero: **re-invio delle chiavi tra i due telefoni** più **chiave di recupero** da salvare | Deciso |
| **TC-07** | **Sola lettura** quando l’app è offline | Deciso |
| **TC-08** | Scena **data-driven**: manifest più slot di immagini a livelli | Deciso |
| **TC-09** | Animazione: **livello 1** con più livelli sovrapposti per slot; **livello 3** (scheletrica o a parti) come obiettivo finale | Deciso |
| **TC-10** | **Aggiornamenti integrati dalla v1**, a due livelli: pacchetti di contenuti e APK da **release GitHub** | Deciso |
| **TC-11** | Backup: estensione degli script esistenti sulla VM OCI | Deciso |
| **TC-12** | Sviluppo a **fette verticali** (grafica, codice e asset insieme) con rilasci frequenti | Deciso |
| **TC-13** | Push con **FCM** e credenziali Firebase fornite a runtime dal server | Proposta, da validare con SP-01 |

## 3. Stack e motivazioni

### 3.1 Client: Flutter (TC-01)

L’interfaccia è illustrata (scena, canvas del disegno, animazioni) e un unico motore di rendering fa sì che il design system appaia identico su tutti i dispositivi. Resta fuori dal framework:

- i **widget della home screen** (F-13) richiedono codice nativo Android (Kotlin), da integrare con il progetto Flutter;
- l’installazione degli APK (TC-10) richiede un canale nativo verso le API di sistema;
- le notifiche e l’eventuale inizializzazione di Firebase a runtime (TC-13) hanno parti native.

### 3.2 Backend: Spring Boot e PostgreSQL (TC-02)

La scelta è del promotore e si fonda su competenze, ecosistema maturo (sicurezza, migrazioni, test, salute del servizio) e su Postgres, già coperto dagli script di backup esistenti. L’alternativa valutata (Go con SQLite) offriva un footprint minore per chi fa self-hosting, ma non una superiorità tecnica. Accorgimenti da adottare:

- **limiti di memoria della JVM e di Postgres espliciti** nel compose, scelti in base alle risorse della VM;
- **consumo reale misurato** (SP-05) per dichiarare i requisiti minimi del self-hosting, senza stimarli;
- migrazioni dello schema versionate e verifica di salute dei servizi nel compose;
- il backend è **sottile**: autentica, conserva blob e stato cifrati, instrada, attiva il push. Non vede i contenuti (TC-05).

### 3.3 Docker e architetture (TC-03)

Tutto gira con Docker Compose. Il backend deve essere costruito per **ARM64** (VM OCI) e **AMD64** (altri self-hoster). La pipeline di build produce immagini multi-architettura. Lo schema di compose, la rete e l’esposizione verso Internet sono demandati all’architetto (AD-04).

## 4. Notifiche push (TC-13)

### 4.1 Cosa fa Kehai

Il progetto Kehai, che avevamo esplorato, **non usa Firebase**. Il suo repository mostra questa architettura:

- un server **ntfy** self-hosted con **UnifiedPush** per il push;
- un client Flutter che, oltre all’app ntfy installata come “distributore”, mantiene un **servizio in primo piano** con notifica permanente e connessione WebSocket realtime al server;
- rete pensata per **Tailscale**, senza porte esposte.

Vantaggi: nessuna dipendenza da Google, nessun progetto Firebase da creare. Costi: una **seconda app** da installare e configurare (per ntfy), connessioni persistenti che i sistemi di risparmio energia dei produttori possono interrompere, e una **notifica permanente** che contrasta con P-02 e V-08 (nessuna pressione, nessun elemento che reclami attenzione). Per il partner non tecnico (P-09) il carico di configurazione è alto.

### 4.2 Proposta: FCM con configurazione a runtime

**\[Proposta\]** FCM resta il canale principale su Android: è efficiente per la batteria perché sfrutta la connessione già mantenuta da Google, e non richiede una seconda app. L’obiezione iniziale era che le credenziali Firebase sono legate alla build. In realtà l’SDK può essere inizializzato **a runtime** con parametri (identificativo del progetto, chiave API, identificativo dell’app, sender ID) che l’app riceve dal **server** del self-hoster al momento dell’abbinamento. Conseguenze:

- **un solo APK ufficiale per tutti**, senza che ogni self-hoster debba compilare la propria app;
- il self-hoster crea un progetto Firebase e inserisce nella configurazione del server i parametri client e la chiave di servizio per inviare;
- nessun relay gestito dal progetto, finché si resta su Android.

Punto da verificare (**SP-01**): l’inizializzazione di Firebase quando il processo viene risvegliato da un push ad app chiusa, che deve poter avvenire prima dell’arrivo del messaggio (parametri salvati localmente e applicati all’avvio del processo).

### 4.3 Contenuto delle notifiche

Coerentemente con S-02, il push non trasporta contenuti: è un “risveglio” con una chiave di localizzazione, e il testo generico è composto dal telefono (“Hai un pensiero in arrivo”). I contenuti arrivano dopo, sincronizzati e cifrati. Notifiche più ricche sono rimandate e richiederebbero decifratura locale.

### 4.4 Alternative e futuro

UnifiedPush resta un’opzione per telefoni senza servizi Google, come funzione opzionale futura. Con iOS tornerebbero necessari un account sviluppatore a pagamento e un relay gestito dal progetto.

## 5. La scena (TC-08, TC-09)

Non serve un motore di gioco. La scena è una composizione di immagini a livelli, descritta da un **manifest** consegnato dal designer.

- **Slot:** ogni oggetto ha ID, posizione in coordinate normalizzate, dimensione, ordine di sovrapposizione, **area di tocco** definita nel manifest (non ricavata dai pixel trasparenti), stati (es. luce spenta e accesa) ed etichette per l’accessibilità.
- **Personalizzazione (F-18):** sostituisce soltanto il file collegato a uno slot; il manifest non cambia.
- **Proporzioni degli schermi:** area di scena a proporzione fissa con fondale che sborda (bleed).
- **Memoria:** immagini decodificate alla risoluzione di visualizzazione; derivati per più densità prodotti dalla pipeline (A-02 del Design Brief).
- **Animazione livello 1 (TC-09):** trasformazioni, opacità e dissolvenze su livelli, con più livelli sovrapposti per slot (ombre, luci, particelle, accessori). Il manifest descrive tipo, durata, curva e ripetizione delle animazioni per slot.
- **Obiettivo finale, livello 3:** animazione scheletrica o a parti 2D. Strumento e formato non sono scelti (DD-11); non è escluso che un agente possa produrla con un formato adatto. L’architettura della scena non deve rendere difficile il passaggio: le animazioni sono dati nel manifest, non logica cablata nel codice.
- **Reazioni del pet:** lo stato derivato (cosa mostra il pet in base alle attività) è calcolato da **un dispositivo** e caricato cifrato (TC-05), non ricalcolato in modo deterministico sui due telefoni, perché le due app possono avere versioni diverse.

## 6. Cifratura e sincronizzazione (TC-05, TC-06)

### 6.1 Modello

- Il server conserva **solo dati cifrati** e metadati minimi. Vede inevitabilmente: l’esistenza e l’identità tecnica degli account o dispositivi, orari, dimensioni dei dati, token di push.
- Gli **eventi** (gesti, disegni, umori, foto) formano il log condiviso, fonte di verità.
- Lo **snapshot** dello stato derivato è una cache ricostruibile, calcolata dal dispositivo che genera l’evento, cifrata e caricata.
- Lo snapshot ha una **versione dello schema**. In caso di scritture concorrenti vale la **concorrenza ottimistica**: se il server ha già una versione più recente, il dispositivo ricalcola e riprova.

### 6.2 Abbinamento e recupero

- Le chiavi nascono e restano sui dispositivi; lo scambio avviene all’abbinamento (invito con link o QR, F-01).
- **Nuovo telefono:** l’altro telefono re-invia le chiavi al nuovo dispositivo (F-20).
- **Chiave di recupero:** generata all’abbinamento; l’app richiede la **conferma di avvenuto salvataggio**.
- Garanzia dichiarata all’utente: i dati sono recuperabili **finché esiste l’altro telefono o la chiave salvata**. L’escrow di chiavi sul server (cifrate con passphrase) è stato **scartato** per ora.
- La **perdita della chiave di firma dell’APK** impedisce di aggiornare le installazioni esistenti: obbliga a reinstallare e a perdere le chiavi locali. Ulteriore motivo per cui la chiave di recupero è obbligatoria, e per cui la chiave di firma va custodita e salvata con cura (AD-08).

### 6.3 Scelte demandate all’architetto

Primitive crittografiche, protocollo di scambio delle chiavi, modello di autenticazione dei dispositivi e gestione delle chiavi sono demandati al documento architetturale (AD-01, AD-02). Il documento deve citare librerie mature e ben mantenute, non crittografia scritta ad hoc, e prevedere una revisione indipendente prima di dichiarare la promessa di privacy (P-06).

## 7. Offline e cache (TC-07)

Senza connessione l’app è in **sola lettura**: scena e ricordi consultabili da una **cache locale**; le azioni di scrittura sono disattivate con un messaggio gentile (P-02, V-08). Non c’è coda di sincronizzazione, né conflitti offline da gestire. La protezione della cache locale (cifratura a riposo, uso del keystore del sistema) è demandata all’architetto (AD-06).

## 8. Aggiornamenti integrati (TC-10)

L’app ha due meccanismi complementari fin dalla v1.

### 8.1 Livello 1: pacchetti di contenuti

Asset, manifest della scena e testi sono scaricati dal server, **verificati** (hash e firma) e applicati **senza installare nulla**. Consente di far evolvere la grafica un po’ per volta senza nuove versioni dell’APK. Non contengono codice eseguibile.

### 8.2 Livello 2: APK da release GitHub

- L’app controlla le **release GitHub** del progetto (sorgente configurabile, per chi usa un fork o un proprio canale). La release contiene l’APK e un **manifest** con versione, hash SHA-256 e firma.
- Prima dell’installazione l’app verifica hash e firma del manifest con una **chiave pubblica incorporata**, in aggiunta al controllo di Android, che accetta l’aggiornamento solo se firmato con la stessa chiave dell’app installata.
- Il permesso necessario è quello per app “**Installa app sconosciute**” (non le impostazioni sviluppatore), concesso una volta; l’installazione passa dal **PackageInstaller** di Android, con la conferma di sistema. Quanto la conferma possa ridursi negli aggiornamenti successivi dipende dalla versione di Android e va verificato (SP-03), senza prometterlo agli utenti.
- Il server può imporre una **versione minima del client e del protocollo**: se un’app è troppo vecchia mostra una schermata “aggiornamento richiesto” (F-19). Serve soprattutto per la compatibilità degli snapshot cifrati (6.1).
- Un precedente simile esiste in Kehai: APK di release, permesso di installazione, conferma dell’utente sulla schermata di sistema e firma con la chiave del progetto per un aggiornamento sul posto che conserva i dati.
- Da valutare: limiti di richieste verso GitHub (controlli condizionali, controllo non a ogni avvio).

### 8.3 Verifica degli sviluppatori Android (D-14)

Google sta introducendo la **verifica dell’identità degli sviluppatori** anche per le app installate fuori dal Play Store. Secondo i suoi annunci, l’applicazione è partita il 30 settembre 2026 in Brasile, Indonesia, Singapore e Thailandia ed è prevista a livello globale dal 2027; chi non completa la verifica può trovare limiti a installazioni e aggiornamenti. Esistono un **account a distribuzione limitata** (fino a 20 dispositivi, senza documento d’identità né costi) per hobbisti e un **flusso avanzato** per installare app di sviluppatori non verificati. Per noi:

- il dogfooding tra due persone rientra nell’account a distribuzione limitata;
- un **APK ufficiale distribuito pubblicamente** richiederà verosimilmente la verifica completa (oltre i 20 dispositivi) quando la regola raggiungerà l’Italia;
- **nome del pacchetto e chiave di firma devono restare stabili** fin dalla prima build;
- da ricontrollare lo stato delle regole prima di ogni decisione sulla distribuzione pubblica.

## 9. Deployment e operazioni

- Servizi nel compose: backend, PostgreSQL, ed eventualmente un reverse proxy con TLS (AD-04).
- Dati persistenti: database e blob cifrati (immagini) su volume, inclusi nel **backup** esteso dagli script esistenti. Con la cifratura end-to-end i backup contengono solo dati cifrati: senza chiavi dei partner non sono leggibili. Il processo di ripristino va provato, non solo la creazione del backup.
- Configurazione del self-hoster: parametri Firebase (TC-13), segreti del server, sorgente degli aggiornamenti (8.2).
- Pipeline di build: immagini multi-architettura, APK firmato, pubblicazione della release con manifest firmato.
- Un solo APK ufficiale per tutti, grazie alla configurazione a runtime (TC-13). Chi vuole compilare la propria versione può farlo, ma non è un requisito del self-hosting.

## 10. Prototipi di verifica

Prima di fissare l’architettura conviene verificare i punti incerti con prototipi piccoli e usa-e-getta.

| ID | Prototipo | Domanda a cui risponde |
| :-- | :-- | :-- |
| **SP-01** | Notifica FCM con inizializzazione a runtime, ad app chiusa, su due telefoni Android reali | La configurazione ricevuta dal server basta a ricevere push anche a processo chiuso? |
| **SP-02** | Abbinamento con scambio di chiavi, chiave di recupero e nuovo dispositivo | Il flusso di recupero è comprensibile e sicuro? Quali metadati vede il server? |
| **SP-03** | Aggiornamento APK da release GitHub con verifica di hash e firma | Quanta interazione chiede Android? Cosa succede con chiave diversa o manifest alterato? |
| **SP-04** | Scena con due slot, un livello animato e una sostituzione di asset, su telefoni reali | Prestazioni, memoria, proporzioni diverse, aree di tocco |
| **SP-05** | Spring Boot più PostgreSQL sulla VM ARM, con limiti di memoria | Consumo reale e requisiti minimi dichiarabili |

## 11. Rischi tecnici

Tabella aggiornata all’uscita della milestone **M1 (`G-1`)**; per le contromisure architetturali complete e la lista di revisione **`G-5`** si vedano il [Documento architetturale v0.2](architecture.md) e gli [ADR](adr/README.md).

| Rischio | Impatto | Mitigazione | Stato post-M1 (`G-1`) |
| :-- | :-- | :-- | :-- |
| Inizializzazione runtime di FCM non affidabile a processo chiuso | Push non consegnati | SP-01; interfaccia `PushProvider` (AR-10) per eventuale passaggio a UnifiedPush / build dedicata | **Aperto (parzialmente mitigato):** ad app aperta e in background verificato su `proto/sp-01` (`ADR-0006`); verifiche a task switcher chiuso, riavvio e Doze riportate in testa a M2 prima di congelare AR-10 |
| Errori nella cifratura end-to-end o nel recupero | Perdita di dati o falsa promessa di privacy | Librerie mature (`cryptography`, `bip39_mnemonic`), SP-02, revisione indipendente (`G-5`) | **In mitigazione:** protocollo implementato e testato (`ADR-0005`); verifiche su telefoni fisici / utenti non tecnici e rotazione post-revoca pianificate tra M2 e `G-5` |
| Perdita della chiave di firma dell’APK | Impossibile aggiornare, reinstallazione e perdita delle chiavi locali | Custodia e backup cifrato offline (`PD-10`, `docs/key-custody.md`), chiave di recupero obbligatoria, guard pre-sessione su `PackageInstaller` | **Mitigato:** flusso offline documentato (`M0`); guard certificati pre-installazione validato in `proto/sp-03` (`ADR-0008`); resta il controllo su dispositivo fisico del flusso di upgrade firmato |
| Verifica degli sviluppatori Android estesa all’Italia | APK ufficiale pubblico bloccato o ostacolato | D-14, nome pacchetto `com.vectevo.deep_sky` (`PD-07`) e chiave stabili, monitoraggio delle regole | **Monitorato:** dogfooding compatibile con fascia limitata (`<= 20` dispositivi); da rivalutare prima di aperture pubbliche |
| Incompatibilità tra versioni diverse dell’app sui due telefoni | Stato cifrato illeggibile | `schemaVersion` su snapshot e buste, enforcement versione minima lato server (`F-19`), controllo `versionCode` in `SP-03` | **In mitigazione:** versione minima e anti-downgrade previsti nel design `SP-02`/`SP-03`; enforcement completo end-to-end da integrare in M2 (`SL` / `F-19`) |
| Memoria e prestazioni con molte immagini AI | App lenta o instabile | Derivati per densità, decodifica alla dimensione di visualizzazione, livelli isolati (`RepaintBoundary`) e reduce motion (`SP-04`) | **Chiuso in M1 (da sorvegliare su asset definitivi):** soglie, accessibilità e validazione designer superate in `proto/sp-04` (`ADR-0007`) |
| Consumo della JVM su VM piccole | Self-hosting costoso per altri | Limiti JVM/PostgreSQL espliciti nel Compose, benchmark replicabile `SP-05`, requisiti minimi dichiarati | **Chiuso in M1:** profili memoria, stabilità senza OOM e requisiti minimi validati dal promotore (`ADR-0009`); profili benchmark esclusi dal profilo `prod` |

## 12. Domande per l’architetto

Il documento architetturale deve rispondere almeno a queste domande, riportando alternative con pro e contro.

| ID | Domanda |
| :-- | :-- |
| **AD-01** | Primitive e protocollo crittografico, e modello di scambio delle chiavi all’abbinamento |
| **AD-02** | Autenticazione dei dispositivi e delle sessioni, senza account pubblici |
| **AD-03** | Modello dei dati: log degli eventi, snapshot, blob; trasporto (richieste HTTP più canale realtime) |
| **AD-04** | Esposizione di rete (D-13): HTTPS pubblico dietro reverse proxy oppure rete privata |
| **AD-05** | Un server ospita **una sola coppia** o **più coppie**? Impatta isolamento dei dati, quote e sicurezza |
| **AD-06** | Cache locale cifrata e uso del keystore del sistema |
| **AD-07** | Archiviazione dei blob (immagini) e dimensionamento dei backup |
| **AD-08** | Custodia della chiave di firma dell’APK e della chiave di firma dei manifest di aggiornamento |
| **AD-09** | Strategia di test (unitari, integrazione con database reale, end-to-end sui dispositivi, sicurezza) |
| **AD-10** | Osservabilità minima senza telemetria che violi S-07 |

## 13. Prossimi passi

1. Documento architetturale, a partire da questo documento, dal Project Brief e dal Design Brief.
2. Esecuzione dei prototipi SP-01 e SP-02, i più rischiosi, prima di fissare i dettagli.
3. Definizione delle interfacce tra manifest della scena, pacchetti di contenuti e design system, in accordo con il designer.
4. Piano di sviluppo a fette verticali (TC-12).

## 14. Tracciabilità

Ogni documento successivo cita gli ID di questo documento (TC-xx, SP-xx, AD-xx) e del Project Brief e del Design Brief da cui discende. In caso di conflitto con una decisione **\[Deciso\]** il conflitto va segnalato al promotore, senza risolverlo in autonomia.
