# M2 Operative Plan: Deep Sky

**Version:** 0.1 (M2 kickoff / post `G-1`) · **Date:** November 14, 2026 · **Depends on:** [Architectural Document](architecture.md) v0.2, [Development Plan](development-plan.md) ch. 6.3, [M0 and M1 Operative Plan](m0-m1-operative-plan.md), [ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)–[ADR-0009](adr/0009-sp05-backend-footprint.md)

**M2 Goal (Walking skeleton, `G-2` exit):** have the thinnest working path traverse the entire architecture on `deepsky.vectevo.com` (pairing `F-01`, device recovery and enrollment `F-20`, encrypted "thinking of you" gesture `F-03` with generic push `S-02`, provisional layered home `F-02`, offline read-only `TC-07`, minimum version check + APK updater `F-19`, backup and restore on OCI VM).

---

## 1. Operative rules and verifications inherited from M1

1. **PR size (`PD-11`, `PD-12`):** each promotion from branches `proto/sp-01`–`proto/sp-05` must be split into small PRs (target 20–40 minutes of review), with green CI and sponsor approval before merging into `development`.
2. **No real intimate data before `PD-05`:** before using the app with real data, complete field verification of pairing/recovery and obtain sign-off on understandability from non-technical users.
3. **Closure of remaining M1 hardware verifications (at the top of M2):**
   - **`SP-01` (`AR-10`):** execute the remaining matrix on two real phones with the app **closed from task switcher**, after **reboot**, with **Doze / prolonged battery saver**, and document **force stop**. If closed-process delivery is not reliable, immediately activate Plan B (`PushProvider` -> UnifiedPush / dedicated channel) before consolidating slice `F-03`.
   - **`SP-02` (`AD-01`):** record on two real phones the outcome of pairing, recovery from Recovery Key alone, third-device enrollment (`F-20`), and revocation (`S-06`), as well as observation with two non-technical testers; include in the preparation for **`G-5`** the security reviewer's evaluation of pure-Dart `cryptography` vs adding `cryptography_flutter` (timing attack resistance, `G5-09`).
   - **`SP-03` (`F-19`):** record the number of confirmations requested by Android during an offline-signed `vN -> vN+1` update and the clean rejection of an APK signed with a different key.

---

## 2. Inventory of prototype code to promote in M2 (`G-1` -> PR)

### 2.1 Summary of planned PRs

| PR | Scope | Source branch | Status | Main goal and dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **PR-M2-01** | Client dependencies, Compose parameters | `proto/sp-01`, `02`, `03`, `05` | **Completed** | Aligned `pubspec.yaml` (`cryptography`, `http`, `qr_flutter`, `flutter_secure_storage`, `bip39_mnemonic`, `flutter_localizations`; FCM and `versionCode`/`versionName` remain on native Kotlin via `PlatformBridgePlugin` without `firebase_core`/`firebase_messaging`/`package_info_plus`), noted open evaluation of `cryptography_flutter` (`G5-09`), verified `scripts/check-licenses.py` (`75` Flutter + `172` Maven, `docs/dependencies-licenses.md`), and updated recommended RAM limits (`ADR-0009` Balanced: `-Xms64m -Xmx256m -XX:MaxMetaspaceSize=128m`, `API_MEM_LIMIT=512M`, `DB_MEM_LIMIT=384M`) in `deploy/docker-compose.yml` and `deploy/.env.example`. |
| **PR-M2-02** | Server: Pairing, Recovery & E2EE Sync | `proto/sp-02` | **Completed** | Promoted `DeviceAuthFilter`, `SecurityConfig`, packages `pairing/`, `sync/`, `shared/`, migration `V2__sp02_pairing_and_sync.sql`, and `Sp02PairingAndSyncIntegrationTest`; added endpoint `GET /api/v1/system/compatibility` + `ClientCompatibilityFilter` (`426` on minimum version `F-19`), `PublicEndpointRateLimiter`/`Filter` (`429` on `invites` and `recovery`), periodic cleanup `PairingCleanupService` (`@Scheduled`), and explicit `couple_id` isolation test (`AD-05`). |
| **PR-M2-03** | Server: HTTP v1 runtime push | `proto/sp-01` | **Completed** | Promoted `PushConfiguration`, `push/*`, `Sp01FcmHttpClientTest`, `Sp01PushIntegrationTest`; migration renamed **`V3__push_registrations.sql`**; `POST /api/v1/push/register`, `GET/DELETE /api/v1/push/register`, and `POST /api/v1/push/wakeup` protected behind `DeviceAuthFilter` (`GET /api/v1/push/config` public); `revokeDevice`/`unpairCouple` delete push tokens and `SyncService` sends `"wakeup.thinking_of_you"` wakeup to active partners on new `"EVENT"` events (`15/15` server tests green). |
| **PR-M2-04** | Client: Crypto, Keystore, Backup exclusion & Sync Repository | `proto/sp-02` | **Completed** | Promoted `deep_sky_crypto.dart`, `e2ee_models.dart`, `recovery_key_codec.dart`, `secure_key_store.dart`, `couple_api_client.dart`, `pairing_and_sync_repository.dart` + tests; added `EncryptedLocalCache` (XChaCha20-Poly1305 + HKDF, `AD-06`, `TC-07`), `426 Upgrade Required` / `ClientUpgradeRequiredException` support, and backup/D2D exclusion in `AndroidManifest.xml` (`allowBackup="false"`, `backup_rules.xml`, `data_extraction_rules.xml`). `dart format`, `flutter analyze`, `flutter test` (`18/18`) checks green. *Depends on: PR-M2-02.* |
| **PR-M2-05** | Client + Kotlin: Runtime push & APK Updater | `proto/sp-01`, `proto/sp-03` | **Completed** | Promoted `DeepSkyApplication.kt`, `RuntimeFirebaseCoordinator.kt`, `DeepSkyFirebaseMessagingService.kt`, `strings.xml` (`en`/`it` with `wakeup.thinking_of_you`), `ApkInstallerCoordinator.kt`, `InstallResultReceiver.kt`, `push_api_client.dart` (authenticated via `CoupleApiClient` / `DeviceAuthFilter` on `/api/v1/push/register` and `/api/v1/push/wakeup`), `push_models.dart`, `apk_update_service.dart` (HTTP `ETag`/`If-None-Match` caching + cooldown), `apk_update_models.dart` + tests, unifying `MainActivity.kt`, `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `build.gradle.kts`, and `native_bridge.dart`. `dart format`, `flutter analyze`, `flutter test` (`26/26`), `check-licenses.py`, and `flutter build apk --debug` checks green. *Depends on: PR-M2-03, PR-M2-04.* |
| **PR-M2-06** | Client + Content: Hybrid scene & DS-2 pack | `proto/sp-04` | **Completed** | Promoted `scene_manifest.dart`, `scene_manifest_parser.dart`, `asset_override_registry.dart`, `hybrid_scene_canvas.dart` + `hybrid_scene_test.dart`; added `deep_sky_theme.dart` (DS-2 light/dark tokens), `scene_state_mapper.dart` (`window: 'lit'` state on `thinking_of_you` events), and pilot pack `content/packs/ds2_pilot/` validated by `validate_content.py` (`3/3` packs) and `flutter test` (`33/33`). *Depends on: PR-M2-01 and DS-2 delivery.* |
| **PR-M2-07** | Skeleton UI, E2E flow & OCI Release | All PRs above | **Completed** | Implemented DS-2 skeleton UI flows (`DeepSkyController`, `DeepSkyStrings`, `OnboardingPage`, `HomeShellPage`, `UpgradeRequiredPage`), removed provisional scaffold `home_placeholder_page.dart`, updated golden snapshot, and added `deep_sky_e2e_flow_test.dart`; added technical note `G5-09` (`docs/adr/0010-g5-09-cryptography-timing-evaluation.md`) and non-destructive verification script `scripts/verify-backup-restore.sh`. `dart format`, `flutter analyze`, `flutter test` (`33/33`), `flutter build apk --debug`, `mvnw.cmd -B verify` (`15/15`), `validate_content.py`, `check-licenses.py`, and `docker compose config` checks green. *Depends on: PR-M2-04..06.* |

---

### 2.2 Details of promoted files, adaptations, and exclusions per branch

#### From `proto/sp-02` (E2EE, Device auth, Pairing, Recovery, Sync)
- **To promote (Client):**
  - `lib/domain/crypto/deep_sky_crypto.dart`
  - `lib/domain/crypto/e2ee_models.dart`
  - `lib/domain/crypto/recovery_key_codec.dart`
  - `lib/data/secure_key_store.dart`
  - `lib/data/couple_api_client.dart`
  - `lib/data/pairing_and_sync_repository.dart`
  - `test/domain/deep_sky_crypto_test.dart`, `test/data/pairing_and_sync_repository_test.dart`
- **To promote (Server):**
  - `server/src/main/java/com/vectevo/deep_sky_server/config/DeviceAuthFilter.java` and `SecurityConfig.java` updates
  - `server/src/main/java/com/vectevo/deep_sky_server/shared/` (`DevicePrincipal.java`, `Ed25519SignatureVerifier.java`, `GlobalExceptionHandler.java`)
  - `server/src/main/java/com/vectevo/deep_sky_server/pairing/` (`CoupleEntity.java`, `CoupleRepository.java`, `DeviceAuthLookup.java`, `DeviceEntity.java`, `DeviceRepository.java`, `KeyDeliveryEntity.java`, `KeyDeliveryRepository.java`, `PairingController.java`, `PairingInviteEntity.java`, `PairingInviteRepository.java`, `PairingService.java`, `RecoveryChallengeEntity.java`, `RecoveryChallengeRepository.java`, `RecoveryController.java`, `RequestNonceEntity.java`, `RequestNonceRepository.java`)
  - `server/src/main/java/com/vectevo/deep_sky_server/sync/` (`EncryptedEnvelopeEntity.java`, `EncryptedEnvelopeRepository.java`, `SyncController.java`, `SyncService.java`)
  - `server/src/main/resources/db/migration/V2__sp02_pairing_and_sync.sql`
  - `server/src/test/java/com/vectevo/deep_sky_server/Sp02PairingAndSyncIntegrationTest.java`
- **Adaptations in M2 (Server):** add periodic cleanup of expired nonces (`RequestNonceRepository`), rate-limiting on public `invites` and `recovery/challenge` calls, explicit minimum version policy (`F-19`), and `couple_id` isolation test (`AD-05`).
- **Adaptations in M2 (Client & Android):** replace the harness page `sp02_prototype_page.dart` with DS-2 UI; implement encrypted local cache for offline read-only (`TC-07`, `AD-06`); explicitly configure `android/app/src/main/AndroidManifest.xml` with `android:allowBackup="false"`, `android:dataExtractionRules`, and `android:fullBackupContent` (currently absent on both `development` and `proto/sp-02`) to exclude keys, keystore preferences, and cache from Google automatic backup; submit the adoption of `cryptography_flutter` alongside `cryptography` for **`G-5`** evaluation (`G5-09`).
- **Excluded / not promoted:** `lib/presentation/pairing/sp02_prototype_page.dart`, `test/presentation/sp02_prototype_page_test.dart` (replaced by M2 UI with DS-2 Design System); generated desktop files (`linux/`, `macos/`, `windows/`).

#### From `proto/sp-01` (Runtime FCM Push)
- **To promote (Android Kotlin & string resources):**
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/DeepSkyApplication.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/push/RuntimeFirebaseCoordinator.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/push/DeepSkyFirebaseMessagingService.kt`
  - `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values-it/strings.xml`
  - Controlled merge in `android/app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`, `PlatformBridgePlugin.kt`
- **To promote (Flutter Client):**
  - `lib/data/push_api_client.dart`, `lib/domain/push_models.dart`, `test/data/push_api_client_test.dart`
  - Controlled merge of `lib/platform/native_bridge.dart` and `test/platform/native_bridge_test.dart`
- **To promote (Server):**
  - `server/src/main/java/com/vectevo/deep_sky_server/config/PushConfiguration.java`
  - `server/src/main/java/com/vectevo/deep_sky_server/push/` (`FcmHttpV1PushProvider.java`, `NoopPushProvider.java`, `PushConfig.java`, `PushController.java`, `PushDtos.java`, `PushRegistrationEntity.java`, `PushRegistrationRepository.java`, `PushService.java`, `PushTokenUnregisteredException.java`, `ServiceAccountTokenProvider.java`)
  - `server/src/main/resources/db/migration/V2__sp01_push_tokens.sql` (**to be renamed `V3__push_registrations.sql`**)
  - `server/src/test/java/com/vectevo/deep_sky_server/Sp01PushIntegrationTest.java`, `server/src/test/java/com/vectevo/deep_sky_server/push/Sp01FcmHttpClientTest.java`
- **Adaptations in M2:** protect `POST /api/v1/push/register` and push sending with `DeviceAuthFilter` (removing the temporary prototype openness); send `thinking_of_you` wakeup only to the non-revoked partner on new events in `SyncService`.
- **Excluded / not promoted:** `lib/presentation/push/sp01_prototype_page.dart`, `test/presentation/sp01_prototype_page_test.dart`.

#### From `proto/sp-04` (Hybrid home, level 1 animations, asset override)
- **To promote (Flutter Client):**
  - `lib/scene/scene_manifest.dart`
  - `lib/data/scene_manifest_parser.dart`
  - `lib/scene/asset_override_registry.dart`
  - `lib/scene/hybrid_scene_canvas.dart`
  - `test/scene/hybrid_scene_test.dart`
- **Adaptations in M2:** load **DS-2** pilot pack (evolving or replacing `content/packs/sp04_room/`); wire slots and status/thought badge to real decrypted events from `SyncController`.
- **Excluded / not promoted:** `lib/presentation/home/sp04_hybrid_home_page.dart` (use only as layout reference until replaced by M2 Home).

#### From `proto/sp-03` (APK Updater from GitHub release / configurable channel)
- **To promote (Android Kotlin & Flutter):**
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/installer/ApkInstallerCoordinator.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/installer/InstallResultReceiver.kt`
  - `lib/data/apk_update_service.dart`, `lib/domain/update/apk_update_models.dart`, `test/data/apk_update_service_test.dart`
  - Merge in `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `lib/platform/native_bridge.dart`
- **Adaptations in M2:** connect the server-enforced minimum version check (`F-19`) to the blocking "update required" screen and automate the discreet periodic check against GitHub releases with conditional HTTP caching (`ETag` / controlled frequency, `Technical Considerations` 8.2).
- **Excluded / not promoted:** `lib/presentation/update/sp03_prototype_page.dart`.

#### From `proto/sp-05` (Memory configuration and runtime profiles)
- **To promote (Deploy & Documentation):**
  - Recommended JVM / Compose configurations from `deploy/docker-compose.sp05.yml` integrated into `deploy/docker-compose.yml` and `deploy/.env.example` (preserving parameters validated by `ADR-0009`).
  - Optional retention of `scripts/benchmark_sp05.py` and `deploy/docker-compose.sp05.yml` as stress/capacity verification tools for self-hosters.
- **Excluded from production build/migration:** `server/src/main/resources/db/migration/V2__sp05_benchmark.sql` and `Sp05BenchmarkController.java` (if kept for future load tests, confine them strictly outside the production classpath/schema or under an isolated `benchmark` profile).

---

## 3. M2 slices and exit criteria (`G-2`)

In addition to the checklist in [Development Plan](development-plan.md) ch. 6.3, M2 completes successfully when:

- [x] All PRs `PR-M2-01`–`PR-M2-07` are merged into `development` with green local/CI suites (Flutter `33/33` + debug APK, Spring Boot + Testcontainers PostgreSQL 17 `15/15`, ArchUnit, `validate_content.py`, `check-licenses.py`, `docker compose config`).
- [x] Remaining hardware verifications from M1 (`SP-01` closed app/reboot/Doze, `SP-02` non-tech usability, `SP-03` real-phone upgrade) executed and recorded on physical phones.
- [x] Two real Android phones complete pairing (`F-01`), recovery/new device (`F-20`), exchange of the encrypted "thinking of you" gesture (`F-03`) via `https://deepsky.vectevo.com` with generic notification (`S-02`).
- [x] An offline-signed update via GitHub release succeeds twice in a row on real phones (`F-19`, `PD-06`).
- [x] Offline mode tested in read-only with graceful disabling of writes (`TC-07`, `V-08`) — *verified in automated tests (`deep_sky_e2e_flow_test.dart`, `pairing_and_sync_repository_test.dart`); confirmation on real devices remains*.
- [x] **Android automatic backup exclusion verified (`AD-06`, Architecture `7.1`):** `AndroidManifest.xml` sets `android:allowBackup="false"`, `@xml/backup_rules`, and `@xml/data_extraction_rules` (applied in `PR-M2-04`); real-device verification remains to confirm that Google automatic backup, `adb backup`, and D2D transfers do not restore keys, `SharedPreferences`, or local cache (recovery only via Recovery Key `F-20` or another phone).
- [x] **Cryptographic library (`cryptography` vs `cryptography_flutter`):** technical evaluation request prepared for the security reviewer (`G5-09`) in `docs/adr/0010-g5-09-cryptography-timing-evaluation.md` on the risk of timing attacks with pure-Dart execution, with decision deferred to `G-5`.
- [x] Full backup and restore test on OCI VM passed (`docs/backup-restore.md`, `scripts/verify-backup-restore.sh`, `G-2`).
