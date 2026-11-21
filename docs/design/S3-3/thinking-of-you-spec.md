# Design Specifica Anticipata — S3-3: Thinking of You e Notifiche (`S2-D10`, `S2-DES-03`)

**Versione:** 0.1 (bozza per approvazione promotore prima della chiusura di `S3-2`) · **Data:** 21 novembre 2026
**Riferimenti:** `F-03`, `F-16`, `P-01`, `P-02`, `P-03`, `P-07`, `S-02`, `V-06`, `V-07`, `V-08`, `V-10..V-12`, `CA-15`

---

## 1. Obiettivo emotivo

Inviare un *“Ti penso”* deve richiedere **meno di 3 secondi** (`P-01`) e arrivare come una luce gentile lasciata accesa nella stanza, mai come una notifica urgente o un messaggio che esige risposta (`P-02`, `P-03`, `V-08`).

---

## 2. Flussi e stati (`F-03`)

### 2.1 Invio rapido dalla Home o dalla lampada da terra
- **Trigger:** pulsante **`♥ Ti penso`** nella card superiore oppure tocco diretto sullo slot `floor_lamp` nella scena (`DD-04`).
- **Foglio leggero opzionale (*bottom sheet*):**
  - **Tocco singolo su `♥ Ti penso`:** invia immediatamente il pensiero (con eventuale nota breve inserita nel campo rapido, max 140 caratteri).
  - **Tocco sulla lampada (`floor_lamp`):** apre un bottom sheet morbido con:
    - titolo: *“Lascia una piccola luce accesa”* / *“Leave a gentle light on”*;
    - 3 spunti facoltativi monotoque (*“Ti penso adesso”*, *“Spero vada bene la giornata”*, *“Vorrei abbracciarti”* — mai obbligatori);
    - campo testo libero facoltativo (max 140 caratteri);
    - pulsante primario **`♥ Invia pensiero`** (`minHeight: 48dp`).
- **Stato offline (`N-03`):** pulsante disattivato con copia calma (*“Sei offline · Riprova appena torna la connessione”*).
- **Stato invio / conferma:** la card superiore passa temporaneamente a un banner di conferma *“Pensiero inviato”* / *“Thought sent”* (che sostituisce il compositore *“Lascia un pensiero”* per ~8 secondi, con anteprima della nota inviata e pulsante discreto per chiudere subito), accompagnato da animazione breve di espansione dell'alone ambra della lampada (`400 ms`, disattivata se *Riduci movimento* è attivo) + aptica leggera **“vibrazione sul cuore”** (`HapticFeedback.lightImpact()` + pausa `120 ms` + `HapticFeedback.selectionClick()`, rispettando le preferenze aptiche di sistema).

### 2.2 Ricezione e stato `< 6h`
- Quando arriva un *Ti penso* dal partner (e non è ancora stato visto localmente `seq > lastSeenEventSeq` e `< 6h`):
  - La lampada da terra passa allo stato **`lit`** (`floor_lamp_lit.png` + `RadialGradient` ambra/rosa sul muro-sfondo).
  - La card superiore mostra **`"<Partner> ti ha pensato"`** (con nota facoltativa del partner), un campo facoltativo per rispondere con un breve messaggio e il pulsante **`♥ Ricambia`**. Inviando la risposta, il pensiero ricevuto viene segnato visto localmente e la card mostra brevemente il banner *“Pensiero inviato”*.
- **Regola di non-obbligo (`P-02`, `P-07`):** nessuna conferma di lettura viene inviata al server quando il destinatario apre la Home o ignora la card. Dopo 6 ore la lampada torna silenziosamente allo stato `calm` (luce soffusa, mai spenta).

---

## 3. Notifiche discrete e impostazioni di quiete (`F-16`, `S-02`, `CA-15`)

### 3.1 Payload e testi generici di default (schermata bloccata sicura `S-02`)
Il server invia solo un risveglio data-only (`{ "l10nKey": "wakeup.thinking_of_you", "event": "thinking_of_you", "ts": ... }`, mai nomi né note in chiaro). L'app compone la notifica localmente sul dispositivo:

| Chiave `l10nKey` | Titolo IT | Corpo IT | Titolo EN | Corpo EN |
| :-- | :-- | :-- | :-- | :-- |
| `wakeup.thinking_of_you` | `Deep Sky` | `C'è una luce accesa nella vostra casa.` | `Deep Sky` | `A gentle light is on in your home.` |
| `wakeup.pairing_request` | `Deep Sky` | `Una richiesta di collegamento attende la tua conferma.` | `Deep Sky` | `A pairing request is waiting for your confirmation.` |

### 3.2 Canale Android & Ore di quiete
- **Canale Android:** `deep_sky_gentle_gestures` (*“Gesti gentili”* / *“Gentle gestures”*), importanza `IMPORTANCE_DEFAULT`, badge numerico disattivato (`setShowBadge(false)` per `V-08`), vibrazione breve morbida (`[0, 70, 90, 50]`), suono di sistema predefinito silenzioso/delicato personalizzabile dall'utente nelle impostazioni Android.
- **Ore di quiete (locale al dispositivo, opzionale in `Impostazioni`):**
  - Interruttore *“Ore di quiete”* / *“Quiet hours”* (default disattivato, orario suggerito `22:30 – 07:30`).
  - Durante le ore di quiete i risvegli push non producono suono né vibrazione, ma l'evento E2EE resta normalmente visibile aprendo la Casa (`P-08`).
- **Tocco sulla notifica:** apre direttamente la tab `Casa` con la card *“\<Partner\> ti ha pensato”* e la lampada accesa.
