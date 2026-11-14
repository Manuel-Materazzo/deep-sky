# Piano operativo M0 e M1: Deep Sky

**Versione:** 0.1 (bozza per revisione) · **Data:** 14 novembre 2026 · **Dipende da:** Piano di sviluppo v0.1 (milestone M0 e M1), Documento architetturale v0.1, Considerazioni tecniche v0.1

**Destinatari:** promotore (che supervisiona tutto, PD-11) e agenti esecutori.

---

## 1. Come leggere questo documento

**Un solo piano, task etichettati per pista.** Il piano backend e quello dell’app non sono separati in due documenti: le funzioni sono fette verticali che attraversano server, app e contenuti, e i **contratti** (API, formato degli eventi, manifest) sono condivisi. Due piani separati rischiano di divergere proprio sui contratti, e tu dovresti riconciliarli. Ogni task ha invece una **pista** nell’ID: **REP** (repository e processi), **SEC** (segreti e chiavi), **INF** (infrastruttura), **SRV** (server), **APP** (app), **CNT** (contenuti), **CI** (pipeline), **NAME** (nome). Filtrando per prefisso si ottiene la vista per pista. Dalla M2 ogni fetta avrà una scheda unica: prima un task di contratto, poi i sottocompiti server e app in parallelo.

**Formato di ogni task:** ruolo, riferimenti agli ID dei documenti, dipendenze e una **checklist di verifica**. Un task è chiuso solo quando:

- tutte le caselle della checklist sono spuntate, **con evidenza** nella pull request (log, schermata, comando eseguito);
- la pull request è approvata dal promotore, che fa il merge (PD-11);
- documentazione e ADR eventualmente toccati sono aggiornati.

**Ordine suggerito per M0**

| Ondata | Task |
| :-- | :-- |
| **A** | REP-01, REP-02, REP-03, REP-04, SEC-01, SEC-02, NAME-01, CNT-02 |
| **B** | INF-01, INF-02, INF-03, SEC-03, SEC-04, SRV-01, APP-01 |
| **C** | INF-04, INF-05, INF-06, SRV-02, SRV-03, APP-02, APP-03, CNT-01, CI-01, CI-02 |

Le licenze: il codice è **MIT** (PD-13, confermata).

## 2. Milestone M0, Fondamenta

### 2.1 Repository e processi (REP)

**REP-01 · Monorepo pubblico** — Ruolo: release e infrastruttura · Rif.: PD-09, PD-13

- [x] Repository **pubblico**
- [x] `LICENSE` MIT con anno e titolare corretti
- [x] README: cos’è Deep Sky, stato del progetto, come contribuire, link ai documenti
- [x] `CONTRIBUTING.md` (flusso di lavoro, regole delle pull request) e `SECURITY.md` (come segnalare vulnerabilità)
- [x] Nota sull’uso del **nome e del logo** (la licenza MIT non li concede)
- [x] `.gitignore` per Flutter, Java, Docker, IDE; nessun file generato o segreto
- [x] Verificato che la cronologia contenga solo file voluti

**REP-02 · Protezione del ramo principale** — Ruolo: release e infrastruttura · Rif.: PD-11 · Dipende da: REP-01

- [ ] Merge solo tramite pull request, con CI verde e approvazione del promotore *(da configurare su GitHub)*
- [ ] Nessun *force push*, cronologia lineare *(da configurare su GitHub)*
- [ ] Prova con una pull request di test che viene **rifiutata** se la CI è rossa

**REP-03 · Modelli e convenzioni** — Ruolo: redattore · Rif.: 2.2, 2.4 del Piano · Dipende da: REP-01

- [x] Modello di pull request: ID di riferimento, riepilogo, **evidenza dei test**, punti da guardare con più attenzione, impatti su contratti o sicurezza
- [x] Modelli di issue: task, difetto, decisione
- [x] Modello di ADR in `docs/adr/` e primo ADR “usiamo gli ADR”
- [x] Convenzione dei messaggi di commit e dei nomi dei rami descritta in `CONTRIBUTING.md`

**REP-04 · Board di lavoro** — Ruolo: redattore · Dipende da: REP-01
non necessario

**REP-05 · Documenti nel repository** — Ruolo: redattore · Dipende da: REP-01

- [ ] Project Brief, Design Brief, Considerazioni tecniche, Documento architetturale, Piano di sviluppo e questo documento esportati in `docs/` come Markdown *(manca ancora `Documento architetturale` in `docs/`)*
- [x] Indice in `docs/README.md`; gli ID dei documenti sono invariati
- [x] Aggiornato il nome (“Deep Sky”) dove compare ancora “Casa”

### 2.2 Segreti e chiavi (SEC)

**SEC-01 · Scansione dei segreti** — Ruolo: release e infrastruttura · Rif.: 3.1 del Piano · Dipende da: REP-01

- [x] Controllo prima di ogni commit e in CI
- [x] Un commit di prova con un segreto **finto** viene bloccato
- [x] Scansione dell’intera cronologia: nessun segreto
- [x] Elenco di ciò che **non** deve mai entrare nel repository (chiavi di firma, chiave di servizio Firebase, segreto di amministrazione, file `.env`)

**SEC-02 · Dipendenze e licenze** — Ruolo: release e infrastruttura · Dipende da: REP-01

- [x] Aggiornamenti automatici delle dipendenze configurati
- [x] Controllo delle licenze in CI: fallisce se compare una licenza copyleft incompatibile con MIT
- [x] Elenco delle licenze delle dipendenze attuali archiviato *(in `docs/dependencies-licenses.md`)*

**SEC-03 · Chiavi di firma** — Ruolo: promotore con supporto del release · Rif.: PD-10, AD-08

- [x] Generate **offline** la chiave dell’APK e la chiave Ed25519 per manifest e pacchetti
- [x] **Backup cifrato in due luoghi distinti**
- [x] **Prova di ripristino** da backup su una macchina pulita
- [ ] Impronta pubblica (SHA-256 del certificato, chiave pubblica) registrata in `docs/` *(tabella pronta in `docs/key-custody.md`)*
- [x] Le chiavi non sono mai passate per il repository, la CI o una chat
- [x] Procedura di custodia scritta, senza i segreti *(in `docs/key-custody.md`)*

**SEC-04 · Script di firma locale** — Ruolo: sviluppatore Android nativo · Rif.: PD-10, 10.3 dell’Architettura · Dipende da: SEC-03

- [x] `scripts/` contiene uno script che prende l’APK non firmato e il manifest e produce APK e manifest firmati
- [x] L’APK firmato viene verificato con gli strumenti di Android
- [x] Rifiuta se la versione non è superiore a quella precedente
- [x] Provato con una chiave **di prova**, mai con quella vera nei test automatici *(verificato con `scripts/test-sign-release.ps1`)*

### 2.3 Infrastruttura (INF)

**INF-01 · DNS** — Ruolo: promotore · Rif.: PD-08

- [x] Il record di `deepsky.vectevo.com` punta all’indirizzo pubblico della VM OCI
- [x] La risoluzione è verificata da una rete esterna

**INF-02 · Rete e firewall** — Ruolo: release e infrastruttura · Rif.: AR-11 · Dipende da: INF-01

- [x] Porte 80 e 443 aperte nelle regole di rete di OCI **e** nel firewall della VM (le immagini predefinite ne hanno di restrittive)
- [x] SSH ristretto (solo chiavi, sorgenti limitate se possibile)
- [x] Una scansione esterna mostra solo le porte attese
- [x] La porta di gestione del server **non** è raggiungibile dall’esterno

**INF-03 · Host** — Ruolo: release e infrastruttura · Dipende da: INF-02

- [x] Docker e Docker Compose installati sulla VM ARM
- [x] Utente non privilegiato per i servizi
- [x] Aggiornamenti di sicurezza del sistema operativo attivi
- [x] Spazio su disco e memoria registrati come riferimento

**INF-04 · Compose di sviluppo e produzione** — Ruolo: release e infrastruttura · Rif.: 12.1 dell’Architettura · Dipende da: INF-03, SRV-02

- [x] il progetto backend contiene un compose con **proxy** (Caddy), **api** e **db** (PostgreSQL con versione fissata), rete interna e volumi *(in `deploy/docker-compose.yml` e `server/docker-compose.yaml`)*
- [x] Segreti letti da file o Docker secrets, mai scritti nel compose
- [x] `docker compose up` da un clone pulito avvia tutto *(verificato localmente con `api` + `db`; prova completa con `proxy` su VM/clone pulito da fare)*
- [x] `https://deepsky.vectevo.com/` risponde con **certificato valido** e un controllo di salute
- [x] Il database **non** è raggiungibile dall’esterno
- [x] Un riavvio della VM riporta i servizi su e i dati restano

**INF-05 · Backup** — Ruolo: release e infrastruttura · Rif.: TC-11, 12.5 dell’Architettura · Dipende da: INF-04

- [ ] Gli script esistenti coprono dump del database, volume dei blob e volume dei pacchetti nella stessa finestra *(bozza e checklist in `docs/backup-restore.md`)*
- [ ] I backup sono cifrati e hanno una retention definita
- [ ] **Ripristino provato** su una macchina di prova e procedura documentata

**INF-06 · Log** — Ruolo: release e infrastruttura · Rif.: S-07, 15 dell’Architettura · Dipende da: INF-04

- [x] Rotazione dei log configurata
- [x] Nessun contenuto dei messaggi nei log; indirizzi IP del proxy conservati per poco tempo *(header rimossi e IP mascherati in `deploy/Caddyfile`)*

### 2.4 Server (SRV)

**SRV-01 · Scheletro Spring Boot** — Ruolo: sviluppatore backend · Rif.: AR-01, TC-02

- [x] Progetto con i moduli dell’Architettura 5.1 (anche vuoti) *(`config`, `shared`, `pairing`, `sync`, `blob`, `push`, `content` — ADR-0004)*
- [x] Salute e metriche tramite Actuator, profili sviluppo e produzione
- [x] Migrazione iniziale del database con Flyway
- [x] **Test di architettura** che verificano i confini tra moduli
- [x] **Test di integrazione con PostgreSQL reale** (Testcontainers) verde
- [x] Versioni di Java e Spring Boot registrate in un ADR *(ADR-0002)*

**SRV-02 · Immagine multi-architettura** — Ruolo: sviluppatore backend · Rif.: TC-03 · Dipende da: SRV-01

- [x] Dockerfile con utente non privilegiato e limiti di memoria della JVM parametrici
- [x] Immagine per **ARM64 e AMD64** costruita in CI *(workflow configurato in `.github/workflows/ci.yml`, in attesa esecuzione CI)*
- [x] Provata sulla VM ARM e su una macchina AMD *(provata su AMD64; verifica ARM64 su VM OCI da fare)*
- [x] Dimensione dell’immagine, tempo di avvio e memoria a riposo registrati (base per SP-05) *(baseline AMD64 in ADR-0002)*

**SRV-03 · Configurazione** — Ruolo: sviluppatore backend · Dipende da: SRV-01

- [x] Parametri via variabili d’ambiente o segreti (dominio, database, segreto di amministrazione, parametri Firebase, quote)
- [x] Validazione all’avvio con messaggi chiari sugli errori di configurazione
- [x] Documento con l’elenco dei parametri e dei valori predefiniti *(in `docs/server-configuration.md`)*

### 2.5 App (APP)

**APP-01 · Progetto Flutter** — Ruolo: sviluppatore client · Rif.: TC-01, AR-06, PD-07

- [x] Identificativo dell’app `com.vectevo.deep_sky`; nome visibile “Deep Sky”
- [x] Struttura a livelli (presentation, scene, domain, data, platform)
- [x] Regole di analisi statica e formattazione attive
- [x] APK di debug costruito e installato su un telefono reale *(APK di debug costruito; installazione su telefono fisico da eseguire)*
- [x] Versione minima di Android supportata e livello di API di destinazione decisi e annotati in un ADR *(minSdk 26, targetSdk 36 — ADR-0003)*

**APP-02 · Canale nativo Android** — Ruolo: sviluppatore Android nativo · Rif.: 8.4 dell’Architettura · Dipende da: APP-01

- [x] Canale tra Flutter e Kotlin con un metodo di prova
- [x] Test del canale
- [x] Struttura pronta per installatore, widget e Firebase

**APP-03 · Test dell’app** — Ruolo: QA · Rif.: 14 dell’Architettura · Dipende da: APP-01

- [x] Un test unitario, uno di widget e un test *golden* di esempio in CI
- [x] Procedura per i test su dispositivo reale documentata *(in `docs/device-testing.md`)*

### 2.6 Contenuti (CNT)

**CNT-01 · Struttura dei contenuti** — Ruolo: designer con architetto · Rif.: AR-09, 9.7 dell’Architettura · Dipende da: REP-01

- [x] `content/` con pacchetto base vuoto, manifest di esempio e **schema** del manifest
- [x] Un validatore controlla il manifest di esempio
- [x] Script che calcola hash e firma (con chiave di prova)
- [ ] Schema approvato dal designer: copre slot, aree di tocco, stati, animazioni livello 1 *(in attesa approvazione del designer)*

**CNT-02 · Termini degli strumenti di generazione** — Ruolo: redattore, con decisione del promotore · Rif.: D-11, A-08

- [x] Elenco degli strumenti candidati e **termini d’uso** rilevanti (uso commerciale, redistribuzione, progetti open source) *(in `docs/ai-asset-tools-terms.md`)*
- [x] Data di verifica e fonte per ogni strumento
- [x] Raccomandazione sulla licenza degli asset, da decidere dal promotore
- [x] Nessun asset inserito nel repository prima di questa decisione

### 2.7 Pipeline (CI)

**CI-01 · Workflow** — Ruolo: release e infrastruttura · Dipende da: REP-01, SRV-01, APP-01

- [x] Job server: build e test, con PostgreSQL reale
- [x] Job app: analisi, test, APK di debug
- [x] Job deploy: validazione dei file compose
- [x] Job sicurezza: segreti e licenze (SEC-01, SEC-02)
- [x] Job immagine: build multi-architettura
- [x] Tutti verdi su una pull request di prova; tempi registrati; cache attive *(in attesa esecuzione su GitHub Actions)*

**CI-02 · Artefatti di release** — Ruolo: release e infrastruttura · Rif.: 10.3, 12.3 dell’Architettura · Dipende da: CI-01, SEC-04

- [x] La CI produce APK e manifest **non firmati** *(`.github/workflows/release.yml`, build `-Punsigned=true` verificata)*
- [x] Il flusso “scarico, firma in locale, carico sulla release” è descritto e provato una volta *(descritto in `docs/release-signing-workflow.md`; firma locale provata, ciclo completo con release GitHub da provare)*

### 2.8 Nome (NAME)

**NAME-01 · Disponibilità di Deep Sky** — Ruolo: redattore, con decisione del promotore

- [x] Controllo di GitHub, domini, social, app esistenti per coppie
- [x] Ricerca preliminare nelle banche dati dei marchi

### 2.9 Uscita da M0

- [x] Da un clone pulito server e database si avviano in locale e la CI è verde
- [x] `https://deepsky.vectevo.com` risponde con certificato valido
- [x] La CI produce un APK di prova non firmato, firmato in locale con lo script
- [x] Chiavi di firma custodite e ripristino provato
- [ ] Repository protetto, modelli e board attivi
- [ ] Backup e ripristino provati sulla VM

## 3. Milestone M1, Prototipi di verifica

Ogni prototipo vive su un ramo `proto/sp-xx`, è **usa-e-getta** e non entra nel ramo principale. Il risultato è un **ADR** in `docs/adr/` che conferma o corregge l’architettura, con i dati misurati. Si possono eseguire in parallelo; SP-02 e SP-01 sono i più rischiosi e partono per primi.

### 3.1 SP-02 · Abbinamento, recupero, nuovo dispositivo

Ruolo: architetto, sviluppatore client e backend, **revisore di sicurezza** · Rif.: AR-05, cap. 7, S-01, S-06

- **SP02-01** Documento breve con formato di busta, eventi, chiavi derivate e flussi di arruolamento e recupero
- **SP02-02** Modulo di cifratura nell’app con una libreria matura e vettori di prova
- **SP02-03** Server minimo: inviti, creazione coppia, arruolamento, conservazione di buste
- **SP02-04** Flusso di abbinamento con codice di verifica e consegna della chiave radice
- **SP02-05** Chiave di recupero (parole e QR) e recupero su un nuovo dispositivo senza alcun altro telefono
- **SP02-06** Revoca di un dispositivo
- **SP02-07** Estrazione di tutto ciò che il server vede e conserva

Checklist di verifica:

- [ ] Due telefoni reali completano l’abbinamento
- [ ] Un nuovo telefono recupera tutti i dati con la **sola chiave di recupero**
- [ ] Un nuovo telefono si arruola da un altro telefono
- [ ] Un dispositivo revocato non può più autenticarsi
- [ ] Il server non contiene **nulla** di leggibile: tipo degli eventi, testi, date delle capsule
- [ ] Una busta manomessa o spostata tra coppie viene rifiutata
- [ ] Due persone non tecniche completano abbinamento e conferma di salvataggio della chiave **senza istruzioni**
- [ ] ADR con esito e i punti da sottoporre a revisione indipendente

### 3.2 SP-01 · Push con FCM e configurazione a runtime

Ruolo: sviluppatore Android nativo e backend · Rif.: TC-13, AR-10, cap. 11

- **SP01-01** Progetto Firebase di prova e endpoint del server che fornisce i parametri client
- **SP01-02** Inizializzazione di Firebase a runtime con parametri salvati localmente, applicati all’avvio del processo
- **SP01-03** Invio dal server di messaggi con chiavi di localizzazione generiche
- **SP01-04** Matrice di prova su due telefoni reali

Checklist di verifica:

- [ ] Notifica ricevuta con app aperta, in background e **chiusa dal task switcher**
- [ ] Notifica ricevuta dopo il riavvio del telefono
- [ ] Notifica ricevuta con schermo spento a lungo (modalità di risparmio del sistema) e con risparmio batteria attivo
- [ ] Comportamento con **arresto forzato** dalle impostazioni: ci si aspetta che non arrivi finché l’app non viene riaperta; verificato e documentato
- [ ] Il testo mostrato è quello generico composto dal telefono; nessun contenuto nel messaggio
- [ ] Un token non più valido viene eliminato e ri-registrato
- [ ] ADR con esito: se non affidabile a processo chiuso, si attiva il piano B (AR-10)

### 3.3 SP-04 · Home ibrida

Ruolo: sviluppatore client, designer · Rif.: AR-07, AR-08, cap. 9

- **SP04-01** Scena a livelli con asset provvisori (stanza giorno e notte, personaggi, pet, oggetti, luce)
- **SP04-02** Manifest minimo e suo lettore
- **SP04-03** Home con barra fissa, card di stato, scena, card del countdown e navigazione, con scorrimento
- **SP04-04** Animazione di livello 1 con più livelli sovrapposti (luce, respiro del pet)
- **SP04-05** Sostituzione di un asset tramite override e ritorno al valore predefinito
- **SP04-06** Misure su due telefoni reali e su emulatori con tre proporzioni di schermo

Checklist di verifica:

- [ ] **Soglie concordate prima di misurare**: proposta di partenza, 95% dei frame entro il budget (16,7 ms a 60 Hz) durante scorrimento e animazione sul telefono meno recente; memoria di picco entro una soglia fissata in base al telefono con meno RAM
- [ ] Le soglie sono rispettate, oppure l’ADR elenca le misure da prendere (meno livelli, derivati più piccoli)
- [ ] Aree di tocco corrette a tutte le proporzioni
- [ ] Nessuna sovrapposizione di card semitrasparenti ai livelli animati
- [ ] “Riduci movimento” ferma le animazioni
- [ ] L’override cambia l’immagine senza toccare il manifest
- [ ] Verifica con un lettore di schermo su un telefono: ordine e etichette degli slot
- [ ] Il designer valida che la composizione corrisponda alle intenzioni

### 3.4 SP-03 · Aggiornamento dell’APK

Ruolo: sviluppatore Android nativo · Rif.: TC-10, 10.3 dell’Architettura, D-14 · Dipende da: SEC-04

- **SP03-01** Release di prova con APK e manifest firmato (chiave di prova)
- **SP03-02** Controllo, scarico, verifica di hash e firma e installazione tramite il canale nativo
- **SP03-03** Flusso del permesso “Installa app sconosciute”
- **SP03-04** Scenari di errore

Checklist di verifica:

- [ ] Aggiornamento riuscito su due telefoni reali, dati e chiavi locali conservati
- [ ] Manifest alterato: rifiutato
- [ ] APK con firma diversa: rifiutato, senza perdita di dati
- [ ] Versione non superiore: rifiutata
- [ ] Scarico interrotto: ripresa o ripetizione
- [ ] Spazio insufficiente e permesso negato: messaggi in linguaggio semplice
- [ ] Annotato **quante conferme** chiede Android sulle versioni dei due telefoni
- [ ] Verifica con il sorgente configurato su un repository diverso
- [ ] ADR con esito

### 3.5 SP-05 · Footprint del backend

Ruolo: sviluppatore backend, release e infrastruttura · Rif.: TC-02, TC-17 · Dipende da: SRV-02

- **SP05-01** Immagine e compose sulla VM ARM
- **SP05-02** Carico sintetico con coppie simulate (da decine a poche centinaia), eventi e blob
- **SP05-03** Misure con diversi limiti di memoria della JVM
- **SP05-04** Raccomandazione sui limiti e sui requisiti minimi

Checklist di verifica:

- [ ] Memoria a riposo e sotto carico, CPU e tempo di avvio registrati
- [ ] Nessuna interruzione per esaurimento di memoria con i limiti raccomandati
- [ ] Requisiti minimi per il self-hosting scritti, con i numeri misurati
- [ ] ADR con esito

### 3.6 Uscita da M1 (G-1)

- [ ] Cinque ADR di esito completati
- [ ] Documento architetturale aggiornato alla v0.2 con le correzioni emerse
- [ ] Decisioni AR-xx confermate, corrette o riaperte esplicitamente
- [ ] Elenco dei rischi aggiornato
- [ ] Elenco dei punti da sottoporre a revisione indipendente (G-5)
- [ ] Dettaglio di M2 preparato a partire dagli esiti

## 4. Tracciabilità

Ogni task cita gli ID dei documenti da cui discende. Un task che non può essere chiuso senza violare una decisione **\[Deciso\]** viene segnalato al promotore.
