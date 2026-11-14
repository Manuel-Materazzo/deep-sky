# Design Brief: Deep Sky

**Versione:** 0.2 (bozza per revisione) · **Data:** 12 novembre 2026 · **Dipende da:** Project Brief v0.2

**Destinatario:** agente designer. Non conosce nulla del progetto: questo documento, insieme al Project Brief, è tutto ciò che gli serve.

**Convenzioni.** Gli stati **\[Deciso\]**, **\[Ipotesi\]**, **\[Aperto\]** hanno lo stesso significato del Project Brief. Gli ID di questo documento sono **V-xx** (requisiti visivi e di esperienza), **A-xx** (requisiti sugli asset), **DD-xx** (decisioni aperte di design). Gli ID P-xx, F-xx, S-xx, N-xx rimandano al Project Brief e vanno citati nei deliverable.

**Novità della v0.2 (12 novembre 2026), per chi ha già iniziato a lavorare:** (1) piattaforma Android per prima; (2) nuove schermate da progettare: aggiornamento dell’app, chiave di recupero e nuovo dispositivo, modalità offline in sola lettura (capitolo 7); (3) animazione: si parte dal livello 1, con più livelli sovrapposti per slot, e si lascia aperta la strada verso l’animazione scheletrica o a parti (capitolo 11, DD-11). Il resto del documento è invariato.

---

## 1. Missione

Il designer definisce **identità, linguaggio visivo, sistema di asset e design system** di un’app mobile per coppie. Non decide stack tecnologico, architettura o modello dei dati: se un vincolo tecnico limita il design, lo segnala come domanda al promotore.

## 2. Il prodotto in breve

È una **casa digitale privata per due persone**, anche a distanza. Non è una chat né un gestionale: è uno spazio dove ogni piccolo gesto (un “ti penso”, un disegno a turni, un umore, un countdown, una time capsule, una foto del giorno) lascia una traccia visibile nella stanza condivisa. Un pet condiviso, che non muore mai, reagisce a ciò che la coppia fa. Mobile-first, senza pubblicità, senza streak, senza monete, open source.

Principi che il design deve incarnare: **P-01** piccoli gesti, **P-02** affetto senza obbligo, **P-03** engagement volontario e non punitivo, **P-04** casa-first, **P-05** mobile-first, **P-09** semplicità per chi non è tecnico.

## 3. Intento emotivo

| Chi apre la casa deve sentire | Non deve mai sentire |
| :-- | :-- |
| Tenerezza, calma, intimità | Dovere, colpa, pressione di “dimostrare” qualcosa |
| Che l’altra persona c’è, anche a distanza | Controllo o sorveglianza reciproca |
| Curiosità di scoprire cosa è stato lasciato | Ansia da notifica, da “non letto”, da urgenza |
| Che un’assenza di giorni sia normale | Che la casa “si spenga” o punisca l’inattività |
| Gioco affettuoso | Un’app per bambini o un gioco a punti |

## 4. Identità

### 4.1 Nome

**\[Aperto\] DD-01.** La direzione scelta è “la luce lasciata accesa”: il gesto di far sapere che ci sei senza scrivere. Il nome definitivo non è confermato. Il designer può usare **“Lucciola”** solo come segnaposto di lavoro e **non lo incide in asset finali** finché il promotore non lo conferma. Alternativa tenuta in riserva: “Lanterna”.

### 4.2 Concetto: la luce

**\[Ipotesi\]** La luce è il motivo ricorrente dell’identità e del linguaggio dell’interfaccia: quando l’altra persona lascia un gesto, nella casa si accende qualcosa (una finestra, una lampada, una piccola luce). Regola ferrea (P-02, P-03): **la casa non si spegne e non diventa buia per inattività**. La luce premia l’arrivo di un gesto, non punisce la sua assenza.

Logo e icona: semplici, riconoscibili a 48 px, efficaci in monocromia, leggibili sia su sfondo chiaro sia scuro. Nessun testo nell’icona.

## 5. Direzione visiva

- **V-01** Calda, non infantile: un mondo tenero per adulti che si amano, non un gioco per bambini.
- **V-02** Mobile-first: progettata per una mano e il pollice. Il desktop non è un target.
- **V-03** Casa-first: la home è la casa, non un menu di funzioni.
- **V-04** Un solo stile illustrativo coerente per pet, avatar, oggetti e sfondi.
- **V-05** Stile **producibile con l’AI**: va scelto perché riproducibile in modo coerente da generatori di immagini. Evitare stili che richiedono precisione tecnica (prospettive complesse, mani dettagliate, testo nelle immagini).
- **V-06** Tema chiaro e scuro. La sera è un momento centrale d’uso e il tema scuro è un cittadino di prima classe, non un’inversione di colori.
- **V-07** Accessibilità: contrasto AA, aree di tocco adeguate, testo ridimensionabile, significato mai affidato al solo colore, rispetto di “riduci movimento”.
- **V-08** Nessun dark pattern visivo: niente badge rossi d’urgenza, contatori ansiogeni, indicatori di “non letto” aggressivi. Le novità si segnalano con delicatezza.
- **V-09** La casa deve funzionare anche **spoglia**: nella prima fase (nucleo) non ci sono pet né corkboard, e deve poi crescere senza ricostruire la composizione.

**Anti-riferimenti.** Estetica desktop-first e ambient del progetto Kehai (grafica non apprezzata dal promotore); linguaggio visivo a monete, ricompense e streak di Togetherly. Non copiare grafiche di progetti esistenti.

**Riferimenti positivi.** **\[Aperto\] DD-02**: vanno definiti insieme al promotore tramite moodboard (vedi fasi, capitolo 11).

## 6. La casa

### 6.1 Composizione

**\[Ipotesi\]** Una scena illustrata 2D in sezione, vista frontale, composta da **oggetti in slot fissi** sopra uno sfondo. Ogni oggetto corrisponde a una funzione e tappandolo la si apre:

- finestra: la luce, l’ora del giorno, i gesti ricevuti (F-03);
- calendario o lavagna a parete: countdown (F-06);
- scatola o mensola sigillata: time capsule (F-07);
- corkboard: disegni e immagini appesi (F-08);
- cornice o album: foto del giorno e timeline (F-10, F-11);
- libro o diario: domande e “gioco del giorno” (F-14);
- il pet (F-09) e i due personaggi dei partner.

La scena non può essere l’unica forma di navigazione: serve un accesso minimo e accessibile alle funzioni (**DD-04**).

### 6.2 Regole degli artefatti

- Ogni attività lascia un artefatto visibile nella casa (P-04).
- La casa non diventa mai satura: quando uno spazio (es. la corkboard) si riempie, gli elementi più vecchi passano alla timeline senza essere persi.
- Gli oggetti si sbloccano come conseguenza naturale delle attività, mai come valuta o ricompensa (P-03).

## 7. Inventario delle schermate e dei momenti

| Schermata o momento | Funzioni | Note di design |
| :-- | :-- | :-- |
| Onboarding e abbinamento | F-01 | Invito da link o QR; comprensibile per chi non è tecnico; nessun gergo da server |
| Home / casa | F-02 | Racconta in un colpo d’occhio: prossimo incontro, umore recente, ultimo disegno |
| Invia un gesto “ti penso” | F-03 | Pochi secondi, frase facoltativa |
| Mood del giorno | F-04 | Sempre facoltativo; “oggi avrei bisogno di…” |
| Disegno a turni | F-05 | Canvas, strumenti semplici, disegno ricevuto, sovra-disegno, messaggio; pensato anche per chi non sa disegnare |
| Countdown | F-06 | Lista e dettaglio con descrizione, todo, immagini, commenti |
| Time capsule | F-07 | Creazione, sigillo, attesa, **cerimonia di apertura** |
| Corkboard | F-08 | Disposizione libera di immagini e disegni |
| Pet e stanza | F-09 | Pose, reazioni, storia delle attività |
| Album, timeline, giorni insieme | F-10, F-11, F-12 | I giorni insieme non sono mai una misura d’impegno |
| Gioco del giorno | F-14 | Un unico modulo coerente, non un pacco di mini-giochi |
| Notifiche e widget | F-13, F-16 | Contenuto generico di default sulla schermata bloccata (S-02) |
| Impostazioni e privacy | F-17, S-03 | Esportazione, cancellazione, interruzione dell’abbinamento con tono dignitoso e non colpevolizzante |
| Personalizzazione | F-18 | Vedi capitolo 8 |
| Stati vuoti, errori, offline, caricamento | tutte | Tono affettuoso, mai allarmante |
| Aggiornamento dell’app | F-19 | Controllo, conferma e avanzamento; il permesso “Installa app sconosciute” va spiegato in modo semplice; schermata di “aggiornamento richiesto” quando il server impone una versione minima, con tono non allarmante |
| Chiave di recupero e nuovo dispositivo | F-20, S-06 | Generazione della chiave all’abbinamento con conferma di avvenuto salvataggio; ripristino su un nuovo telefono; tono rassicurante, mai colpevolizzante |
| Modalità offline | N-03 | Sola lettura: scena e ricordi visibili, azioni di scrittura disattivate con un messaggio gentile (P-02) |

**Momenti da progettare con cura:** primo gesto ricevuto; ritorno dopo giorni di assenza (accoglienza, mai rimprovero); apertura di una time capsule; arrivo del pet nella casa.

## 8. Personaggi e personalizzazione

### 8.1 Il pet

**\[Ipotesi\]** Pet di default: un **cane**, sostituibile dalla coppia con un altro animale. Non muore, non si degrada, non ha bisogni da soddisfare. Reagisce a ciò che la coppia fa (un cuscino nuovo dopo una time capsule, una foto appesa dopo una foto del giorno).

Il pet si esprime con un **set finito di pose**. **\[Ipotesi\]** Un primo set da circa 8 pose: a riposo, attento, contento, curioso, che dorme, che accoglie, che partecipa a un’attività, che festeggia. **Nessuna posa di tristezza, noia o fame legata all’assenza.** Il numero di pose determina il costo per chi vuole sostituire il personaggio, quindi va tenuto basso (vedi A-05).

### 8.2 I due partner

Ogni partner ha un personaggio personalizzabile, senza assunzioni su genere o composizione della coppia. L’aspetto di default è neutro e gradevole.

### 8.3 Personalizzazione (proposta F-18)

**\[Ipotesi\]** La coppia può sostituire gli asset della casa con immagini proprie, create con un assistente AI scelto da loro. Esempi: aggiungere un dettaglio al cane, cambiare animale, ridisegnare i personaggi dei partner. **L’app non offre né integra alcun servizio AI** (N-06): fornisce un kit, riceve un’immagine.

Flusso in quattro passi, da progettare come esperienza guidata e comprensibile per chi non è tecnico:

1. **Scarica il kit** dello slot scelto: immagine attuale, scheda tecnica, prompt suggeriti, riferimenti di stile.
2. **Usa il tuo assistente AI** con il kit e i tuoi dettagli (i prompt hanno segnaposto da completare).
3. **Carica** l’immagine risultante.
4. **Anteprima nella casa** e conferma; è sempre possibile ripristinare l’originale.

L’app verifica che l’immagine rispetti formato, dimensioni e trasparenza, con messaggi in linguaggio semplice. Il designer progetta anche cosa succede se l’immagine non è conforme (**DD-08**).

## 9. Sistema di asset generati con l’AI

Tutti gli asset visivi (pet, avatar, oggetti, sfondi) saranno **generati con strumenti AI**, non disegnati a mano né in vettoriale. Il designer non consegna file sorgente di un programma di grafica: consegna **immagini PNG/JPG e le istruzioni per riprodurle**.

- **A-01 Formati.** PNG con trasparenza per oggetti, personaggi e accessori. JPG ammesso solo per sfondi e fotografie opache.
- **A-02 Master e derivati.** Il designer consegna immagini master ad alta risoluzione e le specifiche di ridimensionamento. I derivati per le varie densità di schermo sono prodotti dagli sviluppatori tramite pipeline (**DD-10** per risoluzioni e budget di peso).
- **A-03 Style Bible.** Documento che rende riproducibile lo stile: immagini di riferimento, palette, tratto, illuminazione, prompt base, prompt negativi, e quale strumento ha prodotto i master. Indipendente da un modello specifico.
- **A-04 Trasparenza pulita.** Bordi senza aloni, ritaglio con margine definito, verifica su sfondo chiaro e scuro. Se lo strumento non produce trasparenza reale, il flusso prevede sfondo uniforme e rimozione dello sfondo, e il criterio di accettazione resta lo stesso.
- **A-05 Coerenza.** Le varianti di uno stesso personaggio (le pose del pet) devono sembrare lo stesso soggetto. Serve un *character sheet* di riferimento e un test affiancato in accettazione.
- **A-06 Niente testo né marchi.** Nessun testo incorporato, logo, marchio o personaggio protetto negli asset (il testo è localizzato dall’app).
- **A-07 Catalogo.** Ogni asset ha: ID, nome, tipo, slot, dimensioni master, formato, prompt completo, riferimenti usati, versione, stato di approvazione.
- **A-08 Licenza.** I termini d’uso dello strumento di generazione devono consentire la redistribuzione degli asset in un progetto open source. Il designer registra strumento e termini; **\[Aperto\] DD-06**.
- **A-09 Slot.** Ogni oggetto sostituibile occupa uno *slot*. Il designer consegna la **tabella degli slot** con: ID slot, descrizione, ancoraggio nella scena, dimensione, trasparenza richiesta, ordine di sovrapposizione, se è sostituibile.

## 10. Voce e microcopy

- **V-10** Prima persona plurale (“la nostra casa”), tono affettuoso, breve, mai pressante.
- **V-11** Mai senso di dovere: “puoi lasciare qualcosa”, mai “devi dimostrare qualcosa” (P-02).
- **V-12** Italiano e inglese pensati ciascuno per sé, non tradotti meccanicamente; le stringhe devono reggere lunghezze diverse.

| Sì | No |
| :-- | :-- |
| “Ti ho lasciato un disegno.” | “Non rispondi da due giorni!” |
| “Hai un pensiero in arrivo.” (notifica generica) | Contenuti intimi sulla schermata bloccata |
| “Bentornato, la casa ti aspettava.” | “Hai perso la tua serie di giorni.” |
| “Se ti va, racconta com’è andata.” | “Spiega perché ti senti così.” |

## 11. Movimento, suono, aptica

**\[Ipotesi\]** Movimenti brevi e delicati; la luce che si accende come gesto ricorrente; aptica leggera; suoni disattivati di default (**DD-09**). Nessuna animazione che insista per richiamare l’attenzione. Rispetto di “riduci movimento”.

**Animazione.** **\[Deciso\]** Si parte dal **livello 1**: trasformazioni, opacità e dissolvenze su livelli di immagine, anche con più livelli sovrapposti per slot (ad esempio ombre, riflessi di luce, particelle, accessori). Il manifest della scena descrive le animazioni per slot (tipo, durata, curva, ripetizione). Gli asset che il designer prevede di animare vanno consegnati in **parti separate** quando serve (ad esempio testa e coda). **Obiettivo finale: livello 3**, animazione scheletrica o a parti 2D, con strumento e formato ancora da scegliere (**DD-11**). Il design non deve rendere difficile il passaggio dal livello 1 al livello 3.

## 12. Vincoli

- Deliverable **indipendenti dallo stack** (D-06 non è deciso): token di design in JSON, immagini PNG/JPG, documenti testuali.
- Android e iOS entrambi cittadini di prima classe; tema chiaro e scuro; widget in formati piccoli (F-13).
- **Font con licenza aperta** (es. OFL) e inclusi nell’app: nessuna dipendenza da servizi esterni per font o immagini (N-06).
- Nessuno spazio per pubblicità o elementi di tracciamento (S-07).
- Notifiche con contenuto generico di default (S-02).
- Le immagini caricate dagli utenti sono contenuti privati e vanno trattate come tali (S-01).

## 13. Fasi e deliverable

Ogni fase termina con un’approvazione del promotore prima di procedere.

| Fase | Deliverable | Gate |
| :-- | :-- | :-- |
| **DS-1 Discovery visiva** | Analisi degli anti-riferimenti, **3 direzioni** di moodboard, proposte di logo e nome | Il promotore sceglie una direzione |
| **DS-2 Pilota** | Style Bible, **kit pilota** (alcune pose del pet, due oggetti, un avatar) e prova completa di **sostituzione con un assistente AI esterno** | Il pilota dimostra coerenza stilistica e fattibilità del flusso di personalizzazione |
| **DS-3 Design system** | Token (colori chiaro/scuro, tipografia, spaziature, raggi, ombre, movimento), iconografia, componenti, linee guida di microcopy | Approvazione del sistema |
| **DS-4 Schermate** | Schermate e stati chiave: prima il nucleo (F-01 – F-07), poi il resto | Approvazione per gruppi di funzioni |
| **DS-5 Catalogo asset** | Catalogo completo, tabella slot, guida di personalizzazione | Approvazione del catalogo |
| **DS-6 Handoff** | Documentazione per gli sviluppatori, checklist di QA visivo | Consegna |

**Regola:** non si producono tutti gli asset prima del gate DS-2.

## 14. Criteri di accettazione

- Ogni scelta di design cita i principi o le funzioni da cui discende.
- Nessun elemento viola P-02, P-03 o V-08.
- Gli asset di una famiglia superano il test di coerenza (A-05) e il test di trasparenza su sfondo chiaro e scuro (A-04).
- Un asset può essere **rigenerato e sostituito** da un’altra persona seguendo solo la Style Bible e il catalogo.
- Un partner non tecnico completa l’abbinamento e invia un “ti penso” senza istruzioni.
- Le schermate funzionano in tema chiaro e scuro, in italiano e in inglese, con testo ingrandito.

## 15. Decisioni aperte

Il designer non le risolve: le segnala, proponendo alternative con pro e contro.

| ID | Questione |
| :-- | :-- |
| **DD-01** | Nome definitivo e naming dei concetti interni |
| **DD-02** | Stile illustrativo e moodboard di riferimento |
| **DD-03** | Specie di default del pet e set definitivo di pose |
| **DD-04** | Casa come scena unica o più stanze; navigazione accessibile oltre la scena |
| **DD-05** | Granularità della personalizzazione: sostituire l’intero set di pose o aggiungere accessori come livelli sovrapposti con punti di ancoraggio |
| **DD-06** | Strumento di generazione e termini di licenza per asset in un progetto open source |
| **DD-07** | Le personalizzazioni sono visibili a entrambi i partner o solo a chi le crea? |
| **DD-08** | Gestione di un’immagine caricata non conforme: rifiuto con spiegazione, adattamento automatico, altro |
| **DD-09** | Presenza e ruolo di suoni |
| **DD-10** | Risoluzioni master e budget di peso per asset e per app |
| DD-11 | Strumento e formato per l’animazione di livello 3 (scheletrica o a parti 2D): deve poter essere prodotto da agenti, non solo da un editor manuale, e restare compatibile con asset generati con l’AI |

## 16. Tracciabilità

Ogni deliverable del designer cita gli ID di questo brief (V-xx, A-xx, DD-xx) e del Project Brief (P-xx, F-xx, S-xx, N-xx) da cui discende. In caso di conflitto con un principio P-xx, vince il principio e il conflitto viene segnalato al promotore.
