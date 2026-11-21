# Contratto dei micro-pacchetti di contenuti firmati (`S2-CTR-01`)

**Versione:** 1.0 · **Data:** 21 novembre 2026 · **Riferimenti:** `AR-09`, `TC-08`, `TC-10`, `G5-07`, `CNT-01`, `DD-10`, `PD-19`, `AD-06`

Questo documento definisce il contratto tra pipeline di pubblicazione (`scripts/`), server (`com.vectevo.deep_sky_server.content`) e client Flutter (`ContentPackService`) per la distribuzione sicura e incrementale dei pacchetti grafici della Casa.

---

## 1. Principi e modello di fiducia (`G5-07`)

- **Ancora di fiducia crittografica sul client:** il client incorpora una mappa immutabile di chiavi pubbliche **Ed25519** indicizzate per `keyId` (es. `{"v1": "<base64-spki-o-raw-32B>"}`).
- **Verifica sul server come difesa operativa aggiuntiva:** il server valida la firma (se sono configurate chiavi pubbliche fidate), l'integrità SHA-256 di tutti i file e la sicurezza dei percorsi all'avvio/ricarica del volume `pack_data`, rifiutando di servire pacchetti corrotti o manomessi; tuttavia la sicurezza verso il dispositivo dipende esclusivamente dalla verifica svolta dal client.
- **Nessun archivio `.zip`/`.tar`:** distribuzione **file per file** guidata da `pack-checksums.json`, così il client scarica solo i file nuovi o modificati (micro-pacchetti `v1.0.0 -> v1.1.0 -> v1.2.0` senza ridownload del pavimento o della finestra invariati).

---

## 2. Formato di `pack-checksums.json` e `pack-checksums.json.sig`

### 2.1 `pack-checksums.json`

```json
{
  "schemaVersion": 1,
  "keyId": "v1",
  "packId": "deep-sky-home-v1",
  "packVersion": "1.0.0",
  "minAppProtocol": 1,
  "files": {
    "manifest.json": {
      "sha256": "<64-hex-lowercase>",
      "sizeBytes": 1824
    },
    "assets/floor.png": {
      "sha256": "<64-hex-lowercase>",
      "sizeBytes": 195420
    }
  }
}
```

Vincoli sui campi:
- `schemaVersion`: intero `>= 1`.
- `keyId`: stringa `^[a-z0-9][a-z0-9_-]{0,31}$` che identifica la chiave pubblica Ed25519 usata per firmare il file.
- `packId`: identificatore del pacchetto, deve coincidere con `manifest.json`.
- `packVersion`: semver `MAJOR.MINOR.PATCH` (`0|[1-9]\d*`).
- `minAppProtocol`: intero `>= 1`; il client rifiuta pacchetti con `minAppProtocol > appProtocolVersion`.
- `files`: mappa `relativePath -> { sha256, sizeBytes }`. Deve sempre includere `manifest.json`. Ogni `relativePath` deve essere relativo, usare `/`, non contenere `..`, `\`, prefissi `/` o caratteri di controllo.

### 2.2 `pack-checksums.json.sig`

Per rispettare rigorosamente `G5-07` (**verifica della firma Ed25519 sui byte grezzi prima di qualsiasi parsing JSON**), il file `.sig` trasporta il `keyId` fuori dal JSON nel formato testuale a una riga:

```text
<keyId>:<base64-signature-64-bytes>
```

Esempio:
```text
v1:9f3b...==
```

Regole di verifica sul client (ordine obbligatorio):
1. Leggere i byte grezzi di `pack-checksums.json` e il contenuto di `pack-checksums.json.sig`.
2. Estrarre `keyId` e i 64 byte di firma da `.sig` (formato `keyId:base64`; in assenza del prefisso `keyId:` solo per retrocompatibilità di test si assume `v1` se e solo se i byte decodificati sono esattamente 64).
3. Cercare `trustedKeys[keyId]`. Se `keyId` è sconosciuto → **rifiuto immediato** (`unknownKeyId`), senza chiamare `jsonDecode`.
4. Verificare la firma Ed25519 sui **byte grezzi** di `pack-checksums.json`. Se non valida → **rifiuto immediato** (`signatureInvalid`), senza chiamare `jsonDecode`.
5. Solo dopo firma valida, eseguire `jsonDecode` su `pack-checksums.json` e verificare che `payload.keyId == sigKeyId` (impedisce sostituzioni di `keyId` tra busta e payload).

---

## 3. API HTTP di distribuzione (`S2-SRV-01`)

Tutti gli endpoint sono serviti sotto `/api/v1/content/pack` in sola lettura (`GET`) e sono integrati con `GET /api/v1/system/compatibility`:

| Endpoint | Risposta | Caching HTTP |
| :-- | :-- | :-- |
| `GET /api/v1/system/compatibility` | `{ minClientVersionCode, minProtocolVersion, minPackVersion }` | Nessuna cache forte |
| `GET /api/v1/content/pack/checksums` | Byte grezzi di `pack-checksums.json` (`application/json`) | `ETag: "<sha256>"`, `Cache-Control: no-cache`, supporto `If-None-Match` -> `304` |
| `GET /api/v1/content/pack/checksums.sig` | Byte grezzi di `pack-checksums.json.sig` (`text/plain; charset=utf-8`) | `ETag: "<sha256>"`, `Cache-Control: no-cache`, supporto `If-None-Match` -> `304` |
| `GET /api/v1/content/pack/files/{*relativePath}` | Byte grezzi del file asset (`image/png`, `image/jpeg`, `application/json`) | `ETag: "<file-sha256>"`, `Cache-Control: public, max-age=31536000, immutable`, `Content-Length` rigoroso, supporto `If-None-Match` -> `304` |

Sicurezza server:
- Qualsiasi path non presente nella whitelist `files` del `pack-checksums.json` attivo o contenente `..` / `\` / symlink esterni restituisce `400` o `404`.
- Se sul server non è presente alcun pacchetto valido (o la verifica difensiva all'avvio fallisce), gli endpoint `/api/v1/content/pack/**` rispondono `404 Not Found` e il client continua a usare il pacchetto incorporato nell'APK senza errori bloccanti.

---

## 4. Protezione anti-downgrade persistente (`AD-06`, `PD-19`)

Poiché Android ha `allowBackup="false"` (`AD-06`), dopo una reinstallazione la memoria locale `localMaxSeenPackVersion` riparte da zero. Per impedire downgrade silenziosi anche dopo una reinstallazione, la versione minima accettabile è sempre:

```text
minAcceptablePackVersion = max(
    bundledPackVersion,       // es. "1.0.0" compilata nell'APK
    localMaxSeenPackVersion,  // massima versione valida mai attivata localmente
    serverMinPackVersion      // esposta da GET /api/v1/system/compatibility
)
```

Un pacchetto con `packVersion < minAcceptablePackVersion` viene sempre rifiutato (`downgradeRejected`).

---

## 5. Modalità di aggiornamento, staging e rollback "ultimo pacchetto funzionante"

### 5.1 Struttura su disco locale (app-private storage)
- `content_packs/blobs/<sha256>`: cache content-addressed dei singoli file già verificati (per evitare di riscaricare file invariati tra `v1.0.0`, `v1.1.0` e `v1.2.0`).
- `content_packs/staged/<packVersion>/`: pacchetto completamente verificato (firma + SHA-256 + `SceneManifestParser`), pronto per promozione.
- `content_packs/active/<packVersion>/`: pacchetto attivo.
- `content_packs/previous/<packVersion>/`: ultimo pacchetto funzionante precedente.
- Metadati in `SecureKeyStore` / file locale (`activeVersion`, `previousVersion`, `stagedVersion`, `maxSeenVersion`, `etag`, `packBootAttempts`).

### 5.2 Due modalità di aggiornamento
1. **Automatico in background (`syncSilently`):**
   - Eseguito solo su rete **non a consumo** (Wi-Fi di default tramite `ConnectivityManager.isActiveNetworkMetered == false`).
   - Usa `If-None-Match` su `/checksums`; se cambia, scarica solo i file con SHA-256 mancante nella cache locale `blobs/`, assembla in `staged/<packVersion>/` e **non sostituisce la UI in corsa**: verrà promosso ad `active` al prossimo avvio.
2. **Pulsante manuale "Aggiorna grafiche" in Impostazioni (`forceUpdateAndReloadNow`, `S2-D09`):**
   - Ignora il vincolo rete non a consumo e forza il controllo anche su rete mobile.
   - Scarica i file nuovi, valida firma e hash, promuove subito `staged -> active` (salvando il precedente in `previous`), **evict delle texture del pacchetto precedente da `PaintingBinding.instance.imageCache`** e ricarica immediatamente `SceneManifest` nella UI senza chiudere l'app.

### 5.3 Rollback automatico "ultimo pacchetto funzionante"
- All'avvio dell'app, prima di caricare un pacchetto esterno `active`:
  - se esiste uno `staged` valido, viene promosso ad `active` (spostando il vecchio `active` in `previous`) e `packBootAttempts` viene azzerato a `0`;
  - poi `packBootAttempts` viene incrementato (`+= 1`) e salvato prima del rendering della Home.
- Quando la Home completa con successo il primo frame (`WidgetsBinding.instance.addPostFrameCallback`), il controller chiama `markHomeBootSucceeded()` che azzera `packBootAttempts = 0`.
- Se al boot successivo `packBootAttempts >= 2` (la Home è andata in crash o non ha mai completato il primo frame per 2 avvii consecutivi), il client esegue rollback automatico:
  - ripristina `previous` se presente e valido, altrimenti torna al pacchetto incorporato nell'APK (`bundled`);
  - registra il pacchetto difettoso (`blockedVersion`) per non ripromuoverlo automaticamente finché non arriva una versione più recente.
