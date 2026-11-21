# Server Configuration Reference

**Reference IDs:** `SRV-03`, `INF-04`, `TC-02`, `TC-10`, `TC-13`

All configuration is supplied via environment variables (or Docker secrets mapped into environment/property files). The server validates required production settings at startup and fails fast with explicit diagnostic messages.

## Parameters

| Property (`deepsky.*`) | Environment Variable | Default (`dev` / base) | Required in `prod` | Description |
| :-- | :-- | :-- | :-- | :-- |
| `deepsky.domain` | `DEEPSKY_DOMAIN` | `localhost` | Yes | Public domain of the instance (e.g. `deepsky.vectevo.com`) |
| `deepsky.admin-secret` | `DEEPSKY_ADMIN_SECRET` | `dev-admin-secret-change-me` (dev only) | Yes (>= 24 chars, non-default) | Admin secret for self-hoster operational endpoints |
| `deepsky.protocol.min-client-version-code` | `DEEPSKY_MIN_CLIENT_VERSION_CODE` | `1` | No (`1`) | Minimum Android `versionCode` allowed by the server (`F-19`, `N-10`) |
| `deepsky.protocol.min-protocol-version` | `DEEPSKY_MIN_PROTOCOL_VERSION` | `1` | No (`1`) | Minimum E2EE/snapshot protocol version (`TC-05`, `8.2`) |
| `deepsky.quotas.max-blob-bytes` | `DEEPSKY_MAX_BLOB_BYTES` | `10485760` (10 MiB) | No | Maximum single encrypted blob upload size |
| `deepsky.quotas.max-couple-storage-bytes` | `DEEPSKY_MAX_COUPLE_STORAGE_BYTES` | `1073741824` (1 GiB) | No | Total encrypted blob storage quota per couple |
| `deepsky.content.packs-dir` | `DEEPSKY_CONTENT_PACKS_DIR` | `""` (compose: `/var/lib/deepsky/packs`, volume `pack_data`) | No | Directory dei micro-pacchetti di contenuti firmati serviti da `/api/v1/content/pack/**` |
| `deepsky.content.min-pack-version` | `DEEPSKY_MIN_PACK_VERSION` | `1.0.0` | No | Versione minima del pacchetto esposta in `GET /api/v1/system/compatibility` (anti-downgrade, `AD-06`) |
| `deepsky.content.trusted-public-keys.v1` / `.v2` | `DEEPSKY_CONTENT_TRUSTED_KEY_V1` / `DEEPSKY_CONTENT_TRUSTED_KEY_V2` | `""` (verifica firma disattivata) | Consigliato | Chiavi pubbliche Ed25519 (base64, 32 byte raw o SPKI 44 byte) per `keyId`. Se almeno una è impostata il server verifica la firma di `pack-checksums.json` e rifiuta `keyId` sconosciuti. Se è configurata la directory dei pacchetti ma nessuna chiave, il server logga un `WARN` all'avvio (resta attiva solo la verifica SHA-256/path; l'ancora di fiducia è comunque il client) |
| `deepsky.firebase.enabled` | `DEEPSKY_FIREBASE_ENABLED` | `false` | No (`false`) | Enables FCM push delivery and runtime client config endpoint (`TC-13`) |
| `deepsky.firebase.project-id` | `DEEPSKY_FIREBASE_PROJECT_ID` | `""` | If `firebase.enabled=true` | Firebase project ID sent to clients at pairing |
| `deepsky.firebase.api-key` | `DEEPSKY_FIREBASE_API_KEY` | `""` | If `firebase.enabled=true` | Firebase Web/Android API key sent to clients at pairing |
| `deepsky.firebase.app-id` | `DEEPSKY_FIREBASE_APP_ID` | `""` | If `firebase.enabled=true` | Firebase Android App ID (`1:...:android:...`) |
| `deepsky.firebase.sender-id` | `DEEPSKY_FIREBASE_SENDER_ID` | `""` | If `firebase.enabled=true` | Firebase Cloud Messaging sender ID |
| `deepsky.firebase.service-account-file` | `DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE` | `""` | If `firebase.enabled=true` | Filesystem path to mounted Firebase service account JSON (never in repo) |

## Database & Spring Profiles

| Variable | Description |
| :-- | :-- |
| `SPRING_PROFILES_ACTIVE` | `dev` (local development) or `prod` (containerized deployment) |
| `SPRING_DATASOURCE_URL` | JDBC URL (e.g. `jdbc:postgresql://db:5432/deepsky`) |
| `SPRING_DATASOURCE_USERNAME` | PostgreSQL user |
| `SPRING_DATASOURCE_PASSWORD` | PostgreSQL password (or injected via `/run/secrets/db_password`) |
| `JAVA_TOOL_OPTIONS` | JVM heap/memory flags (e.g. `-XX:MaxRAMPercentage=70.0 -XX:+ExitOnOutOfMemoryError`) |

## Reverse Proxy & Rate-Limiting (`CA-12`)

- The Spring Boot API sets `server.forward-headers-strategy: native` so Tomcat's `RemoteIpValve` resolves `request.getRemoteAddr()` from `X-Forwarded-For` **only** when the direct TCP connection comes from a trusted private/loopback proxy (`internal-proxies`), ignoring forged `X-Forwarded-For` headers from untrusted peers.
- In `deploy/docker-compose.yml`, only Caddy (`proxy`) publishes ports `80`/`443`, while `api` listens exclusively on the Docker `internal` network. Self-hosters must **not** expose `api:8080` directly to untrusted networks or disable proxy header sanitization.

## Startup Validation Behavior (`SRV-03`)

- In `prod` profile, `DEEPSKY_DOMAIN` cannot be `localhost` or blank, and `DEEPSKY_ADMIN_SECRET` must be at least 24 characters and must not equal the dev placeholder.
- Whenever `DEEPSKY_FIREBASE_ENABLED=true`, all five Firebase fields (`project-id`, `api-key`, `app-id`, `sender-id`, `service-account-file`) must be non-blank, and `service-account-file` must point to a readable file. See [Firebase Setup Guide](firebase-setup.md) for step-by-step setup without `google-services.json`.
- Quotas (`max-blob-bytes`, `max-couple-storage-bytes`) and protocol versions must be strictly positive, and `max-couple-storage-bytes >= max-blob-bytes`.

## Pubblicazione dei pacchetti di contenuti (`S2-SRV-01`, `TC-10`)

Il server serve il pacchetto attivo letto dal volume Docker `pack_data` (montato in `/var/lib/deepsky/packs` nel container `api`). La directory può contenere direttamente i file del pacchetto oppure una sottodirectory `current/`. Struttura attesa:

```text
pack-checksums.json
pack-checksums.json.sig
manifest.json
assets/*.png
```

Procedura di pubblicazione di una nuova versione (es. `v1.1.0`):

1. Genera e firma il pacchetto in locale (`scripts/build_content_pack.py`, `scripts/sign_content.py`, `scripts/validate_content.py`); la chiave privata di firma non lascia mai la macchina del promotore.
2. Copia **tutti** i file nel volume, ad esempio da un host con accesso al progetto Compose:
   ```bash
   docker compose cp ./pack-v1.1.0/. api:/var/lib/deepsky/packs/current/
   ```
   Pubblica `pack-checksums.json` e `pack-checksums.json.sig` **per ultimi**: il server rileva la modifica di questi due file.
3. Entro 60 secondi il server ricarica il pacchetto (`@Scheduled`, intervallo configurabile con `deepsky.content.reload-interval`, formato `PT60S`), lo verifica (firma se sono configurate le chiavi, SHA-256, dimensioni, path) e inizia a servirlo. Se la verifica fallisce resta servito l'ultimo pacchetto valido e il motivo compare nel log (`Rejected content pack ...`). Non è necessario riavviare il container; in caso di dubbio `docker compose restart api` forza un ricaricamento.
4. Controlla: `curl -s https://<dominio>/api/v1/content/pack/checksums` e, per un file, `curl -I https://<dominio>/api/v1/content/pack/blobs/<sha256>`.

Aumenta `DEEPSKY_MIN_PACK_VERSION` solo per escludere versioni vecchie (anti-downgrade); i client scaricano i file da `/api/v1/content/pack/blobs/<sha256>` (immutabile) e rivalidano i percorsi `/files/**` con `ETag`.
