# Piano operativo M2: Deep Sky

**Versione:** 0.1 (avvio M2 / post `G-1`) · **Data:** 14 novembre 2026 · **Dipende da:** [Documento architetturale](architecture.md) v0.2, [Piano di sviluppo](development-plan.md) cap. 6.3, [Piano operativo M0 e M1](m0-m1-operative-plan.md), [ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)–[ADR-0009](adr/0009-sp05-backend-footprint.md)

**Obiettivo di M2 (Scheletro funzionante, uscita `G-2`):** far attraversare l’intera architettura dal percorso più sottile e funzionante su `deepsky.vectevo.com` (pairing `F-01`, recupero e arruolamento dispositivo `F-20`, gesto cifrato “ti penso” `F-03` con push generico `S-02`, home provvisoria a livelli `F-02`, sola lettura offline `TC-07`, controllo versione minima + aggiornatore APK `F-19`, backup e ripristino su VM OCI).

---

## 1. Regole operative e verifiche ereditate da M1

1. **Dimensione delle PR (`PD-11`, `PD-12`):** ogni promozione dai rami `proto/sp-01`–`proto/sp-05` va frazionata in PR piccole (target 20–40 minuti di revisione), con CI verde e approvazione del promotore prima del merge su `development`.
2. **Nessun dato intimo reale prima di `PD-05`:** prima di usare l’app con dati veri, completare la verifica sul campo di pairing/recupero e ottenere l’ok sulla comprensibilità da utenti non tecnici.
3. **Chiusura delle verifiche hardware residue di M1 (in testa a M2):**
   - **`SP-01` (`AR-10`):** eseguire la matrice residua su due telefoni reali con app **chiusa dal task switcher**, dopo **riavvio**, con **Doze / risparmio batteria prolungato** e documentare l’**arresto forzato**. Se la consegna a processo chiuso non è affidabile, attivare subito il Piano B (`PushProvider` -> UnifiedPush / canale dedicato) prima di consolidare la fetta `F-03`.
   - **`SP-02` (`AD-01`):** registrare su due telefoni reali l’esito di pairing, recupero da sola Recovery Key, arruolamento terzo dispositivo (`F-20`) e revoca (`S-06`), oltre all’osservazione con due tester non tecnici; includere nella preparazione a **`G-5`** la valutazione del revisore di sicurezza su `cryptography` in Dart puro vs aggiunta di `cryptography_flutter` (resistenza agli attacchi di temporizzazione, `G5-09`).
   - **`SP-03` (`F-19`):** registrare il numero di conferme richieste da Android durante un aggiornamento firmato offline `vN -> vN+1` e il rifiuto pulito di un APK firmato con chiave diversa.

---

## 2. Inventario del codice dei prototipi da promuovere in M2 (`G-1` -> PR)

### 2.1 Riepilogo delle PR pianificate

| PR | Ambito | Ramo sorgente | Stato | Obiettivo principale e dipendenze |
| :--- | :--- | :--- | :--- | :--- |
| **PR-M2-01** | Dipendenze client, parametri Compose | `proto/sp-01`, `02`, `03`, `05` | **Completata** | Allineato `pubspec.yaml` (`cryptography`, `http`, `qr_flutter`, `flutter_secure_storage`, `bip39_mnemonic`, `flutter_localizations`; FCM e `versionCode`/`versionName` restano su Kotlin nativo tramite `PlatformBridgePlugin` senza `firebase_core`/`firebase_messaging`/`package_info_plus`), annotata valutazione aperta di `cryptography_flutter` (`G5-09`), verificato `scripts/check-licenses.py` (`75` Flutter + `172` Maven, `docs/dependencies-licenses.md`) e aggiornati i limiti RAM raccomandati (`ADR-0009` Balanced: `-Xms64m -Xmx256m -XX:MaxMetaspaceSize=128m`, `API_MEM_LIMIT=512M`, `DB_MEM_LIMIT=384M`) su `deploy/docker-compose.yml` e `deploy/.env.example`. |
| **PR-M2-02** | Server: Pairing, Recovery & Sync E2EE | `proto/sp-02` | **Completata** | Promossi `DeviceAuthFilter`, `SecurityConfig`, package `pairing/`, `sync/`, `shared/`, migrazione `V2__sp02_pairing_and_sync.sql` e `Sp02PairingAndSyncIntegrationTest`; aggiunti endpoint `GET /api/v1/system/compatibility` + `ClientCompatibilityFilter` (`426` su versione minima `F-19`), `PublicEndpointRateLimiter`/`Filter` (`429` su `invites` e `recovery`), cleanup periodico `PairingCleanupService` (`@Scheduled`) e test esplicito di isolamento `couple_id` (`AD-05`). |
| **PR-M2-03** | Server: Push runtime HTTP v1 | `proto/sp-01` | **Completata** | Promossi `PushConfiguration`, `push/*`, `Sp01FcmHttpClientTest`, `Sp01PushIntegrationTest`; migrazione rinominata **`V3__push_registrations.sql`**; `POST /api/v1/push/register`, `GET/DELETE /api/v1/push/register` e `POST /api/v1/push/wakeup` protetti dietro `DeviceAuthFilter` (`GET /api/v1/push/config` pubblico); `revokeDevice`/`unpairCouple` eliminano i token push e `SyncService` invia risveglio `"wakeup.thinking_of_you"` ai partner attivi su nuovi eventi `"EVENT"` (`15/15` test server verdi). |
| **PR-M2-04** | Client: Crypto, Keystore, Backup exclusion & Sync Repository | `proto/sp-02` | **Completata** | Promossi `deep_sky_crypto.dart`, `e2ee_models.dart`, `recovery_key_codec.dart`, `secure_key_store.dart`, `couple_api_client.dart`, `pairing_and_sync_repository.dart` + test; aggiunta `EncryptedLocalCache` (XChaCha20-Poly1305 + HKDF, `AD-06`, `TC-07`), supporto `426 Upgrade Required` / `ClientUpgradeRequiredException`, ed esclusione backup/D2D in `AndroidManifest.xml` (`allowBackup="false"`, `backup_rules.xml`, `data_extraction_rules.xml`). Verifiche `dart format`, `flutter analyze`, `flutter test` (`18/18`) verdi. *Dipende da: PR-M2-02.* |
| **PR-M2-05** | Client + Kotlin: Push runtime & Updater APK | `proto/sp-01`, `proto/sp-03` | **Completata** | Promossi `DeepSkyApplication.kt`, `RuntimeFirebaseCoordinator.kt`, `DeepSkyFirebaseMessagingService.kt`, `strings.xml` (`en`/`it` con `wakeup.thinking_of_you`), `ApkInstallerCoordinator.kt`, `InstallResultReceiver.kt`, `push_api_client.dart` (autenticato via `CoupleApiClient` / `DeviceAuthFilter` su `/api/v1/push/register` e `/api/v1/push/wakeup`), `push_models.dart`, `apk_update_service.dart` (caching HTTP `ETag`/`If-None-Match` + cooldown), `apk_update_models.dart` + test, unificando `MainActivity.kt`, `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `build.gradle.kts` e `native_bridge.dart`. Verifiche `dart format`, `flutter analyze`, `flutter test` (`26/26`), `check-licenses.py` e `flutter build apk --debug` verdi. *Dipende da: PR-M2-03, PR-M2-04.* |
| **PR-M2-06** | Client + Content: Scena ibrida & pack DS-2 | `proto/sp-04` | **Completata** | Promossi `scene_manifest.dart`, `scene_manifest_parser.dart`, `asset_override_registry.dart`, `hybrid_scene_canvas.dart` + `hybrid_scene_test.dart`; aggiunti `deep_sky_theme.dart` (token DS-2 chiari/scuri), `scene_state_mapper.dart` (stato `window: 'lit'` su eventi `thinking_of_you`) e pack pilota `content/packs/ds2_pilot/` validato da `validate_content.py` (`3/3` pack) e `flutter test` (`33/33`). *Dipende da: PR-M2-01 e consegna DS-2.* |
| **PR-M2-07** | UI scheletro, flusso E2E & Release OCI | Tutte le PR sopra | **Completata** | Implementati i flussi UI scheletro DS-2 (`DeepSkyController`, `DeepSkyStrings`, `OnboardingPage`, `HomeShellPage`, `UpgradeRequiredPage`), rimosso lo scaffold provvisorio `home_placeholder_page.dart`, aggiornato golden snapshot e aggiunto `deep_sky_e2e_flow_test.dart`; aggiunta nota tecnica `G5-09` (`docs/adr/0010-g5-09-cryptography-timing-evaluation.md`) e script di verifica non distruttiva `scripts/verify-backup-restore.sh`. Verifiche `dart format`, `flutter analyze`, `flutter test` (`33/33`), `flutter build apk --debug`, `mvnw.cmd -B verify` (`15/15`), `validate_content.py`, `check-licenses.py` e `docker compose config` verdi. *Dipende da: PR-M2-04..06.* |

---

### 2.2 Dettaglio file promossi, adattamenti ed esclusioni per ramo

#### Da `proto/sp-02` (E2EE, Auth dispositivo, Pairing, Recovery, Sync)
- **Da promuovere (Client):**
  - `lib/domain/crypto/deep_sky_crypto.dart`
  - `lib/domain/crypto/e2ee_models.dart`
  - `lib/domain/crypto/recovery_key_codec.dart`
  - `lib/data/secure_key_store.dart`
  - `lib/data/couple_api_client.dart`
  - `lib/data/pairing_and_sync_repository.dart`
  - `test/domain/deep_sky_crypto_test.dart`, `test/data/pairing_and_sync_repository_test.dart`
- **Da promuovere (Server):**
  - `server/src/main/java/com/vectevo/deep_sky_server/config/DeviceAuthFilter.java` e aggiornamenti `SecurityConfig.java`
  - `server/src/main/java/com/vectevo/deep_sky_server/shared/` (`DevicePrincipal.java`, `Ed25519SignatureVerifier.java`, `GlobalExceptionHandler.java`)
  - `server/src/main/java/com/vectevo/deep_sky_server/pairing/` (`CoupleEntity.java`, `CoupleRepository.java`, `DeviceAuthLookup.java`, `DeviceEntity.java`, `DeviceRepository.java`, `KeyDeliveryEntity.java`, `KeyDeliveryRepository.java`, `PairingController.java`, `PairingInviteEntity.java`, `PairingInviteRepository.java`, `PairingService.java`, `RecoveryChallengeEntity.java`, `RecoveryChallengeRepository.java`, `RecoveryController.java`, `RequestNonceEntity.java`, `RequestNonceRepository.java`)
  - `server/src/main/java/com/vectevo/deep_sky_server/sync/` (`EncryptedEnvelopeEntity.java`, `EncryptedEnvelopeRepository.java`, `SyncController.java`, `SyncService.java`)
  - `server/src/main/resources/db/migration/V2__sp02_pairing_and_sync.sql`
  - `server/src/test/java/com/vectevo/deep_sky_server/Sp02PairingAndSyncIntegrationTest.java`
- **Adattamenti in M2 (Server):** aggiungere pulizia periodica dei nonce scaduti (`RequestNonceRepository`), rate-limit sulle chiamate pubbliche `invites` e `recovery/challenge`, policy esplicita di versione minima (`F-19`) e test di isolamento `couple_id` (`AD-05`).
- **Adattamenti in M2 (Client & Android):** sostituire la pagina harness `sp02_prototype_page.dart` con UI DS-2; implementare cache locale cifrata per sola lettura offline (`TC-07`, `AD-06`); configurare esplicitamente `android/app/src/main/AndroidManifest.xml` con `android:allowBackup="false"`, `android:dataExtractionRules` e `android:fullBackupContent` (attualmente assenti sia su `development` sia su `proto/sp-02`) per escludere chiavi, keystore preferences e cache dal backup automatico di Google; sottoporre a valutazione **`G-5`** l’adozione di `cryptography_flutter` accanto a `cryptography` (`G5-09`).
- **Esclusi / non promossi:** `lib/presentation/pairing/sp02_prototype_page.dart`, `test/presentation/sp02_prototype_page_test.dart` (sostituiti da UI M2 con Design System DS-2); file generati desktop (`linux/`, `macos/`, `windows/`).

#### Da `proto/sp-01` (Push FCM a runtime)
- **Da promuovere (Android Kotlin & risorsa stringhe):**
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/DeepSkyApplication.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/push/RuntimeFirebaseCoordinator.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/push/DeepSkyFirebaseMessagingService.kt`
  - `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values-it/strings.xml`
  - Unione controllata in `android/app/build.gradle.kts`, `AndroidManifest.xml`, `MainActivity.kt`, `PlatformBridgePlugin.kt`
- **Da promuovere (Client Flutter):**
  - `lib/data/push_api_client.dart`, `lib/domain/push_models.dart`, `test/data/push_api_client_test.dart`
  - Unione controllata di `lib/platform/native_bridge.dart` e `test/platform/native_bridge_test.dart`
- **Da promuovere (Server):**
  - `server/src/main/java/com/vectevo/deep_sky_server/config/PushConfiguration.java`
  - `server/src/main/java/com/vectevo/deep_sky_server/push/` (`FcmHttpV1PushProvider.java`, `NoopPushProvider.java`, `PushConfig.java`, `PushController.java`, `PushDtos.java`, `PushRegistrationEntity.java`, `PushRegistrationRepository.java`, `PushService.java`, `PushTokenUnregisteredException.java`, `ServiceAccountTokenProvider.java`)
  - `server/src/main/resources/db/migration/V2__sp01_push_tokens.sql` (**da rinominare `V3__push_registrations.sql`**)
  - `server/src/test/java/com/vectevo/deep_sky_server/Sp01PushIntegrationTest.java`, `server/src/test/java/com/vectevo/deep_sky_server/push/Sp01FcmHttpClientTest.java`
- **Adattamenti in M2:** proteggere `POST /api/v1/push/register` e l’invio push con `DeviceAuthFilter` (rimuovendo l’apertura temporanea da prototipo); inviare risveglio `thinking_of_you` al solo partner non revocato in occasione di nuovi eventi in `SyncService`.
- **Esclusi / non promossi:** `lib/presentation/push/sp01_prototype_page.dart`, `test/presentation/sp01_prototype_page_test.dart`.

#### Da `proto/sp-04` (Home ibrida, animazioni livello 1, override asset)
- **Da promuovere (Client Flutter):**
  - `lib/scene/scene_manifest.dart`
  - `lib/data/scene_manifest_parser.dart`
  - `lib/scene/asset_override_registry.dart`
  - `lib/scene/hybrid_scene_canvas.dart`
  - `test/scene/hybrid_scene_test.dart`
- **Adattamenti in M2:** caricare pacchetto pilota **DS-2** (evolvendo o sostituendo `content/packs/sp04_room/`); collegare gli slot e il badge stato/pensiero agli eventi reali decifrati da `SyncController`.
- **Esclusi / non promossi:** `lib/presentation/home/sp04_hybrid_home_page.dart` (usare solo come riferimento di layout finché non sostituita dalla Home M2).

#### Da `proto/sp-03` (Aggiornatore APK da release GitHub / canale configurabile)
- **Da promuovere (Android Kotlin & Flutter):**
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/installer/ApkInstallerCoordinator.kt`
  - `android/app/src/main/kotlin/com/vectevo/deep_sky/platform/installer/InstallResultReceiver.kt`
  - `lib/data/apk_update_service.dart`, `lib/domain/update/apk_update_models.dart`, `test/data/apk_update_service_test.dart`
  - Unione in `PlatformBridgePlugin.kt`, `AndroidManifest.xml`, `lib/platform/native_bridge.dart`
- **Adattamenti in M2:** collegare il controllo versione minima imposto dal server (`F-19`) alla schermata bloccante “aggiornamento richiesto” e automatizzare il check periodico discreto verso le release GitHub con caching HTTP condizionale (`ETag` / frequenza controllata, `Considerazioni tecniche` 8.2).
- **Esclusi / non promossi:** `lib/presentation/update/sp03_prototype_page.dart`.

#### Da `proto/sp-05` (Configurazione memoria e profili runtime)
- **Da promuovere (Deploy & Documentazione):**
  - Configurazioni JVM / Compose raccomandate da `deploy/docker-compose.sp05.yml` integrate in `deploy/docker-compose.yml` e `deploy/.env.example` (mantenendo i parametri validati da `ADR-0009`).
  - Mantenimento opzionale di `scripts/benchmark_sp05.py` e `deploy/docker-compose.sp05.yml` come strumenti di verifica stress/capacità per i self-hoster.
- **Esclusi dalla build/migrazione di produzione:** `server/src/main/resources/db/migration/V2__sp05_benchmark.sql` e `Sp05BenchmarkController.java` (se conservati per test di carico futuri, confinarli rigorosamente fuori dal classpath/schema di produzione o sotto profilo `benchmark` isolato).

---

## 3. Fette e criteri di uscita di M2 (`G-2`)

In aggiunta alla checklist del [Piano di sviluppo](development-plan.md) cap. 6.3, M2 termina positivamente quando:

- [x] Tutte le PR `PR-M2-01`–`PR-M2-07` sono unite su `development` con suite locali/CI verdi (Flutter `33/33` + APK debug, Spring Boot + Testcontainers PostgreSQL 17 `15/15`, ArchUnit, `validate_content.py`, `check-licenses.py`, `docker compose config`).
- [x] Verifiche hardware residue da M1 (`SP-01` app chiusa/riavvio/Doze, `SP-02` usability non-tech, `SP-03` upgrade real-phone) eseguite e registrate su telefoni fisici.
- [x] Due telefoni Android reali completano pairing (`F-01`), recupero/nuovo dispositivo (`F-20`), scambio del gesto cifrato “ti penso” (`F-03`) via `https://deepsky.vectevo.com` con notifica generica (`S-02`).
- [x] Un aggiornamento firmato offline via release GitHub riesce due volte di fila sui telefoni reali (`F-19`, `PD-06`).
- [x] Modalità offline testata in sola lettura con disattivazione gentile delle scritture (`TC-07`, `V-08`) — *verificata nei test automatizzati (`deep_sky_e2e_flow_test.dart`, `pairing_and_sync_repository_test.dart`); resta la conferma su dispositivi reali*.
- [ ] **Esclusione dal backup automatico di Android verificata (`AD-06`, Architettura `7.1`):** `AndroidManifest.xml` imposta `android:allowBackup="false"`, `@xml/backup_rules` e `@xml/data_extraction_rules` (applicato in `PR-M2-04`); resta la verifica su dispositivo reale che backup automatico di Google, `adb backup` e trasferimenti D2D non ripristinino chiavi, `SharedPreferences` o cache locale (recupero solo via Recovery Key `F-20` o altro telefono).
- [x] **Libreria crittografica (`cryptography` vs `cryptography_flutter`):** richiesta di valutazione tecnica preparata per il revisore di sicurezza (`G5-09`) in `docs/adr/0010-g5-09-cryptography-timing-evaluation.md` sul rischio di attacchi di temporizzazione con esecuzione in Dart puro e decisione differita a `G-5`.
- [ ] Prova completa di backup e ripristino su VM OCI superata (`docs/backup-restore.md`, `scripts/verify-backup-restore.sh`, `G-2`).
