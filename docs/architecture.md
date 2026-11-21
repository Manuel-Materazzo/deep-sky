# Architecture Document: Deep Sky

**Version:** 0.2 (M1 exit / gate `G-1`) · **Date:** November 14, 2026 · **Depends on:** [Project Brief](project-brief.md) v0.2, [Design Brief](design-brief.md) v0.2, [Technical Considerations](technical-considerations.md) v0.1, [ADR-0001](adr/0001-use-adrs.md)–[ADR-0010](adr/0010-g5-09-cryptography-timing-evaluation.md)

**Document status:** exported and consolidated in `docs/` (closes `REP-05`), integrating the architectures validated across the five **M1** verification prototypes (`SP-01`–`SP-05`). Module boundary, security, and self-hosting decisions remain subject to possible refinement during promotion into **M2** (`G-2`) and independent review (**`G-5`**).

---

## 1. Context and Architectural Constraints

Deep Sky is an **Android-first** application (`TC-04`, package `com.vectevo.deep_sky`, `PD-07`) for two partners featuring private **end-to-end encrypted communication from v1** (`TC-05`, `S-01`), a data-driven illustrated UI (`TC-08`, `TC-09`), content-free wake-up notifications (`S-02`), integrated content and APK updates (`TC-10`), and a lightweight backend self-hostable on ARM64/AMD64 VMs via Docker Compose (`TC-02`, `TC-03`).

The public monorepo (`PD-09`) cleanly separates responsibilities:

- `lib/` and `test/`: Flutter client (`TC-01`), client-side cryptography, local secure cache/storage, hybrid scene engine, sync and update services.
- `android/`: native Kotlin code limited to system integrations (`MainActivity`, `DeepSkyApplication`, `PlatformBridgePlugin`, `RuntimeFirebaseCoordinator`, `DeepSkyFirebaseMessagingService`, `ApkInstallerCoordinator`, `InstallResultReceiver`, and future home screen widget `F-13`).
- `server/`: Java 25 + Spring Boot 4 + PostgreSQL 17 + Flyway modular monolith backend (`ADR-0002`, `ADR-0004`), with architectural rules enforced via ArchUnit (`ArchitectureTest`).
- `content/`: declarative scene and asset packs (`content/packs/*`), validated by `scripts/validate_content.py` with no executable code.
- `deploy/`: Docker Compose configuration (`deploy/docker-compose.yml`, `deploy/docker-compose.firebase.yml`, `deploy/docker-compose.sp05.yml`), Caddy reverse proxy (`HTTPS` on `deepsky.vectevo.com`, `PD-08`), and environment variable template (`deploy/.env.example`).
- `docs/`: product specification, design, ADRs, and operational procedures. No secrets, private certificates, or Firebase credentials may reside in the repository (`S-02`, `PD-09`, pre-commit secret scan).

---

## 2. Status of Architectural Decisions (`AR-01` … `AR-11`)

This table explicitly updates architectural decisions `AR-xx` at the end of milestone **M1** (`G-1`), indicating which are **Confirmed**, **Consolidated from prototype**, or **Open with fallback**.

| ID | Architectural Area | Post-M1 Status | Consolidated Decision and References |
| :--- | :--- | :--- | :--- |
| **AR-01** | Modular monolith backend (`SRV-01`, `TC-02`) | **Confirmed** | Spring Boot 4 / Java 25 modular monolith with PostgreSQL 17, Flyway migrations, and package boundaries enforced via ArchUnit (`ADR-0002`, `ADR-0004`). |
| **AR-02** | Per-device authentication (`AD-02`) | **Consolidated from SP-02** | No public accounts or passwords: each device generates an **Ed25519** keypair and signs HTTP requests (`X-Device-Id`, `X-Signature`, anti-replay timestamp/nonce) verified by `DeviceAuthFilter` + `Ed25519SignatureVerifier` ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). |
| **AR-03** | Data model and E2EE sync (`AD-03`, `TC-05`) | **Consolidated from SP-02** | Three tiers: (1) append-only log of encrypted envelopes (`EncryptedEnvelope`), (2) encrypted derived snapshots with optimistic `version` / `schemaVersion` concurrency control, (3) encrypted binary blobs. The server stores only ciphertext and minimal metadata ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). |
| **AR-04** | Logical isolation of couples (`AD-05`) | **Confirmed (extensible)** | Data schema scoped by `couple_id` across devices, key deliveries, encrypted envelopes, and push registrations; supports initial single-couple use and isolates multiple couples on a single instance without structural changes. Full quotas/rate limits in M2. |
| **AR-05** | Pairing, recovery, and revocation protocol (`S-01..S-06`, `F-01`, `F-20`) | **Consolidated from SP-02** | 256-bit `CoupleMasterKey` (`CMK`) wrapped separately for X25519 exchange with SAS verification, cross-device enrollment (`F-20`), and 24-word BIP-39 **Recovery Key** / QR `deepsky-rk:v1:`; canonical AAD on XChaCha20-Poly1305; immediate device revocation. Couple closure (`unpairCouple`, `S-03`) sets `unpaired_at` as a soft-close that immediately blocks device auth, invites, and unilateral recovery (`S-06`); any bilateral consensual reactivation and permanent deletion/export (`F-17`, `S-04`) remain assigned to `M5 Memoria`. Verification on physical phones and with non-technical users continues as a real-data entry gate (`PD-05`, M2). |
| **AR-06** | Flutter client + native Android bridge (`APP-01`, `TC-01`, `TC-04`) | **Confirmed** | Single Flutter UI (`minSdk`/`targetSdk` in `ADR-0003`) and isolated native channel (`PlatformBridgePlugin.kt`, `native_bridge.dart`) for APK installer, runtime FCM initialization, keystore, and future Android widgets. |
| **AR-07** | Hybrid Home composition (`V-07..V-10`, `TC-08`) | **Confirmed from SP-04** | `HybridSceneCanvas` with `SceneManifest`, fixed scene aspect ratio and backdrop with bleed (`bg_day`/`bg_night`), explicit normalized touch areas, ordered TalkBack semantics (`OrdinalSortKey`), and solid UI cards in vertical regions not overlapping the animated space ([ADR-0007](adr/0007-sp04-hybrid-home-scene.md)). |
| **AR-08** | Level 1 animations and non-destructive overrides (`TC-09`, `F-18`) | **Confirmed from SP-04** | Animated layers isolated with `RepaintBoundary`, immediate stop on `reduceMotion` / `disableAnimations`, and external customization via `AssetOverrideRegistry` (`slotId:layerId`) without mutating signed manifests ([ADR-0007](adr/0007-sp04-hybrid-home-scene.md)). |
| **AR-09** | Declarative content packs (`CNT-01`, `TC-08`, `TC-10`) | **Confirmed** | Packs under `content/packs/*` described by `manifest.json` and validated by `scripts/validate_content.py` (extended in `SP-04` for `scene.background`). No executable code. Remote delivery/verification of packs from the server enters in M2/M3. |
| **AR-10** | Runtime FCM push notifications and Plan B (`TC-13`, `S-02`) | **Frozen (verified on real hardware, M2)** | `RuntimeFirebaseCoordinator` + `DeepSkyApplication` load public Firebase options from `/api/v1/push/config` without `google-services.json`; `FcmHttpV1PushProvider` sends data-only payloads (`l10nKey`) and removes tokens on `404 UNREGISTERED` ([ADR-0006](adr/0006-sp01-runtime-fcm-push.md)). Delivery validated on 2026-11-15 on real hardware with app open, in background, swiped from task switcher, after reboot, and in Doze: **Plan B** (UnifiedPush or dedicated build via `PushProvider`) is not activated and remains only as a documented fallback. *Force Stop* from Settings suspends delivery until the app is reopened, as expected on Android. |
| **AR-11** | HTTPS exposure, Compose, and memory profile (`AD-04`, `PD-08`, `TC-03`) | **Confirmed from M0 and SP-05** | Caddy TLS reverse proxy on `deepsky.vectevo.com` in front of the Spring Boot backend and PostgreSQL 17; memory limits and self-hosting requirements validated with `SP-05` ([ADR-0009](adr/0009-sp05-backend-footprint.md)). |

---

## 3. Answers to Architectural Questions (`AD-01` … `AD-10`)

| ID | Question (`Technical Considerations` ch. 12) | Architectural Choice v0.2 and Rationale | Rejected Alternatives / Notes |
| :--- | :--- | :--- | :--- |
| **AD-01** | Primitives, cryptographic protocol, and key exchange | **X25519** (ephemeral/pairing exchange + SAS) + **Ed25519** (device/recovery signing) + **HKDF-SHA256** (channel key derivation) + **XChaCha20-Poly1305 AEAD** (`package:cryptography`) + **24-word BIP-39** (`bip39_mnemonic`) for the Recovery Key ([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)). | Custom cryptography or server-side passphrase escrow (rejected: violate `S-01`/`S-03`). *Post-M1 note:* `proto/sp-02` uses pure-Dart `cryptography` without `cryptography_flutter`; the native vs. pure-Dart choice for timing-attack resistance enters the **`G-5`** items (`G5-09`). |
| **AD-02** | Device authentication without public accounts | Per-device Ed25519 keypair registered at pairing or recovery; every protected call signs method, path, timestamp, unique nonce, and body hash. The server binds `DevicePrincipal(deviceId, coupleId)` by verifying a non-revoked `DeviceEntity`. | Shared per-couple bearer tokens (rejected: prevent granular revocation `S-06`). |
| **AD-03** | Data model and transport | Server storage for **encrypted events** (append-only, source of truth) and **encrypted snapshots** (derived cache with optimistic `version`/`schemaVersion` check); separate media blobs; initial transport HTTP/REST TLS + data-only push wake-up (`FCM`), with optional realtime extension to be evaluated only if needed. | Server-derived-only state (incompatible with E2EE) or offline sync with conflict queue (rejected by `TC-07`). |
| **AD-04** | Network exposure (`D-13`) | **Public HTTPS behind Caddy reverse proxy** (`deepsky.vectevo.com`, ports `80`/`443` open in OCI VCN + VM firewall) with automatic TLS certificate; enables mobile push and operation without extra VPN apps (`P-09`). | Mandatory private network / Tailscale (rejected as default due to friction for non-technical partner; optional for advanced self-hosters). |
| **AD-05** | Single-couple vs. multi-couple instance | **Native multi-couple data model with configurable policy**: every user table is partitioned by `couple_id`; the main instance can remain dedicated or open to a few trusted couples by applying per-couple quotas and rate limits. | Separate physical database per couple (excessive for `SP-05`); schema without `couple_id` (expensive to migrate later). |
| **AD-06** | Encrypted local cache, keystore, and system backup exclusion | Identity secrets (`devicePrivateKey`, `CMK`, derived key cache) stored via `flutter_secure_storage` backed by Android Keystore (`EncryptedSharedPreferences` / AES-GCM). For offline read caching of images/events in M2, local encryption with a derived key stored in the keystore is adopted. **Exclusion from Google / Android automatic backup** via `android:allowBackup="false"`, `android:dataExtractionRules`, and `android:fullBackupContent` in `AndroidManifest.xml`, so keys, `SharedPreferences`, and local cache never leave the device via cloud backup or ADB/D2D transfer (recovery only via Recovery Key or the other phone). | Plaintext keys or snapshots on disk or included in Google/Android automatic backup (prohibited: exposes local artifacts or breaks Android Keystore binding on restore). |
| **AD-07** | Blob storage and backup sizing | Encrypted blobs stored on a dedicated persistent volume (`DATA_DIR` / Docker bind volume) referenced by metadata in PostgreSQL; extended OCI scripts include PostgreSQL dump (`pg_dump`) + incremental sync of encrypted blobs and **periodic restore testing** (`docs/backup-restore.md`). | Storing binary images directly in PostgreSQL `BYTEA` columns (bloats DB WAL and RAM in `SP-05`). |
| **AD-08** | Custody of APK and manifest signing keys | Offline generation and encrypted backup in two separate locations, **local** signing of CI-produced artifacts (`PD-10`, `docs/key-custody.md`, `docs/release-signing-workflow.md`), manifest verification public key embedded in the client (`SP-03`). | Automatic CI signing with secrets on the GitHub runner (rejected due to `PD-10` and public repository `PD-09`). |
| **AD-09** | Testing strategy | Four-tier pyramid: (1) cryptographic, domain, scene, and parser unit tests on Flutter/JUnit; (2) backend integration on **real PostgreSQL 17 with Testcontainers** + **ArchUnit** rules; (3) pack (`validate_content.py`) and license (`check-licenses.py`) validation; (4) physical matrix on two real Android phones before every gate (`G-1`..`G-4`). | Relying on in-memory DB (`H2`) or emulators alone (rejected: hides SQL bugs, FCM lifecycle, and `PackageInstaller` behavior). |
| **AD-10** | Minimal observability without violating `S-07` | Local technical metrics via Spring Boot Actuator (`/actuator/health`, `jvm.memory.used`, `process.cpu.usage`) accessible on internal/diagnostic network, structured logs free of payloads, secrets, tokens, or permanent personal identifiers; **zero third-party analytics/crash SDKs** in the client (`S-07`). | Telemetry or user-event tracking SDKs on the client (prohibited by `S-07`). |

---

## 4. Component Architecture and Post-M1 Integration

### 4.1 Logical Boundary Map

```text
+---------------------------------------------------------------+
| Android Client (Flutter + Native Kotlin)                      |
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
| Server (Spring Boot 4 Modular Monolith + PostgreSQL 17)       |
|  - config/: SecurityConfig, DeviceAuthFilter, PushConfig      |
|  - pairing/: Couple, Device, Invite, KeyDelivery, Recovery    |
|  - sync/: EncryptedEnvelope, optimistic snapshot, blob ref    |
|  - push/: PushController, PushService, PushProvider (FCM v1)  |
|  - storage: Encrypted blob volume + PostgreSQL (Flyway V1..Vn)|
+-------------------------------+-------------------------------+
                                | Data-only push {l10nKey, event, ts}
                                v
                     Firebase Cloud Messaging
                   (or Plan B PushProvider)
```

### 4.2 Adaptations Required for Promotion into M2

Joint review of the five prototype branches (`proto/sp-01`–`proto/sp-05`) highlights four integration points to resolve cleanly in the M2 PRs (detailed in [M2 Operative Plan](m2-operative-plan.md)):

1. **Single Flyway migration sequence:** in the isolated prototypes, `sp-02`, `sp-01`, and `sp-05` each created a `V2__*` migration. In `development`/M2 they must be ordered sequentially (`V2` pairing/sync, `V3` `push_registrations`), keeping `sp05_benchmark` out of the production schema.
2. **Uniform protection with `DeviceAuthFilter`:** in `proto/sp-01`, `PushController` was isolated without the per-device authentication of `proto/sp-02`. In M2 `GET /api/v1/push/config` can remain public (it contains only non-secret client options), whereas `POST /api/v1/push/register` and push sends must sit behind `DeviceAuthFilter`, verifying that `deviceId` belongs to the couple.
3. **Unification of native channel and Android manifest:** `DeepSkyApplication.kt`, `MainActivity.kt`, `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `native_bridge.dart`, and `DeepSkyApp` must be consolidated into a single coherent configuration with production routing instead of the `Sp01PrototypePage`–`Sp04HybridHomePage` harness pages.
4. **Strict profiling of benchmark tools:** `Sp05BenchmarkController` remains confined to the `benchmark` Spring profile (or a dedicated script/harness) and is never exposed in the `prod` profile.

---

## 5. Checklist of Items for Independent Review (`G-5`)

Before inviting any couple other than the promoter and his partner (**`G-5`**, [Project Brief](project-brief.md) `P-06`, [Development Plan](development-plan.md) `3.1` and `6.5`), a security reviewer independent from the code authors (ch. `2.1` of the Development Plan) must examine the following critical items that emerged from M1:

| # | Area | Components / Contracts Involved | What to Verify in the Independent Review |
| :--- | :--- | :--- | :--- |
| **G5-01** | **Key hierarchy, entropy, and domain separation** | `DeepSkyCrypto`, `RecoveryKeyCodec` (`proto/sp-02` -> M2) | CSPRNG quality for `CMK`, device keys, and `inviteSecret`; uniqueness of HKDF `info` separation strings (`deepsky-pair-wrap-v1`, derived channels); absence of key or nonce reuse on XChaCha20-Poly1305. |
| **G5-02** | **AAD canonicality and resistance to replay/tampering** | `EncryptedEnvelope`, `DeepSkyCrypto` (`S-01`, `AD-01`) | Impossibility of moving ciphertext across couples (`coupleId`), across channels (`channel`), across versions/generations (`version`, `keyEpoch`), or of reordering ambiguous fields in AAD serialization. |
| **G5-03** | **Recovery Key derivation and verification** | `RecoveryKeyCodec`, `RecoveryController` (`AD-01`, `F-20`) | Security of deterministic Ed25519 derivation from the 24-word BIP-39 seed, checksummed QR format `deepsky-rk:v1:`, validity of the 60s single-use nonce, and robustness of **rate-limiting** / anti-bruteforce on recovery and invite verification endpoints. |
| **G5-04** | **Per-device HTTP authentication and anti-replay** | `DeviceAuthFilter`, `Ed25519SignatureVerifier`, `RequestNonceEntity` (`AD-02`) | Exact signature coverage (method, URI/query, timestamp, nonce, body hash), tolerated time window, nonce cleanup/uniqueness, and IDOR/cross-couple prevention between `DevicePrincipal.coupleId` and requested resources. |
| **G5-05** | **Key rotation upon device revocation** | `POST /api/v1/pairing/devices/{deviceId}/revoke`, `keyEpoch` (`S-06`) | How incrementing `keyEpoch > 1` and securely redistributing the new key to the surviving device is orchestrated so that a stolen phone (before revocation or with old cached snapshots) cannot decrypt future messages. |
| **G5-06** | **Local custody, offline cache, and Android backup exclusion** | `SecureKeyStore`, `AndroidManifest.xml`, local offline cache (`AD-06`, `TC-07`) | Android Keystore configuration (`flutter_secure_storage`), protection of session/snapshot keys and locally cached blobs, and effective exclusion of keys, `SharedPreferences`, and local cache from Google Auto Backup, `adb backup`, and device-to-device transfers (`allowBackup="false"`, `dataExtractionRules`, `fullBackupContent`). |
| **G5-07** | **APK and content-pack update supply chain** | `ApkUpdateService`, `ApkInstallerCoordinator`, `scripts/sign-release.*`, future signed packs (`TC-10`, `SEC-04`) | Strict order *Ed25519 signature verification on raw bytes before JSON parsing*, monotonically increasing `versionCode` and `packageId` enforcement, pre-install verification of APK signing certificates, safe handling of HTTP `Range` resume + SHA-256 before `PackageInstaller.Session` commit, and absence of path traversal in content packs. |
| **G5-08** | **Push notification privacy, logs, and absence of telemetry** | `FcmHttpV1PushProvider`, `DeepSkyFirebaseMessagingService`, Caddy/Spring logs (`S-02`, `S-07`, `AD-10`) | Confirmation that FCM carries exclusively `{ "l10nKey", "event", "ts" }` without user identifiers or plaintext content, that `/api/v1/push/config` does not expose secrets (`serviceAccount`), and that logs/Actuator comply with `S-07`. |
| **G5-09** | **Pure-Dart cryptographic library vs. native backend (`cryptography` without `cryptography_flutter`)** | `pubspec.yaml`, `DeepSkyCrypto`, `RecoveryKeyCodec` (`proto/sp-02` -> M2) | Assess the concrete risk of timing side-channel attacks with X25519, Ed25519, HKDF, and XChaCha20-Poly1305 primitives executed in pure Dart via `package:cryptography` on Android, and recommend whether to introduce `cryptography_flutter` (native/constant-time execution) before `G-5`. |
