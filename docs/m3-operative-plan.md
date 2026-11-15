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

- [ ] Pairing, recupero da sola chiave, arruolamento di un nuovo telefono e revoca provati su due
  telefoni reali
- [ ] Un ripristino da backup con dati di prova realistici riuscito e documentato
- [ ] Verificata l’esclusione di chiavi e cache locale dal backup automatico di Android
- [ ] **Revisione interna di sicurezza** sui componenti critici (filtro di autenticazione,
  cifratura, archivio chiavi, recupero), con rapporto scritto (S1-SEC-01)
- [ ] La partner ha completato l’enrollment **senza aiuto** su un telefono suo (S1-QA-02)
- [ ] Politica di compatibilità attiva (PD-19) e aggiornamento in app provato
- [ ] Procedura di emergenza scritta: cosa fare se il server non risponde o se un aggiornamento ha
  un difetto

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

| Codice     | Area                                         | Contenuto                                                                                                                                                                    | Formato di consegna                                             | Stato         | Note                                                                         |
|:-----------|:---------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------|:--------------|:-----------------------------------------------------------------------------|
| **S1-D01** | **Guida all’installazione** (fuori dall’app) | Pagina web o istruzioni illustrate: scaricare l’APK, consentire l’installazione da questa fonte, eventuale avviso di sicurezza del sistema, aprire l’app, tornare all’invito | Pagina web (codice di esempio); immagini dei passi; testi IT/EN | Da verificare | La prima installazione è il punto più fragile per chi non è tecnico          |
| **S1-D02** | **Benvenuto**                                | Cos’è Deep Sky in poche frasi; scelta “Ho un invito” / “Ho già una coppia”                                                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Implementato in app (`S3-1`: `OnboardingPage`, temi scuro/chiaro Intimate Sanctuary, IT/EN, drawer server collassabile `P-09`) |
| **S1-D03** | **Creazione della coppia** (primo partner)   | Inserimento di invito (link, QR o codice), nome visibile                                                                                                                     | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Automatico all'apertura dell'app, e si passa direttamente a S1-D05; implementato con stati caricamento/errore/riprova (`S3-1`) |
| **S1-D04** | **Chiave di recupero**                       | Spiegazione, parole e QR, modi di salvarla (copia, condivisione, stampa), conferma di avvenuto salvataggio                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Da verificare | Obbligatoria (S-06). Avvertenze sugli screenshot e sul salvataggio nel cloud |
| **S1-D05** | **Invito al partner**                        | Generazione di link e QR, condivisione, stato “in attesa di …”, scadenza e rigenerazione                                                                                     | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Implementato (`S3-1`): QR ad alto contrasto, share nativo Android, copia link `#token=`/`#server=...`, countdown 15 min, rigenerazione (placeholder mockup `lucciola.app`/`Nessuna scadenza` allineati a Deep Sky + TTL 15 min) |
| **S1-D06** | **Unione del secondo partner**               | Apertura del link, nome, richiesta inviata, attesa                                                                                                                           | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    |                                                                              |
| **S1-D07** | **Verifica reciproca**                       | Codice breve mostrato su entrambi i telefoni, istruzione di confrontarlo a voce, “coincide / non coincide”                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Cosa succede se non coincide (annullamento e avviso)                         |
| **S1-D08** | **Approvazione**                             | Sul telefono del primo partner: “… vuole unirsi”, approva o rifiuta                                                                                                          | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Unito a S1-D07 per evitare troppi passaggi                                   |
| **S1-D09** | **Ingresso nella casa**                      | Schermata di benvenuto che porta alla home                                                                                                                                   | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    | Schermata transitoria in cui specificare il nome della persona/dispositivo   |
| **S1-D10** | **Nuovo telefono**                           | chiave di recupero (inserimento guidato delle parole con controllo di ogni parola, avanzamento del recupero)                                                                 | Schermate e stati; codice web del mockup; testi IT/EN           | Consegnato    |                                                                              |
| **S1-D11** | **Gestione dispositivi**                     | Elenco, stato, revoca di un dispositivo                                                                                                                                      | Schermate e stati; codice web del mockup; testi IT/EN           | Da verificare | Tono non allarmante                                                          |
| **S1-D12** | **Permesso notifiche**                       | Richiesta spiegata nel momento giusto, non al primo avvio                                                                                                                    | Schermate e stati; testi IT/EN                                  | Da verificare | Su Android recenti è un permesso da chiedere esplicitamente                  |
| **S1-D13** | **Aggiornamenti**                            | Schermata con versione, canale, controllo, avanzamento; “aggiornamento richiesto” bloccante e gentile                                                                        | Schermate e stati; codice web del mockup; testi IT/EN           | Da verificare |                                                                              |
| **S1-D14** | **Errori**                                   | Invito scaduto o già usato, server non raggiungibile, versione troppo vecchia, rete assente, tempo scaduto                                                                   | Schermate e stati; testi IT/EN                                  | Da verificare | Mai allarmistici (P-02, V-08)                                                |
| **S1-D15** | **Diagramma del flusso**                     | Percorsi completi con punti di uscita e di errore, collegati ai codici S1-D02 … S1-D14                                                                                       | Diagramma                                                       | Da verificare | Deve coincidere con la macchina a stati di S1-CTR-01                         |
| **S1-D16** | **Componenti nuovi**                         | Campo per le parole di recupero, QR, codice di verifica                                                                                                                      | Componenti nel design system, con stati e token                 | Da verificare |                                                                              |

**Stato.** *Consegnato* (approvato dal promotore), *Parziale* (manca uno stato, un testo, un tema o
il codice del mockup), *Da consegnare*, *Da verificare* (non ancora confrontato con il mockup già
esistente). Una voce è **Consegnata** solo quando ha schermate per tutti gli stati, testi IT/EN,
tema chiaro e scuro e, dove previsto, il codice web del mockup.

**Aperto (DD-12).** Si può rivedere la chiave di recupero dopo la prima volta? Ipotesi: sì, ma solo
dopo aver confermato l’identità sul telefono e con un avviso.

### 5.3 Task

**S1-CTR-01 · Macchina a stati dell’enrollment** — Ruolo: architetto · Rif.: cap. 7
dell’Architettura

- [ ] Stati e transizioni descritti (creazione, invito, richiesta, verifica, approvazione, recupero,
  revoca)
- [ ] Errori con **codici stabili** e mappatura sui messaggi dell’interfaccia
- [ ] Versione del protocollo di enrollment dichiarata
- [ ] Approvato dal designer: ogni stato ha una schermata

**S1-DES-01 · Flusso e schermate finali** — Ruolo: designer

- [ ] Tutte le aree del 5.2 consegnate con stati, testi IT/EN, tema chiaro e scuro
- [ ] Diagramma del flusso con i punti di uscita e di errore
- [ ] Componenti nuovi (campo per le parole, QR, codice di verifica) nel design system
- [ ] Approvazione del promotore

**S1-DES-02 · Prova di comprensibilità sul mockup** — Ruolo: designer con promotore

- [ ] Prototipo cliccabile provato dalla partner **prima** dell’implementazione
- [ ] Note su dove si ferma, cosa non capisce, cosa fraintende
- [ ] Correzioni incorporate o motivate

**S1-DES-03 · Guida all’installazione** — Ruolo: designer e redattore

- [ ] Pagina o documento con passi illustrati, in italiano e inglese
- [ ] Provata sul telefono della partner da qualcuno che non l’ha scritta

**S1-INF-01 · Pagina di installazione e verifica dei link** — Ruolo: release e infrastruttura ·
Rif.: AR-11

- [ ] Pagina statica su `deepsky.vectevo.com` con la guida e il link all’ultima release stabile
- [ ] File di associazione tra dominio e app (asset links) pubblicato con l’impronta pubblica del
  certificato
- [ ] Un link d’invito apre l’app se installata, la pagina di installazione se non lo è
- [ ] **Il segreto dell’invito non passa per il server**: proposta di metterlo nel frammento
  dell’indirizzo; da verificare che l’app lo riceva e che non finisca nei log
- [ ] Alternativa funzionante: inserimento manuale del codice

**S1-SRV-01 · Creazione degli inviti** — Ruolo: sviluppatore backend · Rif.: AR-02

- [ ] Comando di amministrazione che crea un invito e ne stampa **link e QR**
- [ ] Monouso, con scadenza; un invito riscattato o scaduto è rifiutato
- [ ] Limite di tentativi sul riscatto; nessuna possibilità di scoprire inviti validi per tentativi
- [ ] Pulizia periodica degli inviti scaduti

**S1-SRV-02 · Segnali dell’enrollment** — Ruolo: sviluppatore backend

- [ ] Il primo partner riceve un segnale generico quando c’è una richiesta da approvare
- [ ] Il segnale non contiene nomi né altri contenuti (S-02)
- [ ] Richieste non approvate scadono

**S1-APP-01 · Guscio dell’app** — Ruolo: sviluppatore client

- [ ] Navigazione, stato di sessione e gestione dei link d’invito *(in corso: `InviteLinkCodec` `#token=`/`#server=...` e share nativo Android pronti; da completare deep link OS e schermate `S1-D06`..`S1-D10`)*
- [x] Tema dai token del design system *(token `Intimate Sanctuary` scuro + chiaro armonizzato applicati in `DeepSkyTheme`; font OFL `Plus Jakarta Sans`/`Nunito Sans` da integrare in bundle quando i `.ttf` saranno disponibili)*
- [x] Stati globali: non abbinato, in attesa, abbinato, versione obsoleta *(aggiunto `AppBootPhase.waiting` con persistenza invito pendente su cold restart)*

**S1-APP-02 · Primo partner** — Ruolo: sviluppatore client · Dipende da: S1-APP-01

- [ ] Creazione della coppia da invito *(creazione automatica all'avvio implementata per `S1-D03`; completamento onboarding con schermata dedicate `S1-D04`/`S1-D09` ancora aperto)*
- [ ] Chiave di recupero con **conferma obbligatoria** del salvataggio *(gate M2 già attivo; schermata dedicata `S1-D04` ancora da realizzare)*
- [x] Invito al partner con stato e rigenerazione *(QR, share nativo, link compatto, scadenza 15 min, verifica manuale e rigenerazione implementati in `WelcomeInvitePanel`)*
- [ ] Approvazione della richiesta con verifica reciproca *(componente SAS condiviso già collegato; schermate dedicate `S1-D07`/`S1-D08` ancora da realizzare)*

**S1-APP-03 · Secondo partner** — Ruolo: sviluppatore client · Dipende da: S1-APP-01

- [ ] Unione da link o codice, nome, attesa
- [ ] Verifica reciproca; gestione di “non coincide”
- [ ] Ingresso nella casa dopo l’approvazione

**S1-APP-04 · Nuovo telefono** — Ruolo: sviluppatore client

- [ ] Via altro telefono: QR o codice, verifica, approvazione
- [ ] Via chiave di recupero: inserimento guidato, avanzamento, ripristino dei dati
- [ ] Una chiave errata dà messaggi comprensibili, senza rivelare nulla di più

**S1-APP-05 · Dispositivi e permessi** — Ruolo: sviluppatore client

- [ ] Elenco dispositivi e revoca
- [ ] Permesso notifiche richiesto nel momento previsto dal design
- [ ] Impostazioni minime

**S1-UPD-01 · Aggiornamenti e canali** — Ruolo: sviluppatore Android nativo · Rif.: F-19, PD-18

- [ ] Schermata aggiornamenti con versione, canale e avanzamento
- [ ] Canale **stabile** (release normali) e **anteprima** (anche pre-release), selezionabile dalle
  impostazioni
- [ ] Versione minima imposta dal server con schermata bloccante gentile
- [ ] Provato: la partner su stabile non riceve una anteprima

**S1-SEC-01 · Revisione interna di sicurezza** — Ruolo: revisore di sicurezza, non l’autore del
codice

- [ ] Filtro di autenticazione, cifratura, archivio chiavi, recupero, arruolamento e revoca
  esaminati
- [ ] Rapporto scritto con rilievi e decisioni; i rilievi alti sono chiusi prima di G-3a
- [ ] Elenco dei punti da passare alla revisione indipendente (G-5)

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

- [ ] Cosa fare se il server non risponde, se un aggiornamento è difettoso (nuova release con numero
  più alto), se si perde un telefono o la chiave

**S1-REL-01 · Prima release sul campo** — Ruolo: release e infrastruttura

- [ ] Release stabile firmata in locale, installata dal link sul telefono della partner
- [ ] Una seconda release ricevuta in app senza intervento
- [ ] Release di anteprima solo sul telefono del promotore

### 5.4 Uscita da S3-1 (G-3a)

- [ ] Tutti i task chiusi con evidenza e approvati
- [ ] Tutti i punti del capitolo 3 spuntati
- [ ] Elenco di cosa la partner ha trovato difficile, con priorità
- [ ] Decisione del promotore: si inizia a usare dati reali

## 6. Sprint S3-2 … S3-8

In sintesi; il dettaglio si scrive a ogni sprint con la stessa struttura del capitolo 5.

| Sprint                               | Design (una fetta avanti)                                                   | Contratto e server                               | App                                                                       | Domande da fare sul campo                                                    |
|:-------------------------------------|:----------------------------------------------------------------------------|:-------------------------------------------------|:--------------------------------------------------------------------------|:-----------------------------------------------------------------------------|
| **S3-2 Home e scena**                | Design system completo, livelli della scena, manifest, stati giorno e notte | Pacchetto di contenuti v1, firma e distribuzione | Home vera, scena a livelli, aree di tocco, cielo dall’ora del dispositivo | La casa sembra un posto in cui tornare volentieri? Ci sono elementi inutili? |
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
