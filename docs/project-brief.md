# Project Brief: Deep Sky

**Versione:** 0.2 (bozza per revisione) · **Data:** 12 novembre 2026 · **Stato:** in attesa di approvazione del promotore

**Destinatari:** promotore del progetto e team di agenti AI incaricati di produrre i documenti successivi (design system, documento architetturale, piano di sviluppo, specifiche, test plan).

**Novità della v0.2 (12 novembre 2026):** Android come prima piattaforma (N-02); cifratura end-to-end confermata dalla v1 con recupero tramite scambio di chiavi tra telefoni e chiave di recupero (S-01, S-06); app offline in sola lettura (N-03); aggiornamenti integrati dalla v1 (N-10, F-19); recupero e nuovo dispositivo (F-20); stack deciso (D-06). Le decisioni tecniche di dettaglio sono nel documento Considerazioni tecniche.

**Come leggere lo stato delle affermazioni.** Ogni decisione è marcata così:

- **\[Deciso\]**: confermato dal promotore.
- **\[Ipotesi\]**: proposta ragionevole emersa dalla fase di discovery, non ancora confermata. Gli agenti la trattano come default di lavoro e segnalano se la ritengono problematica.
- **\[Aperto\]**: questione irrisolta, elencata nel capitolo 14. Gli agenti non la risolvono da soli: la sollevano.

Questo documento è autosufficiente: chi lo legge non ha bisogno di altro contesto.

---

## 1. Visione in sintesi

Costruiamo **una casa digitale privata per due persone**: un’app mobile in cui una coppia, anche a distanza, lascia piccoli segni della propria presenza nella giornata dell’altra. Non è un gestionale di coppia e non è una chat. Disegni, umori, countdown, ricordi e un piccolo pet condiviso non sono funzioni separate: lasciano tracce visibili nello stesso spazio, la “nostra casa”, che cresce con la relazione.

> Una casa privata e affettuosa per due persone: mobile-first, senza pubblicità, senza streak, senza monete, con un pet che ricorda la vostra storia.

**\[Deciso\]** Il prodotto nasce innanzitutto come app che il promotore userà con la propria partner. L’apertura del codice (open source) è una scelta di valori e di sostenibilità, ma non è l’argomento principale del progetto: il valore primario è l’esperienza.

## 2. Obiettivi e non-obiettivi

### Obiettivi

1. Offrire un’esperienza di vicinanza quotidiana, ricca e piacevole, che due persone vogliano usare spontaneamente.
2. Garantire che l’intera esperienza sia gratuita da self-hostare, senza pubblicità, tracciamento pubblicitario o funzioni affettive a pagamento.
3. Rendere l’app godibile per entrambi i partner, anche quando solo uno dei due è tecnico.
4. Trattare privacy e sicurezza come requisiti verificabili, non come tono rassicurante.
5. Seguire un processo di sviluppo software completo (brief, design, architettura, piano, implementazione, test, rilascio).

### Non-obiettivi (per ora)

- Chat libera, chiamate audio o video come funzioni centrali.
- Gestione spese, calendari condivisi complessi, sincronizzazione con calendari esterni.
- Dating, matching tra sconosciuti, funzioni social tra più coppie.
- Gamification, valute virtuali, livelli, missioni, classifiche.
- Hosting gratuito illimitato offerto dal progetto.

## 3. Contesto e problema

Le app per coppie esistenti seguono quasi tutte uno di questi schemi: pubblicità invasive, funzioni affettive dietro abbonamento, meccaniche di engagement (streak, monete, ricompense) che trasformano l’affetto in un dovere misurabile. Esistono alternative open source, ma nessuna soddisfa insieme le esigenze del promotore.

La discovery ha esaminato tre progetti rilevanti. Sono riferimenti, non obiettivi da replicare:

| Progetto | Cosa fa bene | Perché non basta |
| :-- | :-- | :-- |
| **Kehai** (MIT) | Concetto più vicino: pet condiviso che non muore, corkboard, doodle, umore, countdown, domande | Grafica non apprezzata; impostazione desktop-first; si dichiara progetto personale, senza roadmap né supporto |
| **Togetherly** (GPL-3.0) | Ampia base funzionale: time capsule, mood, widget, disegno condiviso, mascotte | Coin, ricompense, streak e pubblicità: esattamente l’engagement loop da evitare |
| **OnePair** (licenza non verificata) | Esperienza senza account, drawing, lettere, capsule | Focus su chat, chiamate e sincronizzazione peer-to-peer; consegna asincrona limitata; poche feature di interesse |

**Conclusione.** Il gap non sono le feature, già esistenti, ma la **qualità dell’esperienza**: una casa mobile-first, calda e curata, aperta e senza economia dell’attenzione, che funzioni su Android e iPhone e sia semplice per il partner non tecnico.

## 4. Utenti

**Utenti primari:** coppie (anche a distanza) composte da due persone. L’app è sempre usata da esattamente due persone abbinate.

**Persona A, “il configuratore”.** Ha competenze tecniche, è disposto a installare e mantenere un server o a scegliere un hosting. Decide dove vivono i dati.

**Persona B, “il partner”.** Non vuole sapere cosa sia un server. Installa l’app, accetta un invito e deve trovarla bella, semplice e affidabile fin dal primo minuto.

**Vincolo di design:** la riuscita del prodotto si misura sulla Persona B. Se solo il configuratore è felice, il prodotto ha fallito.

**\[Ipotesi\]** Utenti secondari futuri: coppie non tecniche che pagano per un hosting gestito; persone che desiderano contribuire al codice.

## 5. Principi di prodotto

Sono i criteri con cui accettare o rifiutare ogni funzione e ogni scelta di design. Gli agenti li citano per ID.

- **P-01. Piccoli gesti, non grandi impegni.** Ogni interazione chiave deve potersi completare in pochi secondi.
- **P-02. Affetto senza obbligo.** Nessuna funzione trasforma l’affetto in qualcosa di misurabile o dovuto. Vietati: streak, punteggi di compatibilità, conteggi su chi invia di più, solleciti automatici (“il tuo partner aspetta da due giorni”), richieste insistenti di spiegare un umore. Non aprire l’app per giorni deve essere normale.
- **P-03. Engagement volontario e non punitivo.** Le notifiche esistono per un gesto reale dell’altra persona, mai per riportare l’utente nell’app. Il pet non muore e non si degrada. Gli oggetti della casa si sbloccano come conseguenza naturale delle attività, non come valuta.
- **P-04. Casa-first, non feature-first.** Le funzioni non sono sezioni di un menu: ogni attività lascia un artefatto visibile nella casa.
- **P-05. Mobile-first.** L’esperienza primaria è sullo smartphone. Android e iOS sono entrambi cittadini di prima classe.
- **P-06. Sicurezza come promessa precisa.** “Open source”, “self-hosted” e “privato” non sono sinonimi: sono tre impegni distinti (codice ispezionabile, scelta di chi ospita i dati, protezione del contenuto) e vanno descritti e verificati separatamente.
- **P-07. Nessun controllo implicito.** Presenza online, conferme di lettura e posizione non sono presenti o, se introdotti in futuro, sono facoltativi e disattivati di default.
- **P-08. Asincrono per natura.** Un gesto deve arrivare anche se l’altra persona è offline.
- **P-09. Semplicità per chi non è tecnico.** Il self-hosting è una scelta di chi configura, non una complicazione quotidiana per chi usa.
- **P-10. Tutto è gratuito se lo ospiti tu.** Nessuna funzione affettiva è bloccata a pagamento.

## 6. Concetto di prodotto: la casa

La metafora centrale è **“la nostra casa”**: una piccola stanza condivisa che cresce con la relazione. Gli artefatti prodotti dalle attività vi compaiono:

- un disegno finito diventa un quadro sulla corkboard;
- una foto del giorno entra nell’album o nella timeline;
- una lettera sigillata diventa un oggetto nella casa fino alla data di apertura;
- una risposta a una domanda può diventare una pagina di diario o un ricordo;
- un countdown può diventare un calendario sulla parete;
- il pet reagisce a ciò che avete fatto (un cuscino nuovo dopo una time capsule aperta, una foto appesa dopo una foto del giorno, un disegno sul muro dopo un disegno condiviso).

La casa non è una valuta, non è un dovere e non misura l’amore.

**Schermata principale (esempio di intento).** La home deve raccontare in un colpo d’occhio, ad esempio: “Ci vediamo tra 12 giorni. Oggi mi sento un po’ scarico, ma ho voglia di sentirti. Ti ho lasciato un disegno.”

## 7. Funzionalità

### 7.1 Livelli

| Livello | Funzioni | Ruolo |
| :-- | :-- | :-- |
| **Cuore quotidiano** | Thinking of you, mood, disegno a turni, countdown, foto del giorno, domande | Piccoli momenti ricorrenti |
| **Memoria della coppia** | Timeline, time capsule, corkboard, giorni insieme, widget | Archivio affettivo |
| **Mondo condiviso** | Pet, casa virtuale, decorazioni, oggetti sbloccati | Continuità e motivo per tornare |

### 7.2 Catalogo delle funzioni

Gli ID sono stabili e vanno usati nei documenti successivi.

| ID | Funzione | Descrizione |
| :-- | :-- | :-- |
| **F-01** | Abbinamento | Invito tramite link o QR, senza account pubblici. Procedura comprensibile per entrambi. Possibilità per ciascuno di interrompere l’abbinamento unilateralmente. |
| **F-02** | Home della casa | Vista d’insieme: countdown attivo, umore recente, ultimo disegno, prossima apertura di time capsule. |
| **F-03** | Thinking of you | Un tocco, con breve frase facoltativa e notifica discreta. |
| **F-04** | Mood del giorno | Emoji o piccolo stato, nota facoltativa (anche “oggi avrei bisogno di…”), storico condiviso. Sempre facoltativo. |
| **F-05** | Disegno a turni | Uno disegna e invia; l’altro può disegnarci sopra; entrambi possono aggiungere messaggi. Asincrono, nessun canvas in tempo reale. Pensato anche per chi non sa disegnare. |
| **F-06** | Countdown | Data, titolo, descrizione, todo list, immagini e commenti. Prossimo incontro, anniversario o evento a scelta. |
| **F-07** | Time capsule | Foto o lettera sigillata fino a una data scelta, che si apre il giorno stabilito. |
| **F-08** | Corkboard | Bacheca libera dove appendere immagini e disegni. |
| **F-09** | Pet e stanza | Pet condiviso che reagisce alle attività recenti, non muore, conserva una piccola storia di ciò che avete fatto. La casa raccoglie gli artefatti. |
| **F-10** | Foto del giorno | Una foto quotidiana facoltativa che entra nell’album o nella timeline. |
| **F-11** | Timeline / memories | Cronologia di ciò che è successo, con immagini. |
| **F-12** | Giorni insieme | Contatore dei giorni passati insieme. Mai usato come misura di impegno. |
| **F-13** | Widget | Widget home screen per Android e iOS (es. foto condivisa, giorni insieme, countdown, mood). |
| **F-14** | Gioco del giorno | Unico modulo che raccoglie domanda del giorno, this or that, would you rather, truth or dare e tic tac toe, per evitare un “pacco di mini-giochi”. |
| **F-15** | Messaggi brevi contestuali | Frasi, reazioni e note facoltative allegate a disegni, foto, countdown, domande. Nessuna chat libera. |
| **F-16** | Notifiche | Discrete, con contenuto generico di default sulla schermata bloccata. Solo per gesti reali dell’altra persona. |
| **F-17** | Esportazione e cancellazione | Esportazione completa dei dati; regole esplicite per cancellazione e destino dei contenuti condivisi. |
| F-18 | Personalizzazione degli asset | La coppia sostituisce gli asset della casa (pet, personaggi dei partner, oggetti) con immagini proprie: l’app esporta l’asset attuale con scheda tecnica e prompt suggeriti, l’utente li porta al proprio assistente AI e ricarica il risultato. L’app non offre né integra alcun servizio AI. Ripristino sempre possibile. |
| F-19 | Aggiornamenti dell’app | Controllo e installazione degli aggiornamenti dell’APK dalle release GitHub e download di pacchetti di contenuti dal server, sempre con conferma dell’utente. Il server può imporre una versione minima del client. |
| F-20 | Recupero e nuovo dispositivo | Chiave di recupero generata all’abbinamento, con conferma di avvenuto salvataggio; reinstallazione su un nuovo telefono tramite re-invio delle chiavi dall’altro dispositivo o tramite la chiave di recupero (S-06). |

### 7.3 Escluso o rimandato

- **Escluse:** chat libera come funzione centrale, chiamate audio/video, streak, coin, livelli, missioni, ricompense, pubblicità, punteggi di compatibilità.
- **Rimandate a valutazione futura:** gestione spese, calendari condivisi, presenza online, posizione, musica in ascolto, dati da wearable, fusi orari. Se introdotte, devono rispettare P-02 e P-07.

## 8. Fasi e perimetro del rilascio

**\[Ipotesi\]** Sequenza proposta, da confermare (vedi D-03 nel capitolo 14):

| Fase | Contenuto | Scopo |
| :-- | :-- | :-- |
| **0. Discovery e design** | Moodboard, struttura della casa, prototipi cliccabili di home, disegno a turni, mood, countdown, time capsule | Definire sensazione e identità visiva prima del codice |
| **1. Nucleo (dogfooding)** | F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-16, F-19, F-20 | Uso reale in due per 2-3 settimane, senza pet né corkboard |
| **2. Memoria** | F-08, F-10, F-11, F-12, F-13, F-15, F-17 | Aggiungere ciò che entrambi sentono mancare |
| **3. Mondo** | F-09, F-18 e decorazioni | Dare continuità e identità alla casa |
| **4. Gioco del giorno** | F-14 | Contenuti ricorrenti in un unico modulo |
| **5. Apertura** | Decisione su licenza, pubblicazione del codice, modello di hosting | Rilascio pubblico |

Le funzioni vengono aggiunte solo se entrambi i partner ne sentono la mancanza durante l’uso reale.

## 9. Sicurezza e privacy

Requisiti espressi come impegni verificabili. Il documento architetturale deve dire come ciascuno sarà soddisfatto e verificato.

- **S-01 \[Deciso\]** Il gestore del server non può leggere i contenuti intimi: cifratura end-to-end dalla prima versione. Lo stato derivato (ad esempio le reazioni del pet) è calcolato da un dispositivo, cifrato e caricato sul server per la sincronizzazione. Se per qualche contenuto fosse impossibile, va dichiarato esplicitamente.
- **S-02 \[Ipotesi\]** Le notifiche mostrano contenuto generico di default, senza esporre umori o messaggi sulla schermata bloccata.
- **S-03 \[Ipotesi\]** Ogni persona può interrompere l’abbinamento senza il consenso dell’altra.
- **S-04 \[Ipotesi\]** Esportazione, cancellazione e destino dei contenuti condivisi hanno regole esplicite e documentate.
- **S-05 \[Ipotesi\]** Nessuna presenza online, conferma di lettura o posizione attive di default (P-07).
- **S-06 \[Deciso\]** I dati devono essere sempre recuperabili in caso di perdita di un telefono: l’altro telefono può re-inviare le chiavi al nuovo dispositivo e, in più, all’abbinamento viene generata una **chiave di recupero** che l’utente deve confermare di aver salvato. Il recupero è garantito finché esiste l’altro telefono o la chiave salvata, e l’utente lo deve sapere in modo chiaro.
- **S-07 \[Deciso\]** Nessuna telemetria pubblicitaria e nessun tracciamento a fini di advertising.

## 10. Requisiti non funzionali (direzioni)

Sono direzioni da trasformare in requisiti misurabili nel documento architetturale.

- **N-01 Consegna asincrona affidabile:** un gesto inviato arriva anche con il destinatario offline, nel rispetto di S-01.
- **N-02 Compatibilità:** Android per primo **\[Deciso\]**; iOS in una fase successiva, con le implicazioni su account sviluppatore a pagamento e relay per il push da riaffrontare allora. Su Android l’app è distribuita come APK (N-10).
- **N-03 Tolleranza alla rete:** uso accettabile con connessione intermittente e reti diverse. Senza connessione l’app è in **sola lettura** **\[Deciso\]**: scena e ricordi consultabili, azioni di scrittura disattivate con un messaggio gentile (P-02), nessuna coda di sincronizzazione.
- **N-04 Self-hosting semplice:** installazione e aggiornamento del server documentati e riproducibili, con manutenzione minima.
- **N-05 Portabilità dei dati:** formati esportati aperti e documentati, nessuna dipendenza obbligatoria da un servizio del progetto.
- **N-06 Indipendenza da terze parti:** nessuna API esterna obbligatoria; eventuali servizi opzionali (es. notifiche push) sono sostituibili e documentati.
- **N-07 Accessibilità e localizzazione:** italiano e inglese come lingue iniziali **\[Ipotesi\]**; accessibilità di base (contrasto, dimensioni testo, screen reader) nel design system.
- **N-08 Prestazioni percepite:** apertura dell’app e invio di un gesto devono sembrare immediati.
- **N-09 Asset visivi generati con l’AI e sostituibili:** gli asset sono immagini PNG/JPG prodotte con strumenti AI; la coppia può sostituirli con immagini proprie tramite un flusso di esportazione e ricaricamento, senza che l’app integri alcun servizio AI (N-06). Il sistema deve validare formato, dimensioni e trasparenza delle immagini caricate.
- **N-10 Aggiornamenti integrati dalla prima versione** **\[Deciso\]**: l’app include due meccanismi. (1) Pacchetti di contenuti (asset, manifest della scena, testi) scaricati dal server e verificati, senza installazione. (2) Aggiornamento dell’APK scaricato dalle release GitHub del progetto, con sorgente configurabile, e installato tramite il permesso “Installa app sconosciute” con la conferma di sistema. Il server può imporre una versione minima del client e del protocollo.

## 11. Direzione di esperienza e visiva

- **\[Deciso\]** Mobile-first, calda, non infantile. La grafica è un elemento centrale del prodotto, non una rifinitura.
- Punto di partenza negativo, per contrasto: la grafica di Kehai è stata giudicata poco attraente, e la meccanica a ricompense di Togetherly è stressante.
- Il pet e la casa devono comunicare tenerezza senza risultare infantili né da gioco a punti.
- Il tono dei testi è affettuoso e mai pressante: “puoi lasciare qualcosa”, mai “devi dimostrare qualcosa”.
- Il design system dovrà derivare da un moodboard approvato dal promotore (D-04).

## 12. Modello open source e sostenibilità

**\[Ipotesi\]** Si separa il software dal servizio:

| Componente | Proposta |
| :-- | :-- |
| Applicazione e backend | Open source, senza blocchi funzionali |
| Self-hosting | Stesse funzioni del servizio gestito |
| Hosting gestito | Eventuale servizio a pagamento per chi non vuole amministrare nulla |
| Supporto e manutenzione | Possibili servizi aggiuntivi |
| Finanziamento comunitario | Donazioni e sponsorizzazioni, senza influenza sui dati |

Si paga, eventualmente, per la comodità dell’infrastruttura, mai per poter inviare un gesto d’affetto. Non si promette hosting gratuito illimitato prima di aver stimato costi e modalità d’uso. **\[Deciso\]** La decisione se e quando aprire il codice, e con quale licenza, viene presa dopo il dogfooding (D-05).

## 13. Validazione e metriche di successo

**Domanda guida (metrica nord):** *“Quando avete pensato l’uno all’altra, avete aperto questa app invece di non fare nulla?”*

Il successo non si misura in download. Segnali da osservare durante il dogfooding, raccolti con il consenso dei due partner e nel rispetto di P-02:

- entrambi i partner aprono l’app spontaneamente, non solo il configuratore;
- l’app viene scelta per un gesto reale (un “ti penso”, un disegno) invece di un messaggio altrove;
- i partner segnalano spontaneamente cosa manca;
- nessun partner prova senso di dovere o di colpa per non aver usato l’app.

Le metriche non devono mai diventare funzioni visibili agli utenti (nessun contatore di attenzioni).

## 14. Decisioni aperte

Gli agenti non le risolvono: le segnalano e propongono alternative con pro e contro.

| ID | Questione | Note |
| :-- | :-- | :-- |
| **D-01** | Nome definitivo del prodotto | **\[Deciso\]** **Deep Sky**. |
| **D-02** | Cifratura end-to-end: ambito e compromessi | Deciso: E2EE dalla v1 (S-01), stato calcolato da un dispositivo, recupero con scambio di chiavi tra telefoni e chiave di recupero (S-06). Dettagli nelle Considerazioni tecniche. |
| **D-03** | Perimetro dell’MVP | La discovery ha prodotto sia un MVP di nove elementi (inclusi pet e corkboard) sia una sequenza che li rimanda dopo il dogfooding. Va scelto il confine. |
| **D-04** | Direzione visiva | Serve un moodboard approvato (stile, palette, stile del pet). |
| **D-05** | Licenza e momento di apertura del codice | Decisione dopo il dogfooding. |
| **D-06** | Stack tecnologico e architettura | Deciso: Flutter per l’app; Java con Spring Boot e PostgreSQL per il backend; tutto in Docker Compose, con immagini per ARM e AMD. Il documento architetturale ne dettaglia l’uso. |
| **D-07** | Piattaforme al lancio | Deciso: Android per primo, distribuito come APK dalle release GitHub, senza Play Store né App Store per ora. iOS rimandato. |
| **D-08** | Notifiche push | Proposta: FCM con credenziali Firebase fornite a runtime dal server del self-hoster, senza relay; da validare con un prototipo. UnifiedPush come opzione futura. |
| **D-09** | Verifica indipendente delle alternative | Una prova pratica di Kehai e OnePair con due dispositivi reali non è stata ancora svolta. Il promotore ha già valutato i progetti; decidere se serve altro. |
| **D-10** | Modello di hosting gestito | Se e quando offrirlo, a quale costo e con quali garanzie. |
| D-11 | Strumento di generazione e licenza degli asset AI | I termini d’uso dello strumento devono consentire la redistribuzione degli asset in un progetto open source. La licenza degli asset può differire da quella del codice. |
| D-12 | Granularità e visibilità della personalizzazione (F-18) | Sostituire interi set di pose o aggiungere accessori sovrapposti? Le personalizzazioni sono visibili a entrambi i partner o solo a chi le crea? Come trattarle rispetto a S-01 (contenuti privati). |
| D-13 | Esposizione di rete del server | HTTPS pubblico dietro reverse proxy oppure rete privata (es. Tailscale). Impatta la semplicità per il partner non tecnico (P-09) e la sicurezza. |
| D-14 | Verifica sviluppatore Android per l’APK ufficiale | L’account a distribuzione limitata copre fino a 20 dispositivi. Un APK ufficiale pubblico richiederà la verifica completa quando il requisito si estenderà all’Italia (previsto dal 2027). Nome del pacchetto e chiave di firma devono restare stabili. |

## 15. Rischi principali

| Rischio | Impatto | Mitigazione |
| :-- | :-- | :-- |
| Scope troppo ampio (casa, pet, giochi, memoria) | Prodotto mai rifinito | Fasi, dogfooding, rifiuto di feature che non servono un bisogno del cuore quotidiano |
| E2EE complessa con consegna asincrona e recupero chiavi | Ritardi o promesse non mantenibili | Decisione precoce (D-02), prototipo tecnico, dichiarazioni oneste |
| Qualità grafica insufficiente | Il prodotto non conquista il partner non tecnico | Moodboard e prototipi prima del codice, test con la Persona B |
| Deriva verso l’engagement farming | Tradimento dei principi | P-02 e P-03 come criteri di accettazione di ogni funzione |
| Distribuzione su iOS e aggiornamenti | Esperienza diseguale tra Android e iPhone | Decisione esplicita (D-07) |
| Progetto portato avanti da una persona sola | Abbandono o rallentamento | Piano di sviluppo realistico, documentazione, apertura del codice dopo il dogfooding |

## 16. Glossario

- **Casa:** spazio condiviso che raccoglie gli artefatti creati dalla coppia.
- **Artefatto:** traccia visibile lasciata da un’attività (quadro, foto, lettera, oggetto).
- **Gesto:** interazione breve che comunica presenza (es. “ti penso”).
- **Dogfooding:** uso reale del prodotto da parte dei due promotori prima di aprirlo ad altri.
- **Configuratore / Partner:** le due personas descritte al capitolo 4.
- **E2EE:** cifratura end-to-end, per cui solo i due partner possono leggere i contenuti.

## 17. Documenti successivi

| Documento | Dipende da questo brief per | Produce |
| :-- | :-- | :-- |
| **Design system** | Capitolo 5 (principi), 6, 11 | Moodboard, tipografia, colori, componenti, tono dei testi |
| **Documento architetturale** | Capitoli 9 e 10, D-02, D-06, D-07, D-08 | Stack, modello dei dati, modello di sicurezza, deployment |
| **Specifiche funzionali** | Capitolo 7 (ID F-xx) | Flussi, casi limite, criteri di accettazione per funzione |
| **Piano di sviluppo** | Capitoli 8 e 15 | Milestone, ordine di lavoro, dipendenze |
| **Test plan** | Capitoli 9, 10 e 13 | Strategia di test, sicurezza, usabilità con la Persona B |
| **Piano di apertura e sostenibilità** | Capitolo 12, D-05, D-10 | Licenza, governance, hosting gestito |

**Regola per gli agenti.** Ogni funzione, requisito o decisione nei documenti successivi deve citare l’ID di questo brief (P-xx, F-xx, S-xx, N-xx, D-xx) da cui discende. Se un documento entra in conflitto con un principio P-xx, vince il principio e il conflitto va segnalato al promotore.
