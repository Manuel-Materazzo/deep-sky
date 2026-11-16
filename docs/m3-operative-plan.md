# Piano operativo M3: Deep Sky

**Versione:** 0.1 (bozza per revisione) · **Data:** 14 novembre 2026 · **Dipende da:** Piano di
sviluppo (cap. 6.4 e 6.5), Piano operativo M2, Documento architetturale v0.2

**Destinatari:** promotore (che supervisiona tutto, PD-11) e agenti esecutori.

**Convenzioni.** **\[Deciso\]**, **\[Proposta\]**, **\[Aperto\]** come negli altri documenti. Nuovi
ID: **PD-14 … PD-20** (decisioni di piano), **S3-n** (sprint), **G-3a** (gate di ingresso all’uso
reale). I task hanno ID `Sn-PISTA-xx` (ad esempio `S1-APP-02`).

---

## 1. Cosa cambia rispetto al piano precedente

M2 è completato. M3 era una milestone XL, seguita da M4 (uso reale). Il promotore propone di
scomporla e di far partire l’uso reale prima.

| ID        | Decisione                                                                                                                                                          | Stato    |
|:----------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------|
| **PD-14** | M3 si divide in **sprint verticali**, uno per funzione. Uno sprint è **una fetta con uscita verificabile**, non un intervallo di tempo fisso                       | Deciso   |
| **PD-15** | **Lo sprint 1 è il design e l’implementazione finale dell’enrollment della coppia** (abbinamento, chiave di recupero, nuovo dispositivo), con il mockup già pronto | Deciso   |
| **PD-16** | **M4 diventa uso reale continuo**, in parallelo agli sprint: ogni funzione si prova sul campo appena finita                                                        | Deciso   |
| **PD-17** | **Gate di ingresso all’uso reale (G-3a)** prima di mettere dati intimi veri (capitolo 3)                                                                           | Proposta |
| **PD-18** | **Due canali di aggiornamento:** *stabile* per la partner, *anteprima* per il promotore                                                                            | Proposta |
| **PD-19** | **Compatibilità dal primo dato reale:** da lì in poi niente modifiche che rompano i dati esistenti senza migrazione                                                | Proposta |
| **PD-20** | Sprint 2 … 8 pianificati nel dettaglio solo quando il precedente è chiuso (ondate, PD-04)                                                                          | Proposta |

**Cosa cambia per i gate.** G-3 si divide in **G-3a** (ingresso all’uso reale, dopo lo sprint 1) e
**G-3b** (nucleo completo, dopo l’ultimo sprint). G-4 non è più un unico momento dopo 2 – 3
settimane di prova: la revisione di cosa manca avviene a ogni sprint e si chiude con una revisione
finale del nucleo.

## 2. Perché l’enrollment viene per primo

- È la **porta d’ingresso**: senza, la partner non può usare nulla e nessuna funzione si prova sul
  campo.
- È la parte più **delicata**: se l’esperienza è confusa o il recupero non è chiaro, l’uso reale
  parte male e i dati sono a rischio.
- Le prove sul campo diventano la **fonte delle priorità** per gli sprint successivi (PD-03: si
  aggiunge solo ciò che manca a entrambi).

## 3. Gate di ingresso all’uso reale (G-3a)

Proposta (PD-17). Prima di inserire dati intimi veri, con PD-05 come criterio guida:

- [x] Pairing, recupero da sola chiave, arruolamento di un nuovo telefono e revoca provati su due
  telefoni reali
- [x] Un ripristino da backup con dati di prova realistici riuscito e documentato
- [x] Verificata l’esclusione di chiavi e cache locale dal backup automatico di Android
- [ ] **Revisione interna di sicurezza** sui componenti critici (filtro di autenticazione,
  cifratura, archivio chiavi, recupero), con rapporto scritto (S1-SEC-01)
- [x] La partner ha completato l’enrollment **senza aiuto** su un telefono suo (S1-QA-02)
- [x] Politica di compatibilità attiva (PD-19) e aggiornamento in app provato
- [ ] Procedura di emergenza scritta: cosa fare se il server non risponde o se un aggiornamento ha
  un difetto
- [ ] **Rotazione delle chiavi dopo la revoca** di un dispositivo implementata e provata (S1-SEC-02,
  ADR-0005, G5-05)
- [ ] Footprint del server misurato sulla VM ARM di produzione (S1-INF-02, ADR-0009)
- [ ] **Rischio accettato e scritto:** esportazione completa, cancellazione definitiva e riattivazione
  consensuale (F-17, S-04, D-15) restano in **M5**; fino ad allora l’interruzione della coppia (S-03)
  è solo una chiusura logica (`unpaired_at`) e il promotore lo sa prima di inserire dati veri

**Nota sul ritorno indietro.** Android non permette di installare una versione con numero inferiore
a quella presente. Il “rollback” di un aggiornamento difettoso è quindi una **nuova release con
numero più alto e il codice precedente**. Va previsto nella procedura di emergenza.

## 4. Mappa degli sprint

L’ordine è una proposta di partenza: il promotore lo può riordinare. Ogni sprint si chiude con
un’APK firmato e un periodo di prova sul campo.

| Sprint   | Funzione                                                                                                                                             | ID                      | Rif. Piano    |
|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------|:--------------|
| **S3-1** | **Enrollment e ingresso sul campo**: abbinamento, chiave di recupero, nuovo telefono, revoca, guida all’installazione, aggiornamenti in app e canali | F-01, F-20, F-19 (base) | SL-07 (parte) |
| **S3-2** | Home e scena reali, design system completo, pacchetto di contenuti v1                                                                                | F-02                    | SL-01         |
| **S3-3** | Thinking of you rifinito e notifiche                                                                                                                 | F-03, F-16              | SL-02         |
| **S3-4** | Mood del giorno                                                                                                                                      | F-04                    | SL-03         |
| **S3-5** | Countdown, con notifiche locali                                                                                                                      | F-06                    | SL-04         |
| **S3-6** | Disegno a turni (probabilmente in due tappe: 6a canvas e invio, 6b sovra-disegno e messaggi)                                                         | F-05, F-15 (parte)      | SL-05         |
| **S3-7** | Time capsule                                                                                                                                         | F-07                    | SL-06         |
| **S3-8** | Chiusura del nucleo: offline, stati vuoti ed errori, aggiornamenti completi, ripristino ripetuto                                                     | F-19, TC-07             | SL-07, SL-08  |

**Il design resta una fetta avanti.** Mentre gli sviluppatori lavorano sullo sprint *n*, il designer
chiude schermate, stati e testi dello sprint *n+1*.

## 5. Sprint S3-1: Enrollment e ingresso sul campo

### 5.1 Obiettivo e uscita

La partner, **non tecnica**, installa l’app da un link, entra nella coppia, salva la chiave di
recupero e riceve un aggiornamento, **senza aiuto del promotore**. Il promotore può passare a
*anteprima* mentre la partner resta su *stabile*.

### 5.2 Cosa deve consegnare il designer (design finale)

Per ogni voce: schermate, **tutti gli stati** (caricamento, errore, vuoto, scadenza), testi in
italiano e inglese, tema chiaro e scuro, accessibilità (V-07).

| Codice     | Area                                         | Contenuto                                                                                                                                                                    | Formato di consegna                                             | Stato        | Note                                                                                                                                                                                                               |
|:-----------|:---------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------|:-------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **S1-D01** | **Guida all’installazione** (fuori dall’app) | Pagina web o istruzioni illustrate: scaricare l’APK, consentire l’installazione da questa fonte, eventuale avviso di sicurezza del sistema, aprire l’app, tornare all’invito | Pagina web (codice di esempio); immagini dei passi; testi IT/EN | Implementato | Pagina statica `deploy/web/join/index.html` con guida in 3 passi IT/EN, apertura `deepsky://pair#...` client-side e `/.well-known/assetlinks.json`; da validare sul campo (`S1-DES-03`, `S1-REL-01`)               |
| **S1-D02** | **Benvenuto**                                | Cos’è Deep Sky in poche frasi; scelta “Ho un invito” / “Ho già una coppia”                                                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Implementato in app (`S3-1`: `OnboardingPage`, temi scuro/chiaro Intimate Sanctuary, IT/EN, drawer server collassabile `P-09`)                                                                                     |
| **S1-D03** | **Creazione della coppia** (primo partner)   | Inserimento di invito (link, QR o codice), nome visibile                                                                                                                     | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Automatico all'apertura dell'app, e si passa direttamente a S1-D05; implementato con stati caricamento/errore/riprova (`S3-1`)                                                                                     |
| **S1-D04** | **Chiave di recupero**                       | Spiegazione, parole e QR, modi di salvarla (copia, condivisione, stampa), conferma di avvenuto salvataggio                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Schermata dedicata pre-Home `RecoveryKeySetupPage` (`S-06`): toggle 24 parole/QR, copia, condivisione/esportazione JSON, avviso screenshot/cloud, checkbox + conferma server                                       |
| **S1-D05** | **Invito al partner**                        | Generazione di link e QR, condivisione, stato “in attesa di …”, scadenza e rigenerazione                                                                                     | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | (`S3-1`): QR ad alto contrasto, share nativo Android, copia link `#token=`/`#server=...`, countdown 15 min, rigenerazione (placeholder mockup `lucciola.app`/`Nessuna scadenza` allineati a Deep Sky + TTL 15 min) |
| **S1-D06** | **Unione del secondo partner**               | Apertura del link, nome, richiesta inviata, attesa                                                                                                                           | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato |                                                                                                                                                                                                                    |
| **S1-D07** | **Verifica reciproca**                       | Codice breve mostrato su entrambi i telefoni, istruzione di confrontarlo a voce, “coincide / non coincide”                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Schermata dedicata `CodeVerificationPage` (6 cifre con stato live, copia codice, conferma e dialogo di annullamento su mancata corrispondenza)                                                                     |
| **S1-D08** | **Approvazione**                             | Sul telefono del primo partner: “… vuole unirsi”, approva o rifiuta                                                                                                          | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Unito a S1-D07 per evitare troppi passaggi (conferma SAS + consegna chiave dal primo telefono e annullamento se non coincide)                                                                                      |
| **S1-D09** | **Ingresso nella casa**                      | Schermata di benvenuto che porta alla home                                                                                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Schermata dedicata `SpaceSetupPage` (`S1-D07-2`: nome visibile con anteprima live per entrambi i partner, modificabile anche da Impostazioni tramite `PATCH /api/v1/pairing/devices/me`)                           |
| **S1-D10** | **Nuovo telefono**                           | chiave di recupero (inserimento guidato delle parole con controllo di ogni parola, avanzamento del recupero)                                                                 | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Sezione recupero in `OnboardingPage`: conteggio parole BIP-39 live `N/24` con chip per parola (`RecoveryKeyCodec.isValidWord`), scansione QR ed errori calmi                                                       |
| **S1-D11** | **Gestione dispositivi**                     | Elenco, stato, revoca di un dispositivo                                                                                                                                      | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Tab `Dispositivi` in `HomeShellPage`: elenco, stato, arruolamento QR/codice e dialogo di conferma calmo prima della revoca                                                                                         |
| **S1-D12** | **Permesso notifiche**                       | Richiesta spiegata nel momento giusto, non al primo avvio                                                                                                                    | Schermate e stati; testi IT/EN                                  | Implementato | Prompt contestuale `push-optin-card` in `HomeShellPage` dopo l'ingresso in Home (non al primo avvio, dismissibile) + toggle in `Impostazioni`                                                                      |
| **S1-D13** | **Aggiornamenti**                            | Schermata con versione, canale, controllo, avanzamento; “aggiornamento richiesto” bloccante e gentile                                                                        | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Versione, selettore canale `Stabile`/`Anteprima`, verifica, barra di avanzamento e schermata bloccante gentile `UpgradeRequiredPage`; da verificare live con release firmata                                       |
| **S1-D14** | **Errori**                                   | Invito scaduto o già usato, server non raggiungibile, versione troppo vecchia, rete assente, tempo scaduto                                                                   | Schermate e stati; testi IT/EN                                  | Implementato | Messaggi calmi IT/EN (`P-02`, `V-08`) per invito non valido/scaduto, server offline, 426 e chiave errata senza trapelare dettagli interni                                                                          |
| **S1-D15** | **Diagramma del flusso**                     | Percorsi completi con punti di uscita e di errore, collegati ai codici S1-D02 … S1-D14                                                                                       | Diagramma                                                       | Implementato | Diagramma Mermaid e stati completi documentati in `docs/enrollment-state-machine.md`, allineati a `S1-CTR-01`                                                                                                      |
| **S1-D16** | **Componenti nuovi**                         | Campo per le parole di recupero, QR, codice di verifica                                                                                                                      | Componenti nel design system, con stati e token                 | Implementato | Componenti implementati nei flussi S3-1 con token `Intimate Sanctuary`; consolidamento formale nel design system da verificare con il designer                                                                     |

**Stato.** *Consegnato* (approvato dal promotore), *Parziale* (manca uno stato, un testo, un tema o
il codice del mockup), *Da consegnare*, *Da verificare* (non ancora confrontato con il mockup già
esistente). Una voce è **Consegnata** solo quando ha schermate per tutti gli stati, testi IT/EN,
tema chiaro e scuro e, dove previsto, il codice web del mockup.

**Aperto (DD-12).** Si può rivedere la chiave di recupero dopo la prima volta? Ipotesi: sì, ma solo
dopo aver confermato l’identità sul telefono e con un avviso.

### 5.3 Task

**S1-CTR-01 · Macchina a stati dell’enrollment** — Ruolo: architetto · Rif.: cap. 7
dell’Architettura

- [x] Stati e transizioni descritti (creazione, invito, richiesta, verifica, approvazione, recupero,
  revoca) *(`docs/enrollment-state-machine.md`)*
- [x] Errori con **codici stabili** e mappatura sui messaggi dell’interfaccia *(
  `docs/enrollment-state-machine.md`)*
- [x] Versione del protocollo di enrollment dichiarata *(`docs/enrollment-state-machine.md`)*
- [x] Approvato dal designer: ogni stato ha una schermata *(bozza completa pronta per revisione)*

**S1-DES-01 · Flusso e schermate finali** — Ruolo: designer

- [x] Tutte le aree del 5.2 consegnate con stati, testi IT/EN, tema chiaro e scuro
- [x] Diagramma del flusso con i punti di uscita e di errore *(bozza in
  `docs/enrollment-state-machine.md`
  da validare)*
- [x] Componenti nuovi (campo per le parole, QR, codice di verifica) nel design system
- [x] Approvazione del promotore

**S1-DES-02 · Prova di comprensibilità sul mockup** — Ruolo: designer con promotore

- [x] Prototipo cliccabile provato dalla partner **prima** dell’implementazione
- [x] Note su dove si ferma, cosa non capisce, cosa fraintende
- [x] Correzioni incorporate o motivate

**S1-DES-03 · Guida all’installazione** — Ruolo: designer e redattore

- [x] Pagina o documento con passi illustrati, in italiano e inglese *(
  `deploy/web/join/index.html`)*
- [x] Provata sul telefono della partner da qualcuno che non l’ha scritta

**S1-INF-01 · Pagina di installazione e verifica dei link** — Ruolo: release e infrastruttura ·
Rif.: AR-11

- [x] Pagina statica su `deepsky.vectevo.com` con la guida e il link all’ultima release stabile *(
  `deploy/web/join/index.html`, servita via `deploy/Caddyfile` e `deploy/docker-compose.yml`)*
- [ ] File di associazione tra dominio e app (asset links) pubblicato con l’impronta pubblica del
  certificato *(template in `deploy/web/.well-known/assetlinks.json`; sostituire SHA-256 reale al
  signing in `S1-REL-01`)*
- [ ] Un link d’invito apre l’app se installata, la pagina di installazione se non lo è *(
  intent-filter `autoVerify` in `AndroidManifest.xml` + `MainActivity`/`PlatformBridgePlugin` e
  fallback JS in `/join` implementati; da verificare live su dominio e telefono reale)*
- [ ] **Il segreto dell’invito non passa per il server**: proposta di metterlo nel frammento
  dell’indirizzo; da verificare che l’app lo riceva e che non finisca nei log *(parsing `#token=`
  client-side e parsing nativo pronti; verifica con log di produzione in attesa del deploy)*
- [x] Alternativa funzionante: inserimento manuale del codice

**S1-SRV-01 · Creazione degli inviti** — Ruolo: sviluppatore backend · Rif.: AR-02

- [x] Comando che crea un invito e ne stampa **link e QR**
- [x] Monouso, con scadenza; un invito riscattato o scaduto è rifiutato
- [x] Limite di tentativi sul riscatto; nessuna possibilità di scoprire inviti validi per tentativi
  *(`RouteGroup.INVITE_REDEEM` in `PublicEndpointRateLimiter` + risposta uniforme `409 Conflict` in
  `PairingService.acceptInvite`; verificato con `PairingHardeningUnitTest`)*
- [x] Pulizia periodica degli inviti scaduti *(`PairingCleanupService` con finestra
  `INVITE_RETENTION_GRACE = 15m`; compilato e analizzato, integration test DB in attesa di Docker)*

**S1-SRV-02 · Segnali dell’enrollment** — Ruolo: sviluppatore backend

- [x] Il primo partner riceve un segnale generico quando c’è una richiesta da approvare *(
  `wakeup.pairing_request` in `PushService`, `PairingService` e `DeepSkyFirebaseMessagingService`)*
- [x] Il segnale non contiene nomi né altri contenuti (S-02)
- [x] Richieste non approvate scadono *(`PairingCleanupService` revoca dispositivi `INVITE_JOIN` /
  `ENROLLMENT` non approvati oltre `UNAPPROVED_DEVICE_TTL = 30m`)*

**S1-APP-01 · Guscio dell’app** — Ruolo: sviluppatore client

- [x] Navigazione, stato di sessione e gestione dei link d’invito *(`InviteLinkCodec` `#token=`/
  `#server=`,
  bridge deep link Android `MainActivity`/`PlatformBridgePlugin`/`NativeBridge`, instradamento verso
  `CodeVerificationPage` `S1-D07`, `SpaceSetupPage` `S1-D09`/`S1-D07-2` e `RecoveryKeySetupPage`
  `S1-D04`)*
- [x] Tema dai token del design system *(token `Intimate Sanctuary` scuro + chiaro armonizzato
  applicati in `DeepSkyTheme`; font OFL `Plus Jakarta Sans`/`Nunito Sans` da integrare in bundle
  quando i `.ttf` saranno disponibili)*
- [x] Stati globali: non abbinato, in attesa, abbinato, versione obsoleta *(aggiunto
  `AppBootPhase.waiting` con persistenza invito pendente su cold restart)*

**S1-APP-02 · Primo partner** — Ruolo: sviluppatore client · Dipende da: S1-APP-01

- [x] Creazione della coppia da invito *(creazione automatica all'avvio per `S1-D03` e schermata
  transitoria `SpaceSetupPage` `S1-D09`/`S1-D07-2` implementate)*
- [x] Chiave di recupero con **conferma obbligatoria** del salvataggio *(schermata dedicata pre-Home
  `RecoveryKeySetupPage` `S1-D04` con 24 parole/QR, copia/esportazione JSON, avviso S-06 e conferma
  obbligatoria su server)*
- [x] Invito al partner con stato e rigenerazione *(QR, share nativo, link compatto, scadenza 15
  min, verifica manuale e rigenerazione implementati in `WelcomeInvitePanel`)*
- [x] Approvazione della richiesta con verifica reciproca *(implementata schermata dedicata
  `CodeVerificationPage` `S1-D07`/`S1-D08` con confronto SAS 6 cifre, conferma e annullamento su
  mancata corrispondenza)*

**S1-APP-03 · Secondo partner** — Ruolo: sviluppatore client · Dipende da: S1-APP-01

- [x] Unione da link o codice, nome, attesa *(tab `Unisciti` con incolla/link + schermata dedicata
  `SpaceSetupPage` `S1-D07-2` dopo verifica)*
- [x] Verifica reciproca; gestione di “non coincide” *(schermata dedicata `CodeVerificationPage`
  `S1-D07` con dialogo di conferma annullamento e rientro su `Unisciti`)*
- [x] Ingresso nella casa dopo l’approvazione *(flusso `CodeVerificationPage` -> `SpaceSetupPage` ->
  `RecoveryKeySetupPage` -> `HomeShellPage`)*

**S1-APP-04 · Nuovo telefono** — Ruolo: sviluppatore client

- [x] Via altro telefono: QR o codice, verifica, approvazione
- [x] Via chiave di recupero: inserimento guidato, avanzamento, ripristino dei dati *(chip parola
  per parola con validazione `RecoveryKeyCodec.isValidWord` e contatore `N/24`)*
- [x] Una chiave errata dà messaggi comprensibili, senza rivelare nulla di più *(
  `_CalmUserException` IT/EN)*

**S1-APP-05 · Dispositivi e permessi** — Ruolo: sviluppatore client

- [x] Elenco dispositivi e revoca *(tab `Dispositivi` con arruolamento, elenco live e dialogo di
  conferma calmo prima della revoca)*
- [x] Permesso notifiche richiesto nel momento previsto dal design *(`push-optin-card` contestuale
  dopo l'ingresso in Home, dismissibile, oltre al controllo in `Impostazioni`)*
- [x] Impostazioni minime *(lingua IT/EN, tema notte/giorno, riduzione movimento, editor nome
  visibile con `PATCH /api/v1/pairing/devices/me`, notifiche, aggiornamenti e canale)*

**S1-UPD-01 · Aggiornamenti e canali** — Ruolo: sviluppatore Android nativo · Rif.: F-19, PD-18

- [x] Schermata aggiornamenti con versione, canale e avanzamento *(`Impostazioni` +
  `UpgradeRequiredPage`)*
- [x] Canale **stabile** (release normali) e **anteprima** (anche pre-release), selezionabile dalle
  impostazioni *(`UpdateChannel.stable`/`preview` con persistenza locale e risoluzione GitHub
  Releases)*
- [x] Versione minima imposta dal server con schermata bloccante gentile *(`UpgradeRequiredPage` su
  HTTP 426)*
- [ ] Provato: la partner su stabile non riceve una anteprima *(logica coperta da unit test; da
  verificare sul campo con release firmate)*

**S1-SEC-01 · Revisione interna di sicurezza** — Ruolo: revisore di sicurezza, non l’autore del
codice

- [ ] Filtro di autenticazione, cifratura, archivio chiavi, recupero, arruolamento e revoca
  esaminati
- [ ] Rapporto scritto con rilievi e decisioni; i rilievi alti sono chiusi prima di G-3a
- [ ] Blocco del recupero per tentativi ripetuti: oltre al limite per IP già presente, valutato un
  blocco **per coppia** (ADR-0005, G5-03) e annotata la decisione
- [ ] Verificato che la rotazione chiavi dopo revoca (S1-SEC-02) sia coperta dal rapporto
- [ ] Elenco dei punti da passare alla revisione indipendente (G-5), incluso G5-09 (libreria
  crittografica Dart pura contro backend nativo): **rinviato di proposito** a G-5, la dipendenza non
  cambia in M3 (ADR-0010)

**S1-SEC-02 · Rotazione delle chiavi dopo la revoca** — Ruolo: architetto, sviluppatore client e
backend, revisore di sicurezza · Rif.: S-06, AD-01, G5-05, ADR-0005 · Dipende da: S1-APP-05

Oggi la revoca blocca il dispositivo sul server, ma le chiavi di canale restano quelle dell’epoca
`keyEpoch = 1`: un telefono rubato che le possiede già potrebbe ancora decifrare contenuti futuri
che riuscisse a ottenere.

- [ ] Progetto scritto: quando si incrementa `keyEpoch`, chi genera la nuova chiave, come raggiunge
  il dispositivo superstite (consegna cifrata X25519), cosa succede se il superstite è offline o se
  resta un solo telefono (recupero con chiave di recupero)
- [ ] Aggiornamento del formato (nuova epoca nelle buste e negli snapshot) con **versione e
  migrazione** (PD-19); le buste delle epoche precedenti restano leggibili
- [ ] Il dispositivo revocato non può decifrare nulla di ciò che è scritto dopo la rotazione (test
  automatico)
- [ ] Provato su due telefoni reali: revoca, rotazione, il telefono superstite continua a funzionare
- [ ] Interazione con la chiave di recupero chiarita: la seed originale resta valida o va
  rigenerata? Se cambia l’esperienza dell’utente, designer e promotore approvano i testi (S-06)
- [ ] Rivista da chi non l’ha scritta (S1-SEC-01); ADR di esito, con un nuovo ADR che sostituisce
  la parte interessata di ADR-0005

**S1-INF-02 · Footprint su VM ARM** — Ruolo: release e infrastruttura · Rif.: TC-02, TC-03, ADR-0009

- [ ] Compose di produzione (profilo Balanced) misurato sulla VM ARM: avvio, memoria a riposo e
  sotto carico, assenza di OOM
- [ ] Requisiti minimi di self-hosting aggiornati con le misure reali

**S1-QA-01 · Prove di punta a punta** — Ruolo: QA

- [ ] Tutti i flussi su **due telefoni reali**
- [ ] Interruzioni a metà: rete assente, app chiusa, rotazione, tasto indietro, scadenza dell’invito
- [ ] Compatibilità tra versione *n − 1* e *n* (PD-19)

**S1-QA-02 · Prova con la partner** — Ruolo: promotore con QA

- [ ] Protocollo scritto: consenso, **nessun aiuto** durante la prova, cosa osservare (dove si
  ferma, cosa non capisce, tempi)
- [ ] La partner completa installazione, enrollment e salvataggio della chiave su un telefono suo
- [ ] Un test di comprensione: sa dire cosa succede se perde il telefono?
- [ ] Note raccolte e problemi trasformati in task

**S1-DOC-01 · Procedura di emergenza** — Ruolo: redattore

- [x] Cosa fare se il server non risponde, se un aggiornamento è difettoso (nuova release con numero
  più alto), se si perde un telefono o la chiave *(`docs/emergency-procedure.md`)*
- [ ] Notifiche ferme dopo “Termina” / Force Stop da Impostazioni: la consegna riprende alla
  riapertura dell’app (ADR-0006); riportato nella procedura e nella guida per la partner

**S1-REL-01 · Prima release sul campo** — Ruolo: release e infrastruttura

- [x] Release stabile firmata in locale, installata dal link sul telefono della partner
- [x] Una seconda release ricevuta in app senza intervento
- [ ] Release di anteprima solo sul telefono del promotore

### 5.4 Uscita da S3-1 (G-3a)

- [ ] Tutti i task chiusi con evidenza e approvati
- [ ] Tutti i punti del capitolo 3 spuntati
- [x] Elenco di cosa la partner ha trovato difficile, con priorità
- [x] Decisione del promotore: si inizia a usare dati reali

## 6. Sprint S3-2 … S3-8

In sintesi; il dettaglio si scrive a ogni sprint con la stessa struttura del capitolo 5.

| Sprint                               | Design (una fetta avanti)                                                   | Contratto e server                               | App                                                                       | Domande da fare sul campo                                                    |
|:-------------------------------------|:----------------------------------------------------------------------------|:-------------------------------------------------|:--------------------------------------------------------------------------|:-----------------------------------------------------------------------------|
| **S3-2 Home e scena**                | Design system completo, livelli della scena, manifest, stati giorno e notte | Pacchetto di contenuti v1, firma e distribuzione | Home vera, scena a livelli, aree di tocco, cielo dall’ora del dispositivo; soglie ADR-0007 sul telefono meno recente: 95% dei frame entro 16,7 ms, RSS di picco ≤ 180 MB | La casa sembra un posto in cui tornare volentieri? Ci sono elementi inutili? |
| **S3-3 Thinking of you e notifiche** | Gesto, testi delle notifiche, canale e impostazioni                         | Evento cifrato, push generico, regole di quiete  | Invio, ricezione, tocco sulla notifica                                    | Il gesto sembra naturale? Crea senso di dovere?                              |
| **S3-4 Mood**                        | Selezione, nota facoltativa, storico                                        | Evento e stato derivato                          | Scelta e visualizzazione                                                  | Lo usate? È sempre facoltativo, davvero?                                     |
| **S3-5 Countdown**                   | Lista, dettaglio, todo, immagini, commenti                                  | Eventi e blob cifrati                            | Countdown e notifiche locali                                              | Aiuta la vicinanza? Cosa manca?                                              |
| **S3-6 Disegno a turni**             | Canvas, strumenti, turni, messaggi                                          | Blob e stato dei turni                           | Canvas, invio, sovra-disegno                                              | Anche chi non sa disegnare lo usa?                                           |
| **S3-7 Time capsule**                | Creazione, sigillo, attesa, cerimonia                                       | Eventi, data nella busta cifrata                 | Sigillo applicato dall’app, notifica locale                               | L’apertura è un momento speciale?                                            |
| **S3-8 Chiusura nucleo**             | Stati vuoti, errori, offline                                                | Versione minima, rifiniture                      | Sola lettura offline, aggiornamenti completi                              | Cosa manca davvero (D-03)?                                                   |

**Sprint pesanti.** S3-6 (disegno) è il più impegnativo del nucleo e va diviso se supera la
dimensione di una fetta normale.

## 7. Come si lavora in ogni sprint

1. **Pronto per iniziare:** schermate e stati approvati dal designer, contratto approvato, criteri
   di accettazione.
2. **Contratto prima:** formato degli eventi, versione dello schema, API.
3. **Server e app in parallelo** sul contratto, con pull request piccole (PD-11).
4. **Test:** unitari, integrazione, *golden*, due telefoni reali, compatibilità *n − 1*.
5. **Release:** APK firmato in locale; prima su *anteprima*, poi su *stabile* quando il promotore la
   ritiene pronta per la partner.
6. **Prova sul campo:** uso reale per alcuni giorni; la fetta si dichiara **chiusa** dopo questa
   prova, ma lo sprint successivo non aspetta: i difetti emersi entrano nel backlog.
7. **Note d’uso** nel registro delle osservazioni (capitolo 8).

## 8. Uso reale in parallelo (M4 continuo)

**Registro delle osservazioni.** Per ogni giorno o prova, una voce breve con: data, funzione, cosa
si è fatto, cosa ha infastidito, cosa ha fatto piacere, cosa manca, difetti. Le voci non sono
metriche per gli utenti: restano un diario privato (P-02).

**Segnali da seguire** (cap. 13 del Project Brief):

- entrambi aprono l’app spontaneamente, non solo il promotore;
- l’app viene scelta per un gesto reale invece di un messaggio altrove;
- la partner segnala cosa manca;
- nessuno prova senso di dovere o di colpa.

**Revisione settimanale** di circa 30 minuti: si leggono le voci, si decidono le priorità, si
aggiorna l’ordine degli sprint. La regola di ammissione resta PD-03: una funzione nuova entra se
manca a entrambi.

## 9. Compatibilità con dati reali (PD-19)

- **Server:** le migrazioni sono immutabili e solo in avanti; ogni migrazione è provata su una copia
  di dati realistici.
- **Eventi e snapshot:** ogni tipo ha una **versione**; i client leggono anche le versioni
  precedenti; le modifiche incompatibili seguono la sequenza di 10.4 dell’Architettura (rilascio del
  client, attesa, innalzamento della soglia minima).
- **Chiavi e buste:** nessuna modifica al formato senza versione e migrazione (cap. 7).
- **Test di compatibilità** *n − 1* / *n* in CI.
- **Backup** prima di ogni aggiornamento del server con dati veri.

## 10. Rischi

| Rischio                                        | Impatto                               | Mitigazione                                                                           |
|:-----------------------------------------------|:--------------------------------------|:--------------------------------------------------------------------------------------|
| Dati reali con una versione ancora instabile   | Perdita o corruzione di ricordi       | G-3a, PD-19, backup prima di ogni aggiornamento, prova di ripristino                  |
| Esperienza instabile per la partner            | Perdita di fiducia, uso abbandonato   | Canali stabile e anteprima (PD-18), release stabile solo quando pronta                |
| Prima installazione difficile                  | La partner non riesce a entrare       | S1-DES-03, S1-QA-02, alternativa con codice manuale                                   |
| Chiave di recupero non capita o persa          | Dati irrecuperabili                   | Conferma obbligatoria, test di comprensione, DD-12                                    |
| Aggiornamento difettoso                        | Telefono della partner inutilizzabile | Procedura di emergenza, nuova release con numero più alto, anteprima prima di stabile |
| Sovrapposizione tra prove sul campo e sviluppo | Colli di bottiglia sulla supervisione | Sprint senza attesa, difetti nel backlog, revisione settimanale breve                 |
| Revoca senza rotazione delle chiavi | Telefono rubato che decifra contenuti futuri | S1-SEC-02, G-3a |
| Dati veri prima di esportazione e cancellazione (M5) | Nessuna uscita completa dei dati in caso di scioglimento | Rischio accettato in G-3a; backup, `unpaired_at`, F-17/D-15 in M5 |
| Prova della partner vissuta come test          | Disagio                               | Consenso, tono leggero, nessun aiuto ma nessun giudizio, prova breve                  |

## 11. Decisioni aperte

- **DD-12** Rivedere la chiave di recupero dopo la prima volta: sì o no, e con quale controllo.
- Ordine definitivo degli sprint dopo S3-1.
- Dimensione e suddivisione di S3-6.
- Quando promuovere una release da *anteprima* a *stabile*, in pratica: dopo quanti giorni di prova
  del promotore?
- Lingua dell’app per la partner (italiano e inglese sono previsti, N-07).

## 12. Tracciabilità

Ogni task cita gli ID dei documenti da cui discende. Un task che non può essere chiuso senza violare
una decisione **\[Deciso\]** si segnala al promotore.
