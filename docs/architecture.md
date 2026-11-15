# Documento architetturale: Deep Sky

**Versione:** 0.2 (uscita M1 / gate `G-1`) · **Data:** 14 novembre 2026 · **Dipende da:** [Project Brief](project-brief.md) v0.2, [Design Brief](design-brief.md) v0.2, [Considerazioni tecniche](technical-considerations.md) v0.1, [ADR-0001](adr/0001-use-adrs.md)–[ADR-0009](adr/0009-sp05-backend-footprint.md)

**Stato del documento:** esportato e consolidato in `docs/` (chiude `REP-05`) integrando le architetture validate nei cinque prototipi di verifica **M1** (`SP-01`–`SP-05`). Le decisioni di confine di modulo, sicurezza e self-hosting restano soggette a eventuale affinamento durante la promozione in **M2** (`G-2`) e alla revisione indipendente (**`G-5`**).

---

## 1. Contesto e vincoli architetturali

Deep Sky è un’applicazione **Android-first** (`TC-04`, package `com.vectevo.deep_sky`, `PD-07`) per due partner con comunicazione privata **cifrata end-to-end dalla v1** (`TC-05`, `S-01`), interfaccia illustrata data-driven (`TC-08`, `TC-09`), notifiche di risveglio prive di contenuti (`S-02`), aggiornamenti integrati di contenuti e APK (`TC-10`) e backend leggero self-hostabile su VM ARM64/AMD64 tramite Docker Compose (`TC-02`, `TC-03`).

Il monorepo pubblico (`PD-09`) separa nettamente le responsabilità:

- `lib/` e `test/`: client Flutter (`TC-01`), crittografia client-side, cache/archiviazione sicura locale, motore scena ibrida, servizi di sincronizzazione e aggiornamento.
- `android/`: codice nativo Kotlin limitato alle integrazioni di sistema (`MainActivity`, `DeepSkyApplication`, `PlatformBridgePlugin`, `RuntimeFirebaseCoordinator`, `DeepSkyFirebaseMessagingService`, `ApkInstallerCoordinator`, `InstallResultReceiver`, e futuro widget home screen `F-13`).
- `server/`: backend monolito modulare Java 25 + Spring Boot 4 + PostgreSQL 17 + Flyway (`ADR-0002`, `ADR-0004`), con regole architetturali verificate tramite ArchUnit (`ArchitectureTest`).
- `content/`: pacchetti dichiarativi di scena e asset (`content/packs/*`), validati da `scripts/validate_content.py` senza codice eseguibile.
- `deploy/`: configurazione Docker Compose (`deploy/docker-compose.yml`, `deploy/docker-compose.firebase.yml`, `deploy/docker-compose.sp05.yml`), reverse proxy Caddy (`HTTPS` su `deepsky.vectevo.com`, `PD-08`) e modello variabili (`deploy/.env.example`).
- `docs/`: specifica di prodotto, design, ADR e procedure operative. Nessun segreto, certificato privato o credenziale Firebase può risiedere nel repository (`S-02`, `PD-09`, pre-commit secret scan).

---

## 2. Stato delle decisioni architetturali (`AR-01` … `AR-11`)

Questa tabella aggiorna esplicitamente le decisioni architetturali `AR-xx` al termine della milestone **M1** (`G-1`), indicando quali risultano **Confermate**, **Consolidate da prototipo** o **Aperte con fallback**.

| ID | Area architetturale | Stato post-M1 | Decisione consolidata e riferimenti |
| :--- | :--- | :--- | :--- |
| **AR-01** | Backend monolito modulare (`SRV-01`, `TC-02`) | **Confermata** | Monolito modulare Spring Boot 4 / Java 25 con PostgreSQL 17, migrazioni Flyway e confini package applicati via ArchUnit (`ADR-0002`, `ADR-0004`). |
| **AR-02** | Autenticazione per dispositivo (`AD-02`) | **Consolidata da SP-02** | Nessun account pubblico o password: ogni dispositivo genera una coppia **Ed25519** e firma le richieste HTTP (`X-Device-Id`, `X-Signature`, timestamp/nonce anti-replay) verificate da `DeviceAuthFilter` + `Ed25519SignatureVerifier` ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). |
| **AR-03** | Modello dati e sincronizzazione E2EE (`AD-03`, `TC-05`) | **Consolidata da SP-02** | Tre livelli: (1) log append-only di buste cifrate (`EncryptedEnvelope`), (2) snapshot derivati cifrati con controllo ottimistico di `version` / `schemaVersion`, (3) blob binari cifrati. Il server conserva solo ciphertext e metadati minimi ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). |
| **AR-04** | Isolamento logico delle coppie (`AD-05`) | **Confermata (estendibile)** | Schema dati scoped per `couple_id` su dispositivi, consegne chiavi, buste cifrate e registrazioni push; supporta l’uso iniziale mono-coppia e isola più coppie su una singola istanza senza modifiche strutturali. Quote/rate-limit completi in M2. |
| **AR-05** | Protocollo abbinamento, recupero e revoca (`S-01..S-06`, `F-01`, `F-20`) | **Consolidata da SP-02** | `CoupleMasterKey` (`CMK`) a 256 bit incapsulata separatamente per scambio X25519 con verifica SAS, per arruolamento cross-device (`F-20`) e per **Recovery Key** BIP-39 a 24 parole / QR `deepsky-rk:v1:`; AAD canonico su XChaCha20-Poly1305; revoca immediata dispositivo. La chiusura di coppia (`unpairCouple`, `S-03`) imposta `unpaired_at` come soft-close che blocca subito auth dispositivi, inviti e recovery unilaterale (`S-06`); eventuale riattivazione consensuale bilaterale e cancellazione definitiva/esportazione (`F-17`, `S-04`) restano in carico a `M5 Memoria`. Le verifiche su telefoni fisici e con utenti non tecnici proseguono come gate di ingresso dati reali (`PD-05`, M2). |
| **AR-06** | Client Flutter + ponte nativo Android (`APP-01`, `TC-01`, `TC-04`) | **Confermata** | Unica UI Flutter (`minSdk`/`targetSdk` in `ADR-0003`) e canale nativo isolato (`PlatformBridgePlugin.kt`, `native_bridge.dart`) per installer APK, inizializzazione runtime FCM, keystore e futuri widget Android. |
| **AR-07** | Composizione della Home ibrida (`V-07..V-10`, `TC-08`) | **Confermata da SP-04** | `HybridSceneCanvas` con `SceneManifest`, proporzione fissa della scena e fondale con bleed (`bg_day`/`bg_night`), aree di tocco normalizzate esplicite, semantica TalkBack ordinata (`OrdinalSortKey`) e card UI solide in regioni verticali non sovrapposte allo spazio animato ([ADR-0007](adr/0007-sp04-hybrid-home-scene.md)). |
| **AR-08** | Animazioni livello 1 e override non distruttivi (`TC-09`, `F-18`) | **Confermata da SP-04** | Livelli animati isolati con `RepaintBoundary`, arresto immediato su `reduceMotion` / `disableAnimations`, e personalizzazione esterna tramite `AssetOverrideRegistry` (`slotId:layerId`) senza mutare i manifest firmati ([ADR-0007](adr/0007-sp04-hybrid-home-scene.md)). |
| **AR-09** | Pacchetti contenuti dichiarativi (`CNT-01`, `TC-08`, `TC-10`) | **Confermata** | Pacchetti sotto `content/packs/*` descritti da `manifest.json` e validati da `scripts/validate_content.py` (esteso in `SP-04` per `scene.background`). Nessun codice eseguibile. Il meccanismo di consegna/verifica remota dei pack dal server entra in M2/M3. |
| **AR-10** | Notifiche push FCM a runtime e Piano B (`TC-13`, `S-02`) | **Aperta con fallback pronto** | `RuntimeFirebaseCoordinator` + `DeepSkyApplication` caricano le opzioni pubbliche Firebase da `/api/v1/push/config` senza `google-services.json`; `FcmHttpV1PushProvider` invia payload solo-dati (`l10nKey`) e rimuove token su `404 UNREGISTERED` ([ADR-0006](adr/0006-sp01-runtime-fcm-push.md)). Validata consegna ad app aperta e in background; resta aperta la verifica a processo chiuso (task switcher, riavvio, Doze) all’inizio di M2. Se insoddisfacente su hardware reale, si attiva il **Piano B** tramite l’interfaccia `PushProvider` (UnifiedPush o build dedicata). |
| **AR-11** | Esposizione HTTPS, Compose e profilo memoria (`AD-04`, `PD-08`, `TC-03`) | **Confermata da M0 e SP-05** | Reverse proxy Caddy TLS su `deepsky.vectevo.com` davanti al backend Spring Boot e PostgreSQL 17; limiti memoria e requisiti self-hosting validati con `SP-05` ([ADR-0009](adr/0009-sp05-backend-footprint.md)). |

---

## 3. Risposte alle domande architetturali (`AD-01` … `AD-10`)

| ID | Domanda (`Considerazioni tecniche` cap. 12) | Scelta architetturale v0.2 e motivazione | Alternative scartate / note |
| :--- | :--- | :--- | :--- |
| **AD-01** | Primitive, protocollo crittografico e scambio chiavi | **X25519** (scambio effimero/pairing + SAS) + **Ed25519** (firma dispositivo/recupero) + **HKDF-SHA256** (derivazione chiavi di canale) + **XChaCha20-Poly1305 AEAD** (`package:cryptography`) + **BIP-39 24 parole** (`bip39_mnemonic`) per la Recovery Key ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). | Crittografia custom o escrow con passphrase sul server (scartate: violano `S-01`/`S-03`). *Nota post-M1:* `proto/sp-02` usa `cryptography` in Dart puro senza `cryptography_flutter`; la scelta nativa/Dart puro per resistenza ad attacchi di temporizzazione entra tra i punti **`G-5`** (`G5-09`). |
| **AD-02** | Autenticazione dispositivi senza account pubblici | Coppia Ed25519 per dispositivo registrata al pairing o al recovery; ogni chiamata protetta firma metodo, path, timestamp, nonce univoco e hash corpo. Il server associa `DevicePrincipal(deviceId, coupleId)` verificando `DeviceEntity` non revocato. | Token bearer condivisi per coppia (scartati: impediscono la revoca granulare `S-06`). |
| **AD-03** | Modello dati e trasporto | Storage server per **eventi cifrati** (append-only, fonte di verità) e **snapshot cifrati** (cache derivata con controllo ottimistico `version`/`schemaVersion`); blob media separati; trasporto iniziale HTTP/REST TLS + risveglio push data-only (`FCM`), con estensione realtime opzionale valutabile solo se necessaria. | Stato solo server-derived (incompatibile con E2EE) o sync offline con coda di conflitti (scartata da `TC-07`). |
| **AD-04** | Esposizione di rete (`D-13`) | **HTTPS pubblico dietro reverse proxy Caddy** (`deepsky.vectevo.com`, porte `80`/`443` aperte in OCI VCN + firewall VM) con certificato TLS automatico; consente push mobile e funzionamento senza app VPN aggiuntive (`P-09`). | Rete privata / Tailscale obbligatoria (scartata come predefinita per attrito su partner non tecnico; opzionale per chi fa self-hosting avanzato). |
| **AD-05** | Istanza mono-coppia vs multi-coppia | **Modello dati multi-coppia nativo con policy configurabile**: ogni tabella utente è partizionata per `couple_id`; l’istanza principale può restare dedicata o aperta a poche coppie fidate applicando quote e rate-limit per coppia. | Database fisico separato per coppia (eccessivo per `SP-05`); schema senza `couple_id` (costoso da migrare in seguito). |
| **AD-06** | Cache locale cifrata, keystore ed esclusione dal backup di sistema | Segreti di identità (`devicePrivateKey`, `CMK`, cache chiavi derivate) salvati tramite `flutter_secure_storage` appoggiato ad Android Keystore (`EncryptedSharedPreferences` / AES-GCM). Per la cache di lettura offline delle immagini/eventi in M2 si adotta cifratura locale con chiave derivata custodita nel keystore. **Esclusione dal backup automatico di Google / Android** tramite `android:allowBackup="false"`, `android:dataExtractionRules` e `android:fullBackupContent` in `AndroidManifest.xml`, così chiavi, `SharedPreferences` e cache locale non lasciano il dispositivo via cloud backup o trasferimento ADB/D2D (recupero solo via Recovery Key o altro telefono). | Chiavi o snapshot in chiaro su disco o inclusi nel backup automatico Google/Android (vietato: espone artefatti locali o rompe l’accoppiamento con Android Keystore al ripristino). |
| **AD-07** | Archiviazione blob e dimensionamento backup | Blob cifrati memorizzati su volume persistente dedicato (`DATA_DIR` / bind volume Docker) referenziati da metadati su PostgreSQL; script OCI estesi includono dump PostgreSQL (`pg_dump`) + sincronizzazione incrementale dei blob cifrati e **prova periodica di ripristino** (`docs/backup-restore.md`). | Salvataggio immagini binarie direttamente in colonne `BYTEA` su PostgreSQL (gonfia WAL e RAM del DB in `SP-05`). |
| **AD-08** | Custodia chiave di firma APK e manifest | Generazione offline e backup cifrato in due luoghi separati, firma **locale** degli artefatti prodotti dalla CI (`PD-10`, `docs/key-custody.md`, `docs/release-signing-workflow.md`), chiave pubblica di verifica dei manifest incorporata nel client (`SP-03`). | Firma automatica in CI con segreti sul runner GitHub (scartata per `PD-10` e repository pubblico `PD-09`). |
| **AD-09** | Strategia di test | Piramide a quattro livelli: (1) unit test crittografici, dominio, scene e parser su Flutter/JUnit; (2) integrazione backend su **PostgreSQL 17 reale con Testcontainers** + regole **ArchUnit**; (3) validazione pack (`validate_content.py`) e licenze (`check-licenses.py`); (4) matrice fisica su due telefoni reali Android prima di ogni gate (`G-1`..`G-4`). | Affidarsi a DB in-memory (`H2`) o soli emulatori (scartato: nasconde bug SQL, lifecycle FCM e `PackageInstaller`). |
| **AD-10** | Osservabilità minima senza violare `S-07` | Metriche tecniche locali tramite Spring Boot Actuator (`/actuator/health`, `jvm.memory.used`, `process.cpu.usage`) accessibili in rete interna/diagnostica, log strutturati privi di payload, segreti, token o identificativi personali permanenti; **zero analytics/crash SDK di terze parti** nel client (`S-07`). | SDK di telemetria o tracciamento eventi utente sul client (vietati da `S-07`). |

---

## 4. Architettura dei componenti e integrazione post-M1

### 4.1 Mappa dei confini logici

```text
+---------------------------------------------------------------+
| Client Android (Flutter + Kotlin nativo)                      |
|  - Presentation: HybridSceneCanvas, AssetOverrideRegistry     |
|  - Domain/Crypto: DeepSkyCrypto, RecoveryKeyCodec, Sync       |
|  - Update: ApkUpdateService (Ed25519 + Range + SHA-256)       |
|  - Storage: SecureKeyStore (Android Keystore)                 |
|  - Kotlin: DeepSkyApplication, RuntimeFirebaseCoordinator,    |
|            DeepSkyFirebaseMessagingService,                   |
|            ApkInstallerCoordinator, InstallResultReceiver     |
+-------------------------------+-------------------------------+
                                | HTTPS TLS (Caddy) + Ed25519 auth
                                v
+---------------------------------------------------------------+
| Server (Spring Boot 4 Monolito Modulare + PostgreSQL 17)      |
|  - config/: SecurityConfig, DeviceAuthFilter, PushConfig      |
|  - pairing/: Couple, Device, Invite, KeyDelivery, Recovery    |
|  - sync/: EncryptedEnvelope, optimistic snapshot, blob ref    |
|  - push/: PushController, PushService, PushProvider (FCM v1)  |
|  - storage: Volume blob cifrati + PostgreSQL (Flyway V1..Vn)  |
+-------------------------------+-------------------------------+
                                | Push data-only {l10nKey, event, ts}
                                v
                     Firebase Cloud Messaging
                  (oppure Plan B PushProvider)
```

### 4.2 Adattamenti richiesti per la promozione in M2

L’esame congiunto dei cinque rami prototipo (`proto/sp-01`–`proto/sp-05`) evidenzia quattro punti di integrazione da risolvere ordinatamente nelle PR di M2 (dettagliati in [Piano operativo M2](m2-operative-plan.md)):

1. **Sequenza unica migrazioni Flyway:** nei prototipi isolati `sp-02`, `sp-01` e `sp-05` hanno creato ciascuno una migrazione `V2__*`. In `development`/M2 vanno ordinate sequenzialmente (`V2` pairing/sync, `V3` `push_registrations`), mantenendo `sp05_benchmark` fuori dallo schema di produzione.
2. **Protezione uniforme con `DeviceAuthFilter`:** in `proto/sp-01` `PushController` era isolato senza l’autenticazione per-dispositivo di `proto/sp-02`. In M2 `GET /api/v1/push/config` può restare pubblico (contiene sole opzioni client non segrete), mentre `POST /api/v1/push/register` e gli invii devono passare dietro `DeviceAuthFilter` verificando appartenenza di `deviceId` alla coppia.
3. **Unificazione canale nativo e manifest Android:** `DeepSkyApplication.kt`, `MainActivity.kt`, `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `native_bridge.dart` e `DeepSkyApp` vanno consolidati in una singola configurazione coerente con routing di produzione anziché le pagine harness `Sp01PrototypePage`–`Sp04HybridHomePage`.
4. **Profilazione rigorosa degli strumenti benchmark:** `Sp05BenchmarkController` resta confinato al profilo Spring `benchmark` (o script/harness dedicato) e mai esposto nel profilo `prod`.

---

## 5. Elenco dei punti da sottoporre a revisione indipendente (`G-5`)

Prima di invitare qualsiasi altra coppia oltre al promotore e alla partner (**`G-5`**, [Project Brief](project-brief.md) `P-06`, [Piano di sviluppo](development-plan.md) `3.1` e `6.5`), un revisore di sicurezza indipendente da chi ha scritto il codice (cap. `2.1` del Piano di sviluppo) deve esaminare i seguenti punti critici emersi da M1:

| # | Area | Componenti / contratti coinvolti | Cosa verificare nella revisione indipendente |
| :--- | :--- | :--- | :--- |
| **G5-01** | **Gerarchia chiavi, entropia e separazione di dominio** | `DeepSkyCrypto`, `RecoveryKeyCodec` (`proto/sp-02` -> M2) | Qualità CSPRNG per `CMK`, chiavi dispositivo e `inviteSecret`; unicità delle stringhe di separazione `info` HKDF (`deepsky-pair-wrap-v1`, canali derivati); assenza di riuso di chiavi o nonce su XChaCha20-Poly1305. |
| **G5-02** | **Canonicalità AAD e resistenza a replay/manomissione** | `EncryptedEnvelope`, `DeepSkyCrypto` (`S-05`) | Impossibilità di spostare ciphertext tra coppie (`coupleId`), tra canali (`channel`), tra versioni/generazioni (`version`, `keyGeneration`) o di riordinare campi ambigui nella serializzazione AAD. |
| **G5-03** | **Derivazione e verifica della Recovery Key** | `RecoveryKeyCodec`, `RecoveryController` (`AD-01`, `F-20`) | Sicurezza della derivazione deterministica Ed25519 dalla seed BIP-39 a 24 parole, formato QR checksummed `deepsky-rk:v1:`, validità del nonce monouso da 60s e robustezza di **rate-limiting** / anti-bruteforce sugli endpoint di recupero e verifica inviti. |
| **G5-04** | **Autenticazione HTTP per dispositivo e anti-replay** | `DeviceAuthFilter`, `Ed25519SignatureVerifier`, `RequestNonceEntity` (`AD-02`) | Esatta copertura della firma (metodo, URI/query, timestamp, nonce, hash body), finestra temporale tollerata, pulizia/unicità dei nonce, e prevenzione IDOR/cross-couple tra `DevicePrincipal.coupleId` e le risorse richieste. |
| **G5-05** | **Rotazione chiavi alla revoca di un dispositivo** | `DELETE /api/v1/devices/{id}`, `keyGeneration` (`S-06`) | Come viene orchestrata l’incrementazione di `keyGeneration > 1` e la ridistribuzione sicura della nuova chiave al dispositivo superstite affinché un telefono rubato (prima della revoca o con snapshot vecchi in cache) non decifri messaggi futuri. |
| **G5-06** | **Custodia locale, cache offline ed esclusione backup Android** | `SecureKeyStore`, `AndroidManifest.xml`, cache locale offline (`AD-06`, `TC-07`) | Configurazione Android Keystore (`flutter_secure_storage`), protezione di chiavi di sessione/snapshot e blob in cache locale, ed effettiva esclusione di chiavi, `SharedPreferences` e cache locale da Google Auto Backup, `adb backup` e trasferimenti dispositivo-dispositivo (`allowBackup="false"`, `dataExtractionRules`, `fullBackupContent`). |
| **G5-07** | **Filiera di aggiornamento APK e pacchetti contenuti** | `ApkUpdateService`, `ApkInstallerCoordinator`, `scripts/sign-release.*`, futuri pack firmati (`TC-10`, `SEC-04`) | Ordine rigido *verifica firma Ed25519 sui byte grezzi prima del parsing JSON*, enforcement `versionCode` crescente e `packageId`, verifica pre-installazione dei certificati di firma APK, gestione sicura della ripresa HTTP `Range` + SHA-256 prima del commit di `PackageInstaller.Session`, assenza di path traversal nei pack contenuti. |
| **G5-08** | **Privacy notifiche push, log e assenza telemetria** | `FcmHttpV1PushProvider`, `DeepSkyFirebaseMessagingService`, Caddy/Spring logs (`S-02`, `S-07`, `AD-10`) | Conferma che FCM trasporti esclusivamente `{ "l10nKey", "event", "ts" }` senza identificatori utente o contenuti in chiaro, che l’endpoint `/api/v1/push/config` non esponga segreti (`serviceAccount`), e che i log/Actuator rispettino `S-07`. |
| **G5-09** | **Libreria crittografica Dart puro vs backend nativo (`cryptography` senza `cryptography_flutter`)** | `pubspec.yaml`, `DeepSkyCrypto`, `RecoveryKeyCodec` (`proto/sp-02` -> M2) | Valutare il rischio concreto di attacchi di temporizzazione (timing side-channel) con le primitive X25519, Ed25519, HKDF e XChaCha20-Poly1305 eseguite in Dart puro tramite `package:cryptography` su Android, e raccomandare se introdurre `cryptography_flutter` (esecuzione nativa/costante-in-tempo) prima di `G-5`. |
