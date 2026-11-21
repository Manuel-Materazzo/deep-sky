# Contratto di separazione stato locale e snapshot condiviso (`S2-CTR-02`)

**Versione:** 1.0 · **Data:** 21 novembre 2026 · **Riferimenti:** `AR-03`, `AR-07`, `TC-05`, `P-02`, `P-03`, `P-07`, `S-05`, `F-02`, `PD-19`

Questo documento formalizza il confine tra ciò che appartiene allo stato condiviso della coppia (sincronizzato in E2EE) e ciò che deve restare **esclusivamente locale al singolo dispositivo**.

---

## 1. `CoupleRoomSnapshot` (condiviso, cifrato E2EE, `schemaVersion = 1`)

Contiene esclusivamente artefatti e stati oggettivi condivisi della coppia, derivabili in modo deterministico dal log di buste cifrate (`EncryptedEnvelope`):

```json
{
  "schemaVersion": 1,
  "coupleId": "<uuid>",
  "lastEventSeq": 42,
  "latestThought": {
    "envelopeId": "<uuid>",
    "seq": 42,
    "authorDeviceId": "<uuid>",
    "createdAtUtc": "2026-11-21T17:30:00Z",
    "note": "Un caffè insieme?"
  }
}
```

**Campi esplicitamente vietati (`P-02`, `P-07`, `S-05`):**
- Nessun `lastSeenEventSeq`, `readAt`, `seenByDeviceId` o conferma di lettura.
- Nessun `lastOpenedAt`, `lastActiveAt` o indicatore di presenza online.
- Nessun contatore di assenza, inattività, streak o frequenza di invio.
- Nessuna coordinata GPS, città o dato meteo.

---

## 2. `LocalSceneViewState` (strettamente locale, mai sincronizzato)

Persistito esclusivamente nello storage sicuro locale del dispositivo (`SecureKeyStore`, escluso dal backup Android `AD-06`) e **mai** incluso in buste, snapshot o chiamate HTTP verso il server:

| Campo | Tipo | Scopo |
| :-- | :-- | :-- |
| `lastSeenEventSeq` | `int` (default `0`) | Ultimo `seq` di evento visto/ricambiato localmente sul telefono. Usato insieme al timestamp per decidere se la card *Ti penso* mostra il banner `"<Partner> ti ha pensato"` + `♥ Ricambia` e se `floor_lamp` è in stato `lit`. |
| `lastSeenThoughtEnvelopeId` | `String?` | Fallback per eventi locali o senza `seq` assegnato (es. compatibilità test / `n-1`). |
| `lastOpenedAtLocal` | `DateTime?` (UTC ISO-8601) | Istante locale della precedente apertura della Home. Se trascorrono `>= 72 ore` (`3 giorni`) dall'ultima apertura, la Home mostra un messaggio calmo di bentornato (*"Bentornato, la casa ti aspettava"* / *"Welcome back, home was waiting for you"*), senza mai mostrare conteggi di giorni o salvare contatori di inattività (`P-02`, `P-03`). |
| `skyPreference` | `enum { auto, day, night }` | Preferenza locale dell'atmosfera/cielo della casa (`Auto` segue l'orologio locale; `Giorno` e `Notte` forzano la relativa fascia e il tema coerente). |

### Regola della finestra di 6 ore per il banner *Ti penso* e la lampada (`F-03`, `S2-APP-03`)

Un pensiero ricevuto dal partner (`latestThought.authorDeviceId != localDeviceId`) è considerato **attivo e non ancora visto** se e solo se:
1. `nowUtc.difference(latestThought.createdAtClient) < Duration(hours: 6)` (e non nel futuro anomalo), **E**
2. non è già stato marcato come visto localmente:
   - se `latestThought.seq != null`: `latestThought.seq! > localState.lastSeenEventSeq`;
   - altrimenti: `latestThought.envelopeId != localState.lastSeenThoughtEnvelopeId`.

Quando tale condizione è vera:
- La card superiore *Ti penso* mostra lo stato **Ricevuto** (`"<Partner> ti ha pensato"`, tempo relativo, nota facoltativa e pulsante `♥ Ricambia`).
- Lo slot `floor_lamp` (dal micro-pacchetto `v1.1.0`) entra nello stato `lit` con alone ambra caldo sul muro-sfondo.

Quando il partner tocca **`♥ Ricambia`** (o segna come letto/invia una risposta), il dispositivo aggiorna solo il proprio `LocalSceneViewState.lastSeenEventSeq` localmente senza inviare alcuna conferma di lettura al server (`P-07`, `S-05`).

---

## 3. Fasce orarie locali fisse per cielo e muro-sfondo (`S-05`)

Per non richiedere mai posizione GPS né API meteo di terze parti (`S-05`, `N-06`), il cielo della finestra (`window`) e la tinta del muro-sfondo sono calcolati dall'orologio locale del dispositivo (`DateTime.now()`):

| Fascia (`SkyPeriod`) | Orario locale (`hour`) | Stato slot `window` | Asset cielo |
| :-- | :-- | :-- | :-- |
| `day` (`Giorno`) | `06:00 – 17:59` (`6 <= h < 18`) | `day` | `assets/window_sky_day.png` |
| `twilight` (`Crepuscolo`) | `18:00 – 20:59` (`18 <= h < 21`) | `twilight` | `assets/window_sky_twilight.png` |
| `night` (`Notte`) | `21:00 – 05:59` (`h >= 21 || h < 6`) | `night` | `assets/window_sky_night.png` |

### Passaggio della mezzanotte e cambio fuso orario ad app aperta
- Il controller esegue un timer leggero ogni **60 secondi** (attivo solo quando il controller è montato e cancellato in `dispose()`) e ricalcola immediatamente la fascia anche su `AppLifecycleState.resumed`.
- Poiché `DateTime.now()` legge l'ora locale corrente del sistema operativo, sia il passaggio delle `06:00` / `18:00` / `21:00` / `00:00` sia un cambio di fuso orario del telefono aggiornano automaticamente `SkyPeriod`.
- Al cambio di `SkyPeriod`, l'app esegue `.evict()` esplicito dalla `imageCache` dell'asset cielo uscente così da mantenere in memoria **una sola variante oraria alla volta** (`ADR-0007`).
