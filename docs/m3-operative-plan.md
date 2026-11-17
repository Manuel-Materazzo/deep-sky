# Piano operativo M3: Deep Sky

**Versione:** 0.2 (bozza per revisione) · **Data:** 16 novembre 2026 · **Dipende da:** Piano di
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
- [x] **Revisione interna di sicurezza** sui componenti critici (filtro di autenticazione,
  cifratura, archivio chiavi, recupero), con rapporto scritto (S1-SEC-01)
- [x] La partner ha completato l’enrollment **senza aiuto** su un telefono suo (S1-QA-02)
- [x] Politica di compatibilità attiva (PD-19) e aggiornamento in app provato
- [ ] Procedura di emergenza scritta: cosa fare se il server non risponde o se un aggiornamento ha
  un difetto
- [x] **Rotazione delle chiavi dopo la revoca** di un dispositivo implementata e provata (S1-SEC-02,
  ADR-0005, G5-05)
- [x] Footprint del server misurato sulla VM ARM di produzione (S1-INF-02, ADR-0009)
- [x] **Rischio accettato e scritto:** esportazione completa, cancellazione definitiva e riattivazione
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
| **S1-D07** | **Verifica reciproca**                       | Codice breve mostrato su entrambi i telefoni, istruzione di confrontarlo a voce, “coincide / non coincide”                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Implementato | Schermata dedicata `CodeVerificationPage` (6 cifre con SAS `v2` legato al `sasSecret` out-of-band per `CA-01`, stato live, blocco copia SAS e `FLAG_SECURE` per `CA-10`, conferma e dialogo di annullamento su mancata corrispondenza) |
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
- [x] File di associazione tra dominio e app (asset links) pubblicato con l’impronta pubblica del
  certificato *(SHA-256 della chiave `deep-sky-release` configurato in `deploy/web/.well-known/assetlinks.json` con controllo CI in `.github/workflows/ci.yml` per `CA-20`; verificare corrispondenza con il `.p12` al rilascio in `S1-REL-01`)*
- [x] Un link d’invito apre l’app se installata, la pagina di installazione se non lo è *(
  intent-filter `autoVerify` in `AndroidManifest.xml` + `MainActivity`/`PlatformBridgePlugin` e
  fallback JS in `/join` implementati; da verificare live su dominio e telefono reale)*
- [x] **Token d’invito fuori da path URL e log**: l’invito resta nel frammento (`#token=`) su web/app e viaggia nel body JSON su `POST /api/v1/pairing/invites/accept` e `/status` (il server riceve il token grezzo per verificarne l’hash SHA-256, ma non finisce nei log di Caddy o Spring; da verificare con log di produzione al deploy)
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

- [x] Filtro di autenticazione, cifratura, archivio chiavi, recupero, arruolamento e revoca
  esaminati *(`docs/code-audit-2026-11-16.md`)*
- [x] Rapporto scritto con rilievi e decisioni; i rilievi alti (`CA-01`, `CA-02`, `CA-03`) sono
  implementati e verificati nei test unitari/widget/WebMvc *(restano integration test DB su Docker e
  verifica finale sul campo per G-3a)*
- [ ] Blocco del recupero per tentativi ripetuti: oltre al limite per IP già presente (`PublicEndpointRateLimiter`), valutato un
  blocco **per coppia** (ADR-0005, G5-03) e annotata la decisione
- [x] Verificato che la rotazione chiavi dopo revoca (S1-SEC-02, CA-02, ADR-0012) sia coperta dal rapporto
- [ ] Elenco dei punti da passare alla revisione indipendente (G-5), incluso G5-09 (libreria
  crittografica Dart pura contro backend nativo): **rinviato di proposito** a G-5, la dipendenza non
  cambia in M3 (ADR-0010)

**S1-SEC-02 · Rotazione delle chiavi dopo la revoca** — Ruolo: architetto, sviluppatore client e
backend, revisore di sicurezza · Rif.: S-06, AD-01, G5-05, ADR-0005, ADR-0012 · Dipende da: S1-APP-05

Implementata in codice e schema DB (`ADR-0012`, `V5__epoch_key_rotation.sql`, `CA-02`): la revoca di
un altro dispositivo incrementa atomicamente `keyEpoch`, ruota `recoverySeed` e `recoveryAuthPublicKey`
e preserva le buste storiche nel `recovery_keyring`.

- [x] Progetto scritto: quando si incrementa `keyEpoch`, chi genera la nuova chiave, come raggiunge
  il dispositivo superstite (consegna cifrata X25519 `EPOCH_ROTATION`), cosa succede se il
  superstite è offline o se resta un solo telefono (`recovery_keyring`) *(ADR-0012)*
- [x] Aggiornamento del formato (nuova epoca `v2` nelle buste e negli snapshot con `V5__epoch_key_rotation.sql`,
  PD-19); le buste `epoch = 1` restano leggibili tramite `epochSecrets[1]` e `recovery_keyring`
- [x] Il dispositivo revocato non può decifrare nulla di ciò che è scritto dopo la rotazione
  *(test automatici in `deep_sky_crypto_test`, `pairing_and_sync_repository_test`, `deep_sky_e2e_flow_test`,
  `PairingServiceUnitTest`, `SyncServiceUnitTest`)*
- [x] Provato su due telefoni reali: revoca, rotazione, il telefono superstite continua a funzionare
- [x] Interazione con la chiave di recupero chiarita (`recoverySeed` ruotato + nuova conferma su
  `RecoveryKeySetupPage` per `ADR-0012`; revisione finale testi IT/EN in carico al designer)
- [ ] Rivista da chi non l’ha scritta (S1-SEC-01); ADR pubblicato (`ADR-0012`) che sostituisce
  la parte interessata di ADR-0005

**S1-INF-02 · Footprint su VM ARM** — Ruolo: release e infrastruttura · Rif.: TC-02, TC-03, ADR-0009

- [x] Compose di produzione (profilo Balanced) misurato sulla VM ARM: avvio, memoria a riposo e
  sotto carico, assenza di OOM
- [x] Requisiti minimi di self-hosting aggiornati con le misure reali

**S1-QA-01 · Prove di punta a punta** — Ruolo: QA

- [x] Tutti i flussi su **due telefoni reali**
- [x] Interruzioni a metà: rete assente, app chiusa, rotazione, tasto indietro, scadenza dell’invito
- [ ] Compatibilità tra versione *n − 1* e *n* (PD-19)

**S1-QA-02 · Prova con la partner** — Ruolo: promotore con QA

- [x] Protocollo scritto: consenso, **nessun aiuto** durante la prova, cosa osservare (dove si
  ferma, cosa non capisce, tempi)
- [x] La partner completa installazione, enrollment e salvataggio della chiave su un telefono suo
- [x] Un test di comprensione: sa dire cosa succede se perde il telefono?
- [x] Note raccolte e problemi trasformati in task

**S1-DOC-01 · Procedura di emergenza** — Ruolo: redattore

- [x] Cosa fare se il server non risponde, se un aggiornamento è difettoso (nuova release con numero
  più alto), se si perde un telefono o la chiave *(`docs/emergency-procedure.md`)*
- [x] Notifiche ferme dopo “Termina” / Force Stop da Impostazioni: la consegna riprende alla
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

## 6. Sprint S3-2: Home e scena reali, design system completo, pacchetto di contenuti v1

### 6.1 Obiettivo e uscita

La coppia apre **la vera casa del nucleo** (`F-02`, `SL-01`, mockup in `docs/design/S3-2/`), non più la stanza pilota `ds2-pilot-room` di M1/M2, procedendo per **micro-pacchetti verticali di contenuti (1–2 grafiche per volta)** così da non bloccare lo sviluppo sulla produzione artistica completa:

- il **design system completo** (`DS-3`, `Intimate Sanctuary`, `docs/design/S3-2/DESIGN.md`) è consolidato con i font OFL inclusi nel bundle (`Plus Jakarta Sans` e `Nunito Sans`, con testi `OFL.txt` registrati in `LicenseRegistry`, `N-06`), token completi chiaro/scuro (`V-06`) e componenti condivisi (`S1-D16`);
- **muro = sfondo dell’app + pavimento continuo fino a fondo pagina:** il muro non è un’immagine opaca con vignettatura ma è lo **sfondo stesso dell’app**, i cui colori cambiano con l’ora del giorno (`giorno`, `crepuscolo`, `notte`); dalla linea del battiscopa in giù prosegue il **pavimento della stanza fino a fondo pagina**, così che l’arredo e (da `S3-5`) il **Countdown** sembrino poggiati direttamente sul pavimento della casa;
- **stanza a micro-pacchetti (`v1.0` → `v1.1` → `v1.2`) senza elementi di funzioni future (`V-09`):**
  - **`v1.0.0` (Stanza base e finestra del cielo):** pavimento continuo con battiscopa (`floor`) + finestra ad arco (`window`) che mostra **solo il cielo** dell’ora locale (`giorno`, `crepuscolo`, `notte`, senza meteo/temperatura per non richiedere posizione GPS `S-05`);
  - **`v1.1.0` (Arredo e “luce lasciata accesa” `F-03`):** divano e tappeto scontornati (`couch`, `rug`) + **lampada da terra (`floor_lamp`)**, che rappresenta la **“luce lasciata accesa”** del Design Brief 4.2 (`calm` a riposo, `lit` con bagliore caldo ambra quando c’è un pensiero ricevuto non visto / recente, toccabile per mandare un *Ti penso*);
  - **`v1.2.0` (Presenza nella stanza):** i due partner seduti sul divano (`partner_a`, `partner_b`) + il cagnolino addormentato sul tappeto come **elemento decorativo statico** (le reazioni e pose dinamiche del pet restano in `M6`, `F-09`);
  - **assenti in `S3-2` (`V-09`):** barra del mood (`S3-4`), card del countdown sul pavimento (`S3-5`), cornice/leggio disegno (`S3-6`), mensola con busta sigillata (`S3-7`), bacheca in sughero (`M5`) e diario `NOI` (`M7`);
- **card superiore “Ti penso” a doppio stato (ponte con `S3-3`, `F-03`, `DD-04`):**
  - se c’è un gesto *Ti penso* ricevuto dal partner **non ancora visto localmente e più recente di 6 ore**, mostra il banner *“\<Partner\> ti ha pensato”* (con eventuale nota) e il pulsante **`♥ Ricambia`**;
  - altrimenti mostra al suo posto il controllo rapido per **inviare un “Ti penso”** con messaggio facoltativo;
- **header e barra di navigazione essenziali:** in alto a sinistra il titolo `Casa` e in alto a destra **un solo pulsante per `Impostazioni`** (rimossi i due pallini del mockup e qualsiasi pallino verde di presenza online `P-07`, `S-05`); in basso **solo 2 tab attivi in `S3-2`: `Casa` e `Noi`** (coppia e dispositivi), aggiungendo `Gesti` e `Ricordi` solo quando nasceranno le rispettive funzioni;
- **separazione rigorosa tra stato locale e snapshot condiviso (`P-07`, `S-05`):** lo stato `lit` della lampada e il banner *“ti ha pensato”* (`< 6h` e non visto), l’ora dell’ultima apertura (per il messaggio di bentornato dopo giorni di assenza) e la fascia oraria del cielo sono **proprietà strettamente locali al singolo dispositivo** (`LocalSceneViewState`), mai sincronizzate nello snapshot E2EE condiviso (`CoupleRoomSnapshot`);
- l’orientamento dell’app è **bloccato in verticale (`portraitUp`)** per le schermate standard, ma la scena è predisposta con sviluppo orizzontale più ampio (per scorrimento orizzontale morbido e futura modalità orizzontale a tutto schermo opzionale per la sola scena);
- i **pacchetti di contenuti firmati** (`CNT-01`, `AR-09`, `TC-10`, `G5-07`) sono scaricati **file per file** (solo gli asset con SHA-256 nuovo), verificati sul client tramite una **lista di chiavi pubbliche Ed25519 con `keyId`** sui byte grezzi prima del parsing JSON, con guardia anti-downgrade persistente, rollback automatico all’**ultimo pacchetto funzionante** e **due modalità di aggiornamento**:
  1. **automatico in background:** solo su rete non a consumo (Wi-Fi di default), preparato in `staged/` e attivato al prossimo avvio;
  2. **pulsante esplicito “Aggiorna grafiche” in Impostazioni:** scarica subito anche su rete a consumo, svuota le texture precedenti dalla `imageCache` e **ricarica immediatamente l’interfaccia** senza chiudere e riaprire l’app;
- sul telefono fisico meno recente sono rispettate le soglie di **`ADR-0007`**: una sola variante oraria decodificata in memoria alla volta (con `.evict()` delle varianti non attive e tetto esplicito a `imageCache`), **≥ 95% dei frame entro 16,7 ms** (60 Hz) e **RSS di picco ≤ 180 MB**.

### 6.2 Cosa deve consegnare il designer (design finale)

Per ogni voce: schermate o artefatti, **tutti gli stati** (giorno/crepuscolo/notte, casa calma, pensiero non letto `< 6h`, ritorno dopo giorni di assenza, caricamento, offline), testi in italiano e inglese (`V-10`, `V-11`, `V-12`), tema chiaro e scuro (`V-06`), accessibilità (`V-07`). In parallelo, il designer consegna schermate e stati di **S3-3** (*Thinking of you e notifiche*, una fetta avanti).

| Codice     | Area                                                       | Contenuto                                                                                                                                                                                                                                                           | Formato di consegna                                                         | Stato         | Note                                                                                                                                                                                                           |
|:-----------|:-----------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------|:--------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **S2-D01** | **Design system completo (`DS-3`)**                        | Token definitivi da `docs/design/S3-2/DESIGN.md` (palette giorno/crepuscolo/notte, tipografia `Plus Jakarta Sans` + `Nunito Sans`, spaziature, raggi, elevazioni, movimento), iconografia, guida microcopy e consolidamento componenti `S1-D16`                     | Specifica token JSON/MD (`DESIGN.md`); file font `.ttf` + `OFL.txt`; stati  | Parziale      | `DESIGN.md` consegnato in `docs/design/S3-2/DESIGN.md`; da completare i token per le 3 fasce orarie del muro-sfondo (`giorno`/`crepuscolo`/`notte`) e il bundle dei file `.ttf` + `OFL.txt` (`N-06`)          |
| **S2-D02** | **Composizione senza muro opaco + pavimento continuo**     | Rimozione del muro opaco dall’illustrazione (il muro è lo sfondo dell’app che cambia colore durante il giorno) e **pavimento con battiscopa che prosegue fino a fondo pagina** (così in `S3-5` il countdown poggerà sul pavimento)                                  | Asset PNG trasparenti per micro-pacchetti `v1.0`, `v1.1`, `v1.2`            | Da consegnare | Nel mockup `docs/design/S3-2/screen.png` la stanza era un’unica immagine piatta con vignettatura; va scomposta nei livelli PNG scontornati dei 3 micro-pacchetti                                              |
| **S2-D03** | **Finestra del cielo e lampada “luce lasciata accesa”**    | **Finestra ad arco (`window`):** mostra solo il cielo (`giorno`/`crepuscolo`/`notte`, senza meteo `14°C` per `S-05`). **Lampada da terra (`floor_lamp`):** rappresenta la “luce lasciata accesa” di `F-03` (`calm` vs `lit` con bagliore ambra su pensiero `< 6h`) | Livelli PNG separati (`A-01`, `A-04`); regole di fascia oraria              | Da consegnare | Separa chiaramente l’ora del cielo (finestra) dal segnale affettivo del partner (lampada da terra `F-03`, Design Brief 4.2)                                                                                    |
| **S2-D04** | **Piano dei 3 micro-pacchetti di `S3-2` (`A-09`, `V-09`)** | **`v1.0.0`:** pavimento + finestra cielo. **`v1.1.0`:** divano + tappeto + lampada da terra (`calm`/`lit`). **`v1.2.0`:** i due partner sul divano + cagnolino addormentato statico. **Assenti** bacheca, mensola capsula/diario, barra mood e countdown           | Tabella slot (`A-09`); `manifest.json` validato; livelli PNG scontornati    | Da consegnare | Evita qualsiasi elemento di funzioni non ancora implementate (`V-09`) e rimuove il testo `"NOI"` dalle immagini (`A-06`)                                                                                       |
| **S2-D05** | **Schermata Home (`F-02`, `DS-4`)**                        | Layout da `docs/design/S3-2/code.html` adattato a `S3-2`: header con titolo `Casa` a sinistra e **un solo pulsante `Impostazioni` a destra**; card superiore *Ti penso* a doppio stato (`< 6h` non letto con `Ricambia` vs invio rapido); scena su muro-sfondo e pavimento; **2 soli tab in basso (`Casa`, `Noi`)** | Schermate e stati; codice web del mockup; testi IT/EN                       | Consegnato (da adattare in app) | Mockup in `docs/design/S3-2/`; in `S3-2` si omettono la barra del mood (`S3-4`), il countdown sul pavimento (`S3-5`), i tab `Gesti`/`Ricordi` e il pallino verde online (`P-07`, `S-05`)                       |
| **S2-D06** | **Navigazione accessibile oltre la scena (`DD-04`)**       | La card superiore *Ti penso* (invio rapido / `Ricambia`) e i 2 tab inferiori (`Casa`, `Noi`) + pulsante `Impostazioni` in alto a destra garantiscono accesso completo anche senza toccare la lampada illustrata, con ordine `OrdinalSortKey` per TalkBack (`V-07`)  | Specifica stati e ordine `OrdinalSortKey`; testi IT/EN                      | Consegnato    | Risolve `DD-04` per `S3-2`: sia il tocco sulla lampada da terra sia la card superiore permettono di inviare o ricambiare il pensiero                                                                           |
| **S2-D07** | **Casa spoglia e bentornato dopo giorni di assenza**       | Aspetto e testi della Home all’inizio dell’uso e nel momento del **ritorno dopo giorni di assenza** calcolato solo sull’ultima apertura locale del dispositivo (`P-02`, `P-03`, `P-07`, Design Brief cap. 7)                                                        | Schermate e stati; testi IT/EN                                              | Da consegnare | Tono calmo e accogliente (“Bentornato, la casa ti aspettava”), zero contatori di inattività, zero sincronizzazione dell’apertura (`S-05`), zero badge d’urgenza (`V-08`, `V-11`)                               |
| **S2-D08** | **Catalogo asset `v1` e Style Bible (`DS-5`)**             | Style Bible aggiornata (`A-03`), catalogo incrementale degli asset dei micro-pacchetti `v1.0`–`v1.2` (`A-07`: ID, slot, dimensioni master, hash SHA-256, prompt, strumento AI e termini `A-08`), verifica trasparenza su muro chiaro/crepuscolo/notte (`A-04`)       | Documento catalogo + Style Bible; specifica master (`content/masters/`)     | Da consegnare | Licenza asset decisa: **`CC-BY-4.0`** in `content/LICENSE-ASSETS` (`D-11`), con esclusione esplicita di nome, logo e icona `Deep Sky`                                                                          |
| **S2-D09** | **Aggiornamento pacchetto contenuti (auto + pulsante forzato)** | In Impostazioni: versione del pacchetto grafico attivo e **pulsante esplicito “Aggiorna grafiche”** che scarica subito (anche su rete a consumo) e ricarica la UI a caldo; banner di sola lettura offline (`N-03`, `TC-07`, `V-08`)                                 | Schermate e stati; testi IT/EN                                              | Da consegnare | Il controllo automatico silenzioso resta su Wi-Fi e applica al riavvio; il pulsante manuale forza download e ricarica istantanea senza chiudere l’app                                                          |
| **S2-D10** | **Design in anticipo per S3-3 (*Thinking of you*)**        | Gesto “ti penso” rifinito (`F-03`), nota breve facoltativa, effetto “vibrazione sul cuore” / aptica, reazione della lampada da terra, testi delle notifiche generiche (`F-16`, `S-02`), canale Android e impostazioni di quiete                                     | Schermate e stati; codice web del mockup; testi IT/EN                       | Da consegnare | La card superiore in `docs/design/S3-2/` anticipa già la vista di ricezione; in `S2-D10` si chiudono il foglio di invio/nota, aptica e notifiche per `S3-3`                                                    |

**Decisioni chiuse a partire dal mockup `docs/design/S3-2/`:**

- **\[Deciso\] Scomposizione dei micro-pacchetti di `S3-2`:**
  1. **`v1.0.0`:** pavimento continuo con battiscopa (`floor`) + finestra ad arco con cielo (`giorno`, `crepuscolo`, `notte`);
  2. **`v1.1.0`:** divano + tappeto + lampada da terra (`calm` / `lit` per `F-03`);
  3. **`v1.2.0`:** i due partner sul divano + cagnolino addormentato sul tappeto (decorativo statico in `S3-2`).
- **\[Deciso\] Muro e pavimento:** il muro è lo sfondo dell’app (cambia colore con l’ora del giorno); il pavimento prosegue fino a fondo pagina così da accogliere sopra di sé il divano e, in `S3-5`, la card del Countdown.
- **\[Deciso\] Ruolo di finestra e lampada (`F-03`):** la finestra mostra solo il cielo dell’ora locale (senza meteo/GPS `S-05`); la lampada da terra rappresenta la “luce lasciata accesa” del *Ti penso* (`F-03`).
- **\[Deciso\] Card *Ti penso* in alto:** mostra *“\<Partner\> ti ha pensato”* + `Ricambia` solo se c’è un pensiero ricevuto **non ancora visto localmente e `< 6 ore`**; altrimenti mostra il tasto per inviare un *Ti penso* con nota facoltativa.
- **\[Deciso\] Header e navigazione inferiore in `S3-2`:** in alto a destra un solo pulsante che apre `Impostazioni` (rimosso l’altro pallino e qualsiasi indicatore online); in basso **2 soli tab (`Casa` e `Noi`)**, rimandando `Gesti` e `Ricordi` agli sprint in cui nascono le rispettive funzioni.
- **\[Deciso\] D-11 / DD-06 e custodia master:** licenza **`CC-BY-4.0`** in `content/LICENSE-ASSETS` (esclusi nome, logo e icona `Deep Sky`); master in `content/masters/**` su **Git LFS** (`lfs: false` in CI) e derivati in `content/packs/**` in Git standard.
- **\[Deciso\] DD-10 (Specifiche tecniche immagini, risoluzioni e budget):** vedi sezione 6.3 qui sotto.

### 6.3 Specifiche tecniche delle immagini (`DD-10`, `A-01..A-09`)

1. **Formato, profilo colore e trasparenza (`A-01`, `A-04`):**
   - **Formato:** `PNG` RGBA a 8 bit per canale (32-bit), profilo colore **sRGB**, con canale alpha reale.
   - **Zero muro nello sfondo degli oggetti:** poiché il muro è disegnato da Flutter come sfondo dell’app, i singoli oggetti (finestra, divano, tappeto, lampada, coppia, cagnolino) non devono contenere il muro né avere aloni blu/scuri sui bordi dello scontorno (`A-04`).
   - **Margine di sicurezza interno (padding trasparente):** lasciare sempre un **`4%–5%` di pixel completamente trasparenti (`alpha = 0`)** lungo tutti i 4 lati del rettangolo, così che contorni, foglie o ombre morbide non risultino mai tagliati a vivo sul bordo del file.
   - **Ritaglio sul soggetto (no tele vuote a tutto schermo):** ogni asset è ritagliato attorno al proprio soggetto (`crop` + 5% padding), mai salvato su una tela `1080×1920` quasi tutta vuota (la GPU alloca memoria per ogni pixel del rettangolo, anche se trasparente). Il posizionamento nella stanza è governato da `bounds` nel `manifest.json`.
   - **Ombre di contatto e luci tra layer:**
     - **Ombre a terra (sotto tappeto, divano, lampada, cagnolino):** incluse direttamente nel PNG dell’oggetto come ombra morbida semitrasparente (`rgba(20, 12, 28, 0.35–0.50)`), così poggiano fisicamente sul legno di `floor.png` scurendone le venature in modo realistico.
     - **Luce della lampada da terra (approccio ibrido PNG pittorico + alone Flutter):** un semplice gradiente geometrico di Flutter da solo non può illuminare in modo direzionale le pieghe del paralume, lo stelo in legno o la pianta. Per avere una resa pittorica perfetta tra i layer, la lampada usa **due varianti PNG illustrate della stessa lampada** (`floor_lamp_calm.png` a luce soffusa e `floor_lamp_lit.png` con paralume acceso, cono di luce direzionale e riflessi caldi sullo stelo), mentre Flutter aggiunge **dietro** il PNG un alone atmosferico morbido (`RadialGradient` ambra/rosa sul muro-sfondo) che non soffre mai di bordi tagliati e non consuma RAM aggiuntiva.
2. **Budget di peso e memoria (`DD-10`, `ADR-0007`):**
   - **Master (`content/masters/`, Git LFS):** lato lungo `1024 px – 2160 px`, fino a `2–5 MB` per file.
   - **Derivati runtime (`content/packs/v1/assets/`, Git standard):** ridimensionati alla risoluzione `3x` effettiva dello slot, compressi lossless (`oxipng`), **≤ `250 KB` per singolo oggetto** e **≤ `400 KB` per il pavimento**, per un peso complessivo di `v1.0 + v1.1 + v1.2` **≤ `1,8 MB` su disco** e **≤ `10 MB` decodificati in RAM**.
3. **Tabella delle immagini per micro-pacchetto (tela logica scena `4:3` panoramica `1440 × 1080`):**

| Micro-pack | File (`assets/`) | Soggetto | Aspect Ratio | Master (`content/masters/`) | Derivato (`content/packs/v1/`) | Criteri specifici di scontorno e layer |
|:-----------|:-----------------|:---------|:-------------|:----------------------------|:-------------------------------|:---------------------------------------|
| **`v1.0.0`** | **`floor.png`** | Battiscopa in legno in alto + parquet caldo continuo verso il basso | **`3:2`** (orizz.) | `2160 × 1440` | **`1440 × 960`** | Trasparente **solo sopra** il bordo superiore del battiscopa; pieno fino in fondo per proseguire anche sotto la futura card del Countdown (`S3-5`). |
| **`v1.0.0`** | **`window_frame.png`** | Cornice della finestra ad arco + davanzale | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | I vetri tra i montanti sono **trasparenti** (`zOffset: 1`) così mostrano dietro il livello del cielo attivo (`zOffset: 0`). |
| **`v1.0.0`** | **`window_sky_day.png`** | Cielo diurno sereno sagomato sull’arco della finestra | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decodificato **solo** nella fascia `giorno` (`.evict()` nelle altre fasce). |
| **`v1.0.0`** | **`window_sky_twilight.png`** | Cielo al crepuscolo/tramonto (rosa/ambra/viola) sagomato sull’arco | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decodificato **solo** nella fascia `crepuscolo`. |
| **`v1.0.0`** | **`window_sky_night.png`** | Cielo notturno stellato con falce di luna sagomato sull’arco | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decodificato **solo** nella fascia `notte`; Flutter può sovrapporre 2–3 micro-stelline animate livello 1. |
| **`v1.1.0`** | **`rug.png`** | Tappeto ovale morbido + cuscini a terra con ombra di contatto | **`5:2`** (orizz.) | `1800 × 720` | **`900 × 360`** | `zIndex: 20`. Ombra morbida semitrasparente sui bordi che si fonde sul parquet di `floor.png`. |
| **`v1.1.0`** | **`couch.png`** | Divano rosa/crema con cuscini (senza personaggi) e ombra a terra | **`16:9`** (orizz.) | `1920 × 1080` | **`960 × 540`** | `zIndex: 30`. Separato dalla coppia così il divano è già completo in `v1.1.0`. |
| **`v1.1.0`** | **`floor_lamp_calm.png`** | Lampada da terra a destra in stato di riposo (luce soffusa, mai spenta `P-02`) | **`1:2`** (vert.) | `720 × 1440` | **`360 × 720`** | `zIndex: 35`, stato `calm`. Include ombra alla base sul pavimento. |
| **`v1.1.0`** | **`floor_lamp_lit.png`** | Stessa lampada in stato `lit` (`F-03`): paralume acceso, cono di luce calda e riflessi sullo stelo | **`1:2`** (vert.) | `720 × 1440` | **`360 × 720`** | Generata in img2img/inpainting da `floor_lamp_calm.png` per coincidere al pixel; accompagnata da alone `RadialGradient` Flutter sul muro dietro. |
| **`v1.2.0`** | **`couple_on_couch.png`** | I due partner seduti abbracciati sul divano sotto la stessa copertina | **`4:3`** (orizz.) | `1280 × 960` | **`640 × 480`** | `zIndex: 40`. Unica immagine per naturalezza dell’abbraccio e della copertina comune (separabili in `M6` se necessario per `F-18`). |
| **`v1.2.0`** | **`pet_sleeping.png`** | Cagnolino bianco addormentato a ciambella sul tappeto con ombra morbida | **`4:3`** (orizz.) | `768 × 576` | **`384 × 288`** | `zIndex: 45`. Elemento decorativo statico in `S3-2` (pose dinamiche in `M6`, `F-09`). |

### 6.4 Task

**S2-CTR-01 · Contratto dei micro-pacchetti di contenuti firmati e distribuzione file-per-file** — Ruolo: architetto · Rif.: `AR-09`, `TC-08`, `TC-10`, `G5-07`

- [ ] Specificato il contratto di distribuzione **file per file** guidato da `pack-checksums.json` + `pack-checksums.json.sig` (nessun archivio `.zip`/`.tar` da estrarre): il client scarica solo i singoli file il cui hash SHA-256 non è già presente nella cache locale, con supporto `ETag` / `If-None-Match`
- [ ] Introdotto il supporto a una **lista di chiavi pubbliche Ed25519 con `keyId`** nel client e in `pack-checksums.json` / `.sig` per consentire la rotazione futura della chiave di firma dei contenuti senza rompere i client esistenti
- [ ] Definita la protezione **anti-downgrade persistente anche dopo reinstallazione** (`allowBackup="false"`, `AD-06`): la versione minima accettabile del pacchetto è `max(bundledPackVersion, localMaxSeenPackVersion, serverMinPackVersion)`, dove il server espone `minPackVersion` nella policy di compatibilità
- [ ] Definito il meccanismo **“ultimo pacchetto funzionante”** (rollback automatico al pacchetto precedente o al pacchetto incorporato nell’APK se l’app fallisce l’avvio della Home per `>= 2` volte consecutive dopo l’attivazione di un pacchetto)
- [ ] Chiarito nel contratto che **l’ancora di fiducia crittografica è il client** (`G5-07`), mentre la verifica sul server è una difesa operativa aggiuntiva contro errori di pubblicazione

**S2-CTR-02 · Separazione tra stato locale (`LocalSceneViewState`) e snapshot condiviso (`CoupleRoomSnapshot`)** — Ruolo: architetto · Rif.: `AR-03`, `AR-07`, `TC-05`, `P-07`, `S-05`, `F-02`, `PD-19`

- [ ] Separati formalmente nel dominio e nei contratti:
  - **`CoupleRoomSnapshot` (condiviso, cifrato E2EE sul server, `schemaVersion = 1`):** contiene solo gli artefatti e gli stati oggettivi condivisi della coppia, **senza alcun campo di “visto/non visto” o orario di accesso** (`P-07`, `S-05`);
  - **`LocalSceneViewState` (strettamente locale al dispositivo, mai sincronizzato):** contiene `lastSeenEventSeq` (da cui si calcola localmente se mostrare il banner *“\<Partner\> ti ha pensato”* `< 6h` e lo stato `floor_lamp: lit`), `lastOpenedAtLocal` (per il messaggio di bentornato dopo giorni di assenza) e preferenza/fascia del cielo (`Auto / Giorno / Notte`)
- [ ] Definite le **fasce orarie locali fisse** per il cielo e per il colore del muro-sfondo (`giorno`, `crepuscolo`, `notte`, calcolate dall’orologio locale senza posizione GPS `S-05`) e il comportamento al passaggio della mezzanotte o al cambio di fuso orario con l’app aperta
- [ ] Confermato che nessun contatore di assenza o inattività viene salvato o sincronizzato (`P-02`, `P-03`)

**S2-DES-01 · Completamento Design System (`DS-3`) e adattamento del mockup Home (`DS-4`)** — Ruolo: designer · Rif.: `V-01..V-12`, `DD-04`, `S1-D16`

- [ ] Completati i token del muro-sfondo e del pavimento per le 3 fasce orarie (`giorno`, `crepuscolo`, `notte`) in tema chiaro e scuro a partire da `docs/design/S3-2/DESIGN.md` (`S2-D01`)
- [ ] Consegnati gli stati della card superiore *Ti penso* (stato pensiero non letto `< 6h` con `Ricambia` vs stato predefinito con invio rapido e nota facoltativa), il messaggio di bentornato (`S2-D07`) e la sezione “Aggiorna grafiche” in Impostazioni (`S2-D09`), con testi IT/EN
- [ ] Consegnati i file font originali non modificati (`Plus Jakarta Sans` e `Nunito Sans`, `.ttf` + `OFL.txt`, `N-06`)
- [ ] Approvazione del promotore

**S2-DES-02 · Scomposizione in livelli PNG trasparenti dei 3 micro-pacchetti (`v1.0`–`v1.2`), Style Bible e catalogo (`DS-5`)** — Ruolo: designer · Rif.: `A-01..A-09`, `V-04`, `V-05`, `V-09`, `D-11`, `DD-10`

- [ ] Consegnati i livelli PNG scontornati trasparenti (`A-01`, `A-04`, senza muro opaco) secondo le risoluzioni e gli aspect ratio della sezione 6.3:
  1. **`v1.0.0`:** pavimento con battiscopa (`floor.png`) + finestra ad arco (`window_frame.png`) e cieli (`window_sky_day.png`, `window_sky_twilight.png`, `window_sky_night.png`);
  2. **`v1.1.0`:** tappeto (`rug.png`) + divano (`couch.png`) + lampada da terra nei due stati pittorici (`floor_lamp_calm.png` e `floor_lamp_lit.png`);
  3. **`v1.2.0`:** la coppia abbracciata sul divano sotto la copertina in un’unica immagine (`couple_on_couch.png`) + cagnolino addormentato statico sul tappeto (`pet_sleeping.png`)
- [ ] Verificata la larghezza del pavimento e della scena per supportare la vista verticale centrata (o con scorrimento orizzontale) e la futura vista orizzontale a tutto schermo, e verificata la continuità del pavimento verso il basso per accogliere il futuro Countdown in `S3-5`
- [ ] Consegnati Style Bible (`A-03`) e catalogo (`A-07`), superando il test di trasparenza senza aloni su muro chiaro, crepuscolo e notte (`A-04`) e senza testo o marchi nelle immagini (`A-06`)

**S2-DES-03 · Design in anticipo per S3-3 (*Thinking of you e notifiche*)** — Ruolo: designer · Rif.: `F-03`, `F-16`, `S-02`, `SL-02`

- [ ] Consegnato `S2-D10`: rifinitura del gesto “ti penso” (composer nota breve, feedback “vibrazione sul cuore” / aptica, animazione di accensione della lampada da terra, testi delle notifiche generiche IT/EN e impostazioni di quiete)
- [ ] Approvato dal promotore prima della chiusura di `S3-2` così che `S3-3` parta senza attese

**S2-CNT-01 · Configurazione Git LFS per i master, licenza `CC-BY-4.0` e pipeline micro-pacchetti** — Ruolo: contenuti e release · Rif.: `CNT-01`, `CNT-02`, `A-02`, `A-08`, `D-11`, `TC-10` · Dipende da: `S2-CTR-01`, `S2-DES-02`

- [ ] Creato `content/LICENSE-ASSETS` con licenza **`CC-BY-4.0`** ed esclusione esplicita di nome, logo e icona `Deep Sky`; configurato `.gitattributes` per tracciare `content/masters/**` su **Git LFS** e impostato `lfs: false` nei workflow GitHub Actions per non consumare banda LFS in CI
- [ ] Realizzato lo script di build/ridimensionamento locale che dai master in `content/masters/` produce i derivati ottimizzati per densità (`A-02`, `DD-10`) in `content/packs/v1/` (in Git standard)
- [ ] Esteso `scripts/validate_content.py` per controllare l’esistenza reale di tutti i file referenziati, i limiti di peso (`DD-10`), l’assenza di path non sicuri (`..`, path assoluti) e la presenza di `keyId` in `scripts/sign_content.py`
- [ ] Generati e firmati `pack-checksums.json` e `pack-checksums.json.sig` per i micro-pacchetti `v1.0.0`, `v1.1.0` e `v1.2.0`

**S2-SRV-01 · Distribuzione file-per-file dei pacchetti di contenuti sul server** — Ruolo: sviluppatore backend · Rif.: `AR-09`, `TC-10`, `G5-07` · Dipende da: `S2-CTR-01`

- [ ] Endpoint per consultare `pack-checksums.json` e `pack-checksums.json.sig` del pacchetto attivo e scaricare i singoli file asset dal volume configurato sul server, più esposizione di `minPackVersion` nella policy di compatibilità
- [ ] Supporto per caching HTTP condizionale (`ETag` / `If-None-Match`, `Cache-Control` immutabile per hash) e intestazioni `Content-Type` / `Content-Length` rigorose
- [ ] Controllo difensivo all’avvio/ricarica sul server (verifica firma e path relativi come difesa aggiuntiva, fermo restando che l’ancora di fiducia è il client); test d’integrazione su Spring Boot + Testcontainers e rispetto di ArchUnit (`ArchitectureTest`)

**S2-APP-01 · Design system completo, font OFL con licenza e blocco orientamento verticale** — Ruolo: sviluppatore client · Rif.: `DS-3`, `V-02`, `V-06`, `V-07`, `N-06`, `S1-D16` · Dipende da: `S2-DES-01`

- [ ] Inclusi nel bundle i file `.ttf` originali non modificati di `Plus Jakarta Sans` e `Nunito Sans` insieme ai relativi `OFL.txt`, registrati in `LicenseRegistry.addLicense` (`N-06`, zero fetch di rete)
- [ ] Bloccato l’orientamento dell’app in verticale (`portraitUp` in `AndroidManifest.xml` / `SystemChrome.setPreferredOrientations`) per le schermate standard
- [ ] Allineati tutti i token `DeepSkyTokens` (inclusi i colori del muro-sfondo per giorno/crepuscolo/notte in tema chiaro e scuro, superfici, bordi, bagliori ambra ≤ 5%, raggi e spaziature) e i componenti riutilizzabili (`S1-D16`) alla specifica `DS-3`, con contrasto WCAG AA e testo scalabile fino al 200% (`V-07`)

**S2-APP-02 · Client dei pacchetti firmati: download file-per-file, `keyId`, staging e pulsante di forzatura a caldo** — Ruolo: sviluppatore client · Rif.: `TC-10`, `AR-09`, `G5-07`, `N-03` · Dipende da: `S2-CTR-01`, `S2-CNT-01`

- [ ] Implementato `ContentPackService` con mappa di chiavi pubbliche Ed25519 indicizzate per `keyId`, verifica della firma **sui byte grezzi** di `pack-checksums.json` **prima** del parsing JSON (`G5-07`), verifica anti-downgrade `max(bundledPackVersion, localMaxSeenPackVersion, serverMinPackVersion)`, guardia contro path traversal e download **file per file** dei soli asset con SHA-256 nuovo
- [ ] Implementate le **due modalità di aggiornamento**:
  1. **automatica silenziosa:** solo su rete non a consumo (Wi-Fi di default), salva il pacchetto verificato in `staged/` e lo promuove ad `active` al prossimo avvio;
  2. **pulsante manuale “Aggiorna grafiche” in Impostazioni (`S2-D09`):** scarica subito anche su rete a consumo, promuove il pacchetto, **svuota dalla `imageCache` le texture del pacchetto precedente e ricarica immediatamente l’interfaccia** senza dover chiudere e riaprire l’app
- [ ] Implementata la guardia **“ultimo pacchetto funzionante”**: contatore `packBootAttempts` azzerato al completamento del primo frame della Home (`addPostFrameCallback`), con rollback automatico al pacchetto precedente o al pacchetto incorporato nell’APK in caso di `>= 2` avvii falliti

**S2-APP-03 · Home reale: muro-sfondo dinamico, pavimento continuo, card *Ti penso* `< 6h`, lampada `F-03` e 2 tab (`Casa`, `Noi`)** — Ruolo: sviluppatore client · Rif.: `F-02`, `AR-07`, `AR-08`, `ADR-0007`, `P-07`, `S-05`, `V-02..V-11` · Dipende da: `S2-CTR-02`, `S2-APP-01`, `S2-APP-02`

- [ ] Ristrutturato `HomeShellPage` secondo il mockup `docs/design/S3-2/` adattato a `S3-2`:
  - **header superiore:** titolo `Casa` a sinistra e **un solo pulsante icona a destra per `Impostazioni`** (nessun secondo pallino e nessun indicatore verde di presenza online `P-07`, `S-05`);
  - **barra di navigazione inferiore a 2 tab:** `Casa` e `Noi` (profilo coppia e dispositivi);
  - **card superiore *Ti penso* a doppio stato:** mostra *“\<Partner\> ti ha pensato”* + pulsante `♥ Ricambia` se esiste un pensiero ricevuto **non ancora visto localmente (`lastSeenEventSeq`) e più recente di 6 ore**; altrimenti mostra il pulsante/campo per mandare un *Ti penso* con messaggio facoltativo;
  - **muro = sfondo dell’app + pavimento continuo fino a fondo pagina:** gli oggetti della stanza (finestra, divano, tappeto, lampada da terra, partner e cagnolino statico nei micro-pacchetti `v1.0`–`v1.2`) sono PNG trasparenti posati sul muro-sfondo (che cambia tinta con `giorno`/`crepuscolo`/`notte`) e sul pavimento che prosegue fino in basso (pronto ad accogliere il Countdown poggiato a terra in `S3-5`);
  - **finestra vs lampada da terra:** la finestra mostra il cielo della fascia oraria locale (`giorno`, `crepuscolo`, `notte`, senza meteo); la lampada da terra mostra lo stato `lit` (con alone caldo ambra) quando c’è un pensiero attivo/non visto e toccandola permette di inviare o aprire il *Ti penso* (`F-03`)
- [ ] Separato `LocalSceneViewState` da `CoupleRoomSnapshot`: `lastSeenEventSeq` e `lastOpenedAtLocal` restano esclusivamente locali (`P-07`, `S-05`); ricalcolo della fascia oraria locale con timer periodico leggero e su `AppLifecycleState.resumed` (mezzanotte e cambio fuso ad app aperta)
- [ ] **Controllo rigoroso della memoria immagini (`ADR-0007`):** una sola variante oraria del cielo della finestra decodificata alla volta (con `.evict()` esplicito della variante uscente al cambio di fascia oraria), `cacheWidth` / `cacheHeight` limitati alla risoluzione di visualizzazione e tetto esplicito a `PaintingBinding.instance.imageCache.maximumSizeBytes`

**S2-SEC-01 · Verifica di sicurezza sulla filiera dei pacchetti e sulla privacy dello stato locale** — Ruolo: revisore di sicurezza (non l’autore di `S2-APP-02` / `S2-SRV-01`) · Rif.: `G5-07`, `TC-10`, `P-07`, `S-05`

- [ ] Verificato nel codice e con test automatici che la firma Ed25519 (con selezione `keyId`) su `pack-checksums.json` sia controllata sui byte grezzi prima di qualsiasi parsing JSON
- [ ] Test automatici di rifiuto per: `keyId` sconosciuto, firma non valida, `pack-checksums.json` alterato, singolo PNG con SHA-256 non corrispondente, path traversal (`../`), downgrade sotto `max(bundled, localMaxSeen, serverMin)` e `minAppProtocol` non supportato, più test del rollback automatico su `>= 2` avvii falliti
- [ ] Verificato che né `lastSeenEventSeq` né `lastOpenedAtLocal` escano mai dal dispositivo verso il server (`P-07`, `S-05`)

**S2-QA-01 · Prove su due telefoni reali, accessibilità e soglie `ADR-0007`** — Ruolo: QA · Rif.: `ADR-0007`, `AD-09`, `V-07`, `PD-19`

- [ ] Test *golden* e di widget per la nuova Home in tema chiaro e scuro, stati `giorno` / `crepuscolo` / `notte` del muro-sfondo e della finestra, lampada `calm` / `lit`, card *Ti penso* nei due stati (`< 6h` non letto vs invio rapido), lingua IT/EN su proporzioni verticali `9:16` (`390×693`) e `9:20` (`360×800`) più test di non-overflow per split-screen / vista panoramica
- [ ] Verifica con TalkBack attivo (`OrdinalSortKey`), testo di sistema al 200% e opzione “riduci movimento” attiva (arresto immediato di tutte le animazioni livello 1, `ADR-0007`)
- [ ] **Misura fisica sul telefono meno recente** durante scorrimento della Home, animazioni attive e pressione del pulsante “Aggiorna grafiche” (ricarica a caldo con eviction della cache): **≥ 95% dei frame entro 16,7 ms** (60 Hz) e **RSS di picco ≤ 180 MB** (`ADR-0007`), registrata nel rapporto di test
- [ ] Prova su due telefoni reali della progressione dei micro-pacchetti (`v1.0.0 -> v1.1.0 -> v1.2.0`) sia tramite il pulsante di aggiornamento immediato sia in automatico, senza reinstallare l’APK, e prova di apertura in modalità aereo (sola lettura offline `N-03`)
- [ ] Test di compatibilità *n − 1* / *n* con i dati e gli eventi già creati in `S3-1` (`PD-19`)

**S2-REL-01 · Release `S3-2` e prova sul campo** — Ruolo: release e infrastruttura con promotore · Rif.: `PD-06`, `PD-18`, `PD-19`

- [ ] Backup verificato prima dell’aggiornamento del server (`PD-19`)
- [ ] Pubblicazione del micro-pacchetto iniziale `v1.0.0` firmato e rilascio dell’APK firmato in locale prima sul canale *anteprima* (telefono del promotore) e, dopo verifica, sul canale *stabile* (telefono della partner), seguito dai micro-aggiornamenti grafici `v1.1.0` e `v1.2.0` distribuiti dal server
- [ ] Raccolta delle osservazioni d’uso nei giorni successivi nel registro (cap. 9), rispondendo alle domande sul campo di `S3-2`: *“La casa sembra un posto in cui tornare volentieri? Ci sono elementi inutili?”*

### 6.5 Uscita da S3-2

- [ ] Tutti i task `S2-*` chiusi con CI verde, test superati e revisione del promotore (`PD-11`)
- [ ] Soglie di prestazioni e memoria (`ADR-0007`: ≥ 95% frame ≤ 16,7 ms, RSS ≤ 180 MB) confermate sul telefono meno recente anche durante l’aggiornamento forzato delle grafiche a caldo
- [ ] Progressione dei micro-pacchetti (`v1.0.0 -> v1.1.0 -> v1.2.0`) riuscita su entrambi i telefoni reali senza aggiornare l’APK
- [ ] Design di `S3-3` (*Thinking of you e notifiche*, `S2-D10`) approvato e pronto per iniziare
- [ ] Note sul campo della partner e del promotore registrate per guidare `S3-3`

## 7. Sprint S3-3 … S3-8

In sintesi; il dettaglio si scrive a ogni sprint con la stessa struttura dei capitoli 5 e 6 (`PD-20`).

| Sprint                               | Design (una fetta avanti)                                                   | Contratto e server                               | App                                                                       | Domande da fare sul campo                                                    |
|:-------------------------------------|:----------------------------------------------------------------------------|:-------------------------------------------------|:--------------------------------------------------------------------------|:-----------------------------------------------------------------------------|
| **S3-3 Thinking of you e notifiche** | Gesto, testi delle notifiche, canale e impostazioni *(consegnato in S2-D10)* | Evento cifrato, push generico con *hint* non segreto esplicito su `POST /api/v1/sync/envelopes` (`CA-15`), regole di quiete | Invio, ricezione, tocco sulla notifica | Il gesto sembra naturale? Crea senso di dovere? |
| **S3-4 Mood**                        | Selezione, nota facoltativa, storico + micro-pacchetto slot mood            | Evento, hint push per tipo evento (`CA-15`) e stato derivato | Scelta, visualizzazione e comparsa dello slot nella stanza | Lo usate? È sempre facoltativo, davvero?                                     |
| **S3-5 Countdown**                   | Lista, dettaglio, todo, immagini, commenti + micro-pacchetto calendario     | Eventi e blob cifrati                            | Countdown, notifiche locali e comparsa del calendario nella stanza        | Aiuta la vicinanza? Cosa manca?                                              |
| **S3-6 Disegno a turni**             | Canvas, strumenti, turni, messaggi + micro-pacchetto cornice/leggio         | Blob e stato dei turni                           | Canvas, invio, sovra-disegno e comparsa del disegno nella stanza          | Anche chi non sa disegnare lo usa?                                           |
| **S3-7 Time capsule**                | Creazione, sigillo, attesa, cerimonia + micro-pacchetto scatola sigillata   | Eventi, data nella busta cifrata                 | Sigillo applicato dall’app, notifica locale e comparsa nella stanza       | L’apertura è un momento speciale?                                            |
| **S3-8 Chiusura nucleo**             | Stati vuoti, errori, offline                                                | Versione minima, rifiniture                      | Sola lettura offline, aggiornamenti completi                              | Cosa manca davvero (D-03)?                                                   |

**Sprint pesanti.** S3-6 (disegno) è il più impegnativo del nucleo e va diviso se supera la
dimensione di una fetta normale.

## 8. Come si lavora in ogni sprint

1. **Pronto per iniziare:** schermate e stati approvati dal designer, contratto approvato, criteri
   di accettazione.
2. **Contratto prima:** formato degli eventi, versione dello schema, API.
3. **Server e app in parallelo** sul contratto, con pull request piccole (PD-11).
4. **Test:** unitari, integrazione, *golden*, due telefoni reali, compatibilità *n − 1*.
5. **Release:** APK firmato in locale; prima su *anteprima*, poi su *stabile* quando il promotore la
   ritiene pronta per la partner.
6. **Prova sul campo:** uso reale per alcuni giorni; la fetta si dichiara **chiusa** dopo questa
   prova, ma lo sprint successivo non aspetta: i difetti emersi entrano nel backlog.
7. **Note d’uso** nel registro delle osservazioni (capitolo 9).

## 9. Uso reale in parallelo (M4 continuo)

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

## 10. Compatibilità con dati reali (PD-19)

- **Server:** le migrazioni sono immutabili e solo in avanti; ogni migrazione è provata su una copia
  di dati realistici.
- **Eventi e snapshot:** ogni tipo ha una **versione**; i client leggono anche le versioni
  precedenti; le modifiche incompatibili seguono la sequenza di 10.4 dell’Architettura (rilascio del
  client, attesa, innalzamento della soglia minima).
- **Chiavi e buste:** nessuna modifica al formato senza versione e migrazione (cap. 7).
- **Test di compatibilità** *n − 1* / *n* in CI.
- **Backup** prima di ogni aggiornamento del server con dati veri.

## 11. Rischi

| Rischio                                        | Impatto                               | Mitigazione                                                                           |
|:-----------------------------------------------|:--------------------------------------|:--------------------------------------------------------------------------------------|
| Dati reali con una versione ancora instabile   | Perdita o corruzione di ricordi       | G-3a, PD-19, backup prima di ogni aggiornamento, prova di ripristino                  |
| Esperienza instabile per la partner            | Perdita di fiducia, uso abbandonato   | Canali stabile e anteprima (PD-18), release stabile solo quando pronta                |
| Prima installazione difficile                  | La partner non riesce a entrare       | S1-DES-03, S1-QA-02, alternativa con codice manuale                                   |
| Chiave di recupero non capita o persa          | Dati irrecuperabili                   | Conferma obbligatoria, test di comprensione, DD-12                                    |
| Aggiornamento difettoso                        | Telefono della partner inutilizzabile | Procedura di emergenza, nuova release con numero più alto, anteprima prima di stabile |
| Sovrapposizione tra prove sul campo e sviluppo | Colli di bottiglia sulla supervisione | Sprint senza attesa, difetti nel backlog, revisione settimanale breve                 |
| Revoca senza rotazione delle chiavi | Telefono rubato che decifra contenuti futuri | Mitigato in codice (`CA-02`, `ADR-0012`); resta verifica hardware in `G-3a` (`S1-SEC-02`) |
| Dati veri prima di esportazione e cancellazione (M5) | Nessuna uscita completa dei dati in caso di scioglimento | Rischio accettato in G-3a; backup, `unpaired_at`, F-17/D-15 in M5 |
| Prova della partner vissuta come test          | Disagio                               | Consenso, tono leggero, nessun aiuto ma nessun giudizio, prova breve                  |
| Collo di bottiglia sugli asset AI o picchi di RAM nei cambi scena | Sviluppo fermo o superamento dei 180 MB di RSS (`ADR-0007`) | Micro-pacchetti da 1–2 grafiche (`v1.0.0`, `v1.1.0`), una sola variante di fondale decodificata con `.evict()` sul cambio / ricarica forzata e rollback automatico all’ultimo pacchetto funzionante |

## 12. Decisioni aperte

- **DD-12** Rivedere la chiave di recupero dopo la prima volta: sì o no, e con quale controllo.
- **D-11 / DD-06 \[Deciso per la licenza, strumento da annotare per asset\]** Licenza degli asset fissata a **`CC-BY-4.0`** in `content/LICENSE-ASSETS` con esclusione esplicita di nome, logo e icona di `Deep Sky`; master archiviati in `content/masters/**` via Git LFS (`lfs: false` in CI) e derivati in `content/packs/**`.
- **DD-04 \[Deciso per il nucleo\]** Navigazione accessibile che affianca la scena in `S3-2`: card superiore *Ti penso* a doppio stato (`< 6h` non letto con `Ricambia` vs invio rapido), 2 soli tab inferiori (`Casa`, `Noi`) che crescono con `Gesti` e `Ricordi` solo quando nascono le relative funzioni, e un unico pulsante `Impostazioni` in alto a destra.
- **DD-10 \[Deciso\]** Risoluzioni master (`1024–2160 px` in Git LFS), risoluzioni derivati (`384–1440 px` in Git standard, ≤ `250 KB` per oggetto / ≤ `400 KB` per il pavimento, totale pack ≤ `1,8 MB`) e criteri di scontorno/layer definiti nella sezione 6.3.
- Modalità orizzontale a tutto schermo dedicata alla sola scena (opzionale, rimandata a dopo `S3-2`, pur predisponendo già il fondale per lo scorrimento orizzontale).
- Ordine definitivo degli sprint dopo S3-2.
- Dimensione e suddivisione di S3-6.
- Quando promuovere una release da *anteprima* a *stabile*, in pratica: dopo quanti giorni di prova
  del promotore?
- Lingua dell’app per la partner (italiano e inglese sono previsti, N-07).

## 13. Tracciabilità

Ogni task cita gli ID dei documenti da cui discende. Un task che non può essere chiuso senza violare
una decisione **\[Deciso\]** si segnala al promotore.
