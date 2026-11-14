# Piano di sviluppo: Deep Sky

**Versione:** 0.1 (bozza per revisione) · **Data:** 14 novembre 2026 · **Dipende da:** Project Brief v0.2, Design Brief v0.2, Considerazioni tecniche v0.1, Documento architetturale v0.1

**Destinatari:** promotore, agenti sviluppatori, agente di test, agente designer.

**Nome.** D-01 è risolta: il prodotto si chiama **Deep Sky**. I documenti precedenti usano ancora “Casa” come titolo provvisorio e sono in corso di aggiornamento da parte del promotore.

**Convenzioni.** **\[Deciso\]**, **\[Proposta\]**, **\[Aperto\]** come negli altri documenti. Gli ID di questo documento sono **PD-xx** (decisioni di piano), **M-x** (milestone), **SL-xx** (fette verticali), **G-x** (gate). Gli altri ID (P, F, S, N, D, V, A, DD, TC, SP, AD, AR, AP) rimandano ai documenti precedenti.

---

## 1. Principi del piano

- **PD-01 \[Deciso\]** Nessuna scadenza: si pianifica per **milestone con criteri di uscita**, non per date.
- **PD-02 \[Deciso\]** **Fette verticali:** ogni funzione si costruisce con grafica, codice, asset e test insieme (TC-12).
- **PD-03 \[Deciso\]** **Uso reale prima di aggiungere:** una funzione nuova entra solo se entrambi i partner ne sentono la mancanza (Project Brief, cap. 8).
- **PD-04 \[Proposta\]** **Pianificazione a ondate:** dettaglio alto per M0 – M2, medio per M3, grossolano per il resto. Si rifinisce dopo aver misurato la velocità reale con M2.
- **PD-05 \[Proposta\]** **Sicurezza prima dei dati reali:** nessun dato intimo reale nell’app finché abbinamento, recupero e cifratura non hanno superato SP-02 e i test di manomissione.
- **PD-06 \[Proposta\]** **Ogni fetta termina con un APK firmato** pubblicato come release, installabile con l’aggiornatore integrato: l’aggiornamento in app viene così provato a ogni passo.

## 2. Organizzazione del lavoro

### 2.1 Ruoli

| Ruolo | Responsabilità | Possiede |
| :-- | :-- | :-- |
| **Promotore** | Product owner: priorità, approvazione dei gate, test con la partner | Decisioni **\[Deciso\]** |
| **Designer** | Identità, design system, schermate, asset, manifest della scena | Design Brief, deliverable DS-1 … DS-6 |
| **Architetto** | Coerenza tecnica, contratti tra componenti, note di decisione | Documento architetturale, contratti API e formati |
| **Sviluppatore backend** | API, database, push, pacchetti | Cartella `server/` |
| **Sviluppatore client** | App Flutter, scena, sincronizzazione, cifratura lato client | Cartella `app/` |
| **Sviluppatore Android nativo** | Widget, installatore APK, Firebase a runtime, keystore | Codice Kotlin in `app/android/` |
| **QA e test** | Strategia di test, automazione, test su dispositivi reali | Cartella di test e criteri di accettazione |
| **Revisore di sicurezza** | Revisione di cifratura, protocolli, filiera degli aggiornamenti | Rapporti di revisione |
| **Release e infrastruttura** | CI, immagini multi-architettura, firma, release, backup | `deploy/`, pipeline |
| **Redattore** | Guida al self-hosting, note di rilascio, documentazione utente | `docs/` |

Un agente può coprire più ruoli, ma la revisione di sicurezza e il QA non sono svolti da chi ha scritto il codice che verificano.

### 2.2 Regole di ingaggio

- Ogni task cita gli ID dei documenti da cui discende.
- Un conflitto con una decisione **\[Deciso\]** si **segnala** al promotore: gli agenti non lo risolvono da soli.
- Le modifiche a decisioni o contratti passano da una **nota di decisione** (ADR) approvata dal promotore.
- Nessun dato reale nei test o nella CI; **nessun segreto nel repository**.
- Nessuna release senza approvazione del promotore.

### 2.3 Repository e flusso

**\[Proposta\]** Monorepo con `app/`, `server/`, `content/` (manifest, pacchetti, asset), `deploy/`, `docs/` (documenti e `docs/adr/`). Sviluppo con rami brevi e pull request; la CI deve essere verde per fare merge; messaggi di commit convenzionali; board e issue su GitHub.

### 2.4 Definition of Ready e Done

**Una fetta è pronta per iniziare** quando ha: funzioni e ID di riferimento, schermate approvate dal designer, contratto API e formato degli eventi, criteri di accettazione.

**Una fetta è finita** quando:

- il codice è integrato e la CI è verde;
- test unitari, di integrazione e, dove serve, *golden* sono presenti;
- funziona su due telefoni reali;
- testi in italiano e inglese, accessibilità di base verificata (V-07);
- nessuna violazione di P-02, P-03, V-08;
- documentazione aggiornata e release firmata installata via aggiornatore;
- note delle osservazioni raccolte in uso.

## 3. Decisioni per partire

| ID | Questione | Decisione |
| :-- | :-- | :-- |
| **PD-07 \[Deciso\]** | Nome del pacchetto Android | `com.vectevo.deep_sky`. Resta stabile da ora: cambiarlo dopo la prima build significherebbe creare un’altra app (D-14) |
| **PD-08 \[Deciso\]** | Dominio per HTTPS (AR-11) | `deepsky.vectevo.com`, con record DNS verso la VM OCI |
| **PD-09 \[Deciso\]** | Visibilità del repository | **Pubblico fin dall’inizio**, un solo monorepo; le release dell’APK stanno nello stesso repository. Chiude D-05 sulla tempistica |
| **PD-10 \[Deciso\]** | Custodia delle chiavi di firma (AD-08) | Custodia offline con backup cifrato in due luoghi; **firma locale a ogni release**. La CI produce artefatti non firmati |
| **PD-11 \[Deciso\]** | Supervisione | Il promotore supervisiona tutto: **nessun merge senza la sua approvazione**. Le pull request sono piccole e verificabili (4.1) |
| **PD-12 \[Deciso\]** | Ritmo e capacità | Il promotore decide ritmo e priorità; capacità assunta di circa **un’ora al giorno** (4.1) |
| **PD-13 \[Proposta\]** | Licenza del codice | **MIT**, in attesa di conferma (3.1). La licenza degli asset è separata e ancora aperta (D-11) |

### 3.1 Cosa comporta pubblicare subito

- **Segreti.** Il repository è pubblico dal primo commit: un segreto finito nella cronologia resta esposto, anche se poi rimosso. Già in M0: scansione dei segreti in CI e prima di ogni commit; chiavi di firma, chiave di servizio Firebase e segreto di amministrazione restano fuori dal repository.
- **Dati reali.** Nessun dato, screenshot o nome reale di persone negli esempi, nei test o nella documentazione.
- **Licenza MIT.** Consente a chiunque di usare, modificare e ridistribuire il codice, anche in versioni chiuse o in servizi a pagamento, senza obbligo di condividere le modifiche. L’alternativa più usata per un server è **AGPL-3.0**, che obbliga chi offre il servizio in rete a pubblicare le proprie modifiche. MIT è una scelta legittima e la più semplice; va confermata sapendo questo (PD-13).
- **Asset generati con l’AI.** La licenza del codice non copre automaticamente le immagini: i loro termini dipendono dallo strumento usato e lo status di copyright di opere generate dall’AI è incerto. Prima di inserirle nel repository pubblico si verificano i termini dello strumento (D-11) e si sceglie una licenza separata per gli asset.
- **Nome e marchio.** La licenza del codice non concede il nome Deep Sky né il logo: serve una breve nota sull’uso del nome. Una ricerca preliminare non ha trovato app per coppie con questo nome, ma non è una verifica sufficiente: quella vera (domini, GitHub, marchi) è in M0.
- **Dipendenze.** Con MIT si evitano componenti copyleft nel client e nel server; la CI controlla le licenze delle dipendenze.
- **Sicurezza.** Il codice pubblico non sostituisce G-5: la revisione indipendente resta necessaria prima di invitare qualunque altra coppia.

## 4. Mappa dei milestone

La dimensione è **relativa** (S, M, L, XL), non una durata: serve a confrontare i milestone tra loro. Le durate reali si stimano dopo M2.

| ID | Milestone | Fase nel Project Brief | Dimensione | Dipende da |
| :-- | :-- | :-- | :-- | :-- |
| **M0** | Fondamenta | — | S | PD-07 … PD-10 |
| **M1** | Prototipi di verifica | 0 | M | M0 |
| **M2** | Scheletro funzionante | 1 | L | M1 (G-1), DS-2 |
| **M3** | Nucleo | 1 | XL | M2 (G-2), DS-3 … DS-5 |
| **M4** | Uso reale e revisione | 1 | S di lavoro, settimane di calendario | M3 (G-3) |
| **M5** | Memoria | 2 | L | M4 (G-4) |
| **M6** | Mondo | 3 | L | M5 |
| **M7** | Gioco del giorno | 4 | M | M6 |
| **M8** | Apertura | 5 | L | G-5 |

### 4.1 Capacità di revisione e stime indicative

Poiché il promotore supervisiona tutto (PD-11) e dedica circa un’ora al giorno (PD-12), il collo di bottiglia è la **revisione**, non la velocità degli agenti. Conseguenze:

- pull request **piccole**, rivedibili in 20 – 40 minuti, ciascuna con ID di riferimento, riepilogo, evidenza dei test e indicazione di cosa guardare con più attenzione;
- gli agenti eseguono test, analisi statica e auto-revisione **prima** di chiedere la revisione del promotore; la sua ora serve per decisioni, prove sui telefoni e punti delicati (sicurezza, contratti);
- un riepilogo settimanale dello stato, per decidere le priorità senza leggere tutto;
- fette dimensionate perché una prova sui due telefoni richieda poco tempo.

Stime **indicative** e molto incerte, assumendo circa 5 – 10 pull request medie a settimana. Non sono scadenze (PD-01) e vanno ricalibrate a G-1 con la velocità reale.

| Milestone | Durata indicativa |
| :-- | :-- |
| M0 | circa 1 settimana |
| M1 | 2 – 3 settimane |
| M2 | 4 – 6 settimane |
| M3 | 8 – 12 settimane |
| M4 | 2 – 3 settimane di calendario |
| M5 | 5 – 8 settimane |
| M6 | 5 – 8 settimane |
| M7 | 2 – 4 settimane |
| M8 | 4 – 8 settimane, escluso il tempo della revisione indipendente |

## 5. Piste di lavoro in parallelo

| Pista | Contenuto | Vincolo di sequenza |
| :-- | :-- | :-- |
| **Design** | DS-1 … DS-6 del Design Brief | Resta **una fetta avanti** agli sviluppatori; M2 richiede il pilota DS-2, M3 richiede DS-3 … DS-5 per ogni fetta |
| **Server** | API, dati, push, pacchetti | Contratti API approvati prima del client |
| **Client** | App, scena, sincronizzazione, cifratura | Dipende dai contratti e dal manifest della scena |
| **Android nativo** | Widget, installatore, Firebase, keystore | Esce dai prototipi SP-01, SP-03 |
| **Contenuti** | Produzione degli asset con l’AI e pacchetti firmati | Segue la Style Bible (A-03) |
| **Qualità e rilascio** | CI, test su dispositivi, release firmate, backup | Parte in M0 e cresce con il progetto |

## 6. Dettaglio dei milestone

### 6.1 M0, Fondamenta

**Attività:**

1. creazione del monorepo **pubblico** con licenza (PD-13), README, regole di contributo, nota di sicurezza e struttura delle cartelle;
2. protezioni: scansione dei segreti in CI e prima di ogni commit, scansione delle licenze delle dipendenze, regole sul ramo principale (merge solo con CI verde e approvazione del promotore);
3. CI: formattazione, analisi statica, test, build di server e app, con artefatti **non firmati**;
4. Docker Compose di sviluppo (api, db, proxy) con immagini ARM64 e AMD64;
5. infrastruttura OCI: record DNS di `deepsky.vectevo.com` verso la VM; porte 80 e 443 aperte sia nelle regole di rete di OCI sia nel firewall della VM (le immagini predefinite di OCI ne hanno di restrittive); Caddy con certificato automatico;
6. chiavi di firma: generazione offline della chiave dell’APK e di quella per manifest e pacchetti, backup cifrato in due luoghi, prova di ripristino; script di **firma locale** delle release;
7. convenzioni di versionamento e formato del manifest di release;
8. modello di pull request (ID, evidenza dei test, punti da rivedere) e di nota di decisione (ADR); board di lavoro;
9. verifica della disponibilità del nome Deep Sky (domini, GitHub, marchi).

**Uscita:** da un clone pulito si avviano server e database in locale e la CI produce un APK di prova non firmato, che si firma in locale con lo script, e https://deepsky.vectevo.com risponde con un controllo di salute.

### 6.2 M1, Prototipi di verifica

Prototipi piccoli e usa-e-getta, eseguibili in parallelo al design system. Ogni prototipo produce una **nota di decisione** che conferma o corregge il Documento architetturale.

| ID | Domanda | Criterio di superamento | Se fallisce |
| :-- | :-- | :-- | :-- |
| **SP-02** | Abbinamento, chiave di recupero e nuovo dispositivo | Flusso completato su due telefoni; recupero da sola chiave; il server non vede contenuti; comprensibile al partner non tecnico | Rivedere il protocollo con il revisore di sicurezza |
| **SP-01** | FCM con inizializzazione a runtime, ad app chiusa | Push ricevuto a processo chiuso su due telefoni reali | Interfaccia PushProvider (AR-10): UnifiedPush o build dedicata |
| **SP-04** | Home ibrida: scena a livelli con un livello animato, un asset sostituito, interfaccia attorno | Frame fluidi e memoria nei limiti su due telefoni; tocchi corretti a proporzioni diverse | Ridurre livelli e animazioni, rivedere regole di layout |
| **SP-03** | Aggiornamento APK da release GitHub con verifica | Aggiornamento riuscito; rifiuto di manifest alterato e di firma diversa | Rivedere flusso e verifiche |
| **SP-05** | Spring Boot e PostgreSQL sulla VM ARM | Consumo misurato e limiti definiti | Ottimizzazioni JVM o revisione dello stack |

**Uscita (G-1):** Documento architetturale aggiornato alla v0.2 con gli esiti dei prototipi.

### 6.3 M2, Scheletro funzionante

Il percorso più sottile che attraversa **tutta** l’architettura, con poche funzioni. Include:

- server su VM OCI con HTTPS (Caddy), inviti, coppie, dispositivi, autenticazione per firma;
- **abbinamento, chiave di recupero e arruolamento di un nuovo dispositivo** (F-01, F-20): sono la condizione per usare dati reali (PD-05);
- evento “ti penso” (F-03) cifrato, sincronizzazione, push generico;
- home con scena provvisoria a livelli, pacchetto di contenuti base, tokens del design system pilota;
- aggiornatore APK e controllo della versione minima (F-19, versione base);
- sola lettura offline; backup e prova di ripristino sulla VM.

**Uscita (G-2):** due telefoni reali si scambiano un gesto di punta a punta tramite il server OCI; un aggiornamento via release GitHub funziona due volte di fila; un ripristino da backup riesce.

### 6.4 M3, Nucleo

Fette verticali, in quest’ordine di partenza (il promotore può riordinarle):

| Fetta | Funzioni | Note |
| :-- | :-- | :-- |
| **SL-01** | Home e scena reali, design system completo, pacchetto contenuti v1 (F-02) | Sblocca le altre fette |
| **SL-02** | Thinking of you rifinito e notifiche (F-03, F-16) | Stile e testi del Design Brief |
| **SL-03** | Mood del giorno (F-04) | Sempre facoltativo |
| **SL-04** | Countdown (F-06) | Notifiche locali per le scadenze |
| **SL-05** | Disegno a turni (F-05) | Fetta più impegnativa del nucleo |
| **SL-06** | Time capsule (F-07) | Sigillo applicato dall’app (6.3.1) |
| **SL-07** | Aggiornamenti completi (F-19) | Schermate, errori, “aggiornamento richiesto” |
| **SL-08** | Offline, stati vuoti ed errori | Tono affettuoso, mai allarmante |

**Uscita (G-3):** tutte le fette finite secondo la Definition of Done; nessuna violazione dei principi P-02 e P-03; test su dispositivi reali; prova di ripristino ripetuta; guida per usare l’app a due.

### 6.5 M4, Uso reale e revisione

Uso tra voi due per **2 – 3 settimane**, con le sole funzioni del nucleo. Un diario di osservazioni, i segnali del cap. 13 del Project Brief (apertura spontanea da parte di entrambi, nessun senso di dovere), correzione dei difetti. Revisione interna di sicurezza e preparazione della revisione indipendente.

**Uscita (G-4):** elenco motivato di ciò che manca, soluzione di D-03 e priorità per M5.

### 6.6 M5 – M8, sintesi

| Milestone | Contenuto principale | Uscita |
| :-- | :-- | :-- |
| **M5 Memoria** | Corkboard (F-08), foto del giorno (F-10), timeline (F-11), giorni insieme (F-12), widget (F-13), messaggi brevi (F-15), esportazione e scioglimento (F-17, S-03) | Archivio dei ricordi usato davvero da entrambi |
| **M6 Mondo** | Pet e stanza (F-09), personalizzazione degli asset (F-18), decorazioni, animazione di livello 1 con più livelli; esplorazione del livello 3 (DD-11) | Pet e casa che reagiscono alle attività |
| **M7 Gioco del giorno** | Modulo unico (F-14) | Contenuti ricorrenti senza pressione |
| **M8 Apertura** | Revisione indipendente di sicurezza (G-5), verifica sviluppatore Android (D-14), licenza e apertura del codice (D-05), guida completa al self-hosting, collaudo multi-coppia | Pubblicazione per altri |

M5 – M7 si pianificano nel dettaglio solo dopo G-4.

## 7. Modello di fetta verticale

Ogni fetta SL-xx contiene, nell’ordine:

1. **Definizione:** funzioni, ID, criteri di accettazione;
2. **Design:** schermate, stati, asset e pacchetto di contenuti (design una fetta avanti);
3. **Contratto:** API, formato degli eventi, versione dello schema;
4. **Server e client** in parallelo sul contratto;
5. **Test:** unitari, integrazione, *golden*, due dispositivi;
6. **Release:** APK firmato, manifest, eventuale pacchetto di contenuti;
7. **Osservazioni d’uso:** note per la fetta successiva.

## 8. Gate

| Gate | Quando | Cosa si verifica | Approva |
| :-- | :-- | :-- | :-- |
| **G-1** | Fine M1 | Rischi architetturali chiusi, architettura confermata o corretta | Promotore |
| **G-2** | Fine M2 | Scheletro end-to-end, aggiornamento e ripristino provati | Promotore |
| **G-3** | Fine M3 | Pronto per l’uso reale: principi rispettati, test superati | Promotore |
| **G-4** | Fine M4 | Cosa aggiungere, dalle osservazioni d’uso | Promotore |
| **G-5** | Prima di M8, e prima di invitare **qualunque altra coppia** | **Revisione indipendente** di cifratura, protocolli, filiera degli aggiornamenti | Promotore con il revisore |

## 9. Rischi del piano

| Rischio | Impatto | Mitigazione |
| :-- | :-- | :-- |
| Scope troppo ampio | Nessuna parte rifinita | PD-03, nucleo piccolo, funzioni solo se mancano a entrambi |
| Design e sviluppo fuori sincronia | Sviluppatori in attesa o lavoro buttato | Design una fetta avanti, contratti approvati prima |
| Revisione come collo di bottiglia | Lavoro fermo in attesa | Pull request piccole, auto-revisione degli agenti, riepilogo settimanale (4.1) |
| Velocità degli agenti e del promotore sconosciute | Stime inaffidabili | Stime indicative, calibrazione a G-1, pianificazione a ondate |
| Prototipi che smentiscono l’architettura | Rifacimenti | Farli in M1, prima di costruire; nota di decisione per ogni esito |
| Dati reali usati troppo presto | Perdita o esposizione di dati intimi | PD-05, G-2 |
| Segreti nel repository pubblico | Esposizione irrimediabile nella cronologia | Scansione dei segreti in CI e pre-commit; nessun segreto nel repository; chiavi solo offline |
| Perdita delle chiavi di firma | Aggiornamenti impossibili | PD-10, backup cifrato in due luoghi, prova di ripristino |
| Licenza degli asset AI non chiarita | Asset non redistribuibili nel repository pubblico | D-11 prima di pubblicare gli asset |
| Verifica degli sviluppatori Android in Italia | APK pubblico ostacolato | D-14, nome del pacchetto stabile (PD-07) |

## 10. Prossimi passi

1. Confermare la **licenza del codice** (PD-13) e avviare la verifica dei termini degli strumenti di generazione per gli asset (D-11).
2. Avviare **M0**.
3. Avviare **M1** in parallelo a DS-1 e DS-2 del designer, partendo da SP-02 e SP-01, i prototipi più rischiosi.
4. Preparare il dettaglio di **M2** a partire dagli esiti di G-1.

## 11. Tracciabilità

Ogni task e ogni fetta cita gli ID di questo piano (PD, M, SL, G) e dei documenti da cui discende. In caso di conflitto con una decisione **\[Deciso\]**, il conflitto si segnala al promotore senza risolverlo in autonomia.
