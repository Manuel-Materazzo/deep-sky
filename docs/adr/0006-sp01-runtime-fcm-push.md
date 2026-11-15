# ADR-0006: Runtime-Configured FCM Push Notifications (`SP-01`)

- **Status:** Accepted (`AR-10` frozen; verified on real Android hardware across foreground, background, task-switcher-closed, reboot, and Doze)
- **Date:** 2026-11-15 (proposed 2026-11-14)
- **Reference IDs:** `S-02`, `TC-04`, `AD-04`, `AR-10`, `SP-01`

## Context

The public Android repository and distributed APKs must contain no Firebase credentials (`TC-04`, `AD-04`), meaning `google-services.json` and the `com.google.gms.google-services` Gradle plugin cannot be used. Furthermore, wakeup notifications must carry zero couple content (`S-02`) and still display localized text when the app was dismissed from the Android task switcher or after device reboot.

## Decision

The prototype on branch `proto/sp-01` implements the architecture documented in `docs/sp-01-runtime-fcm.md`:

- **Runtime Initialization Without `google-services.json`:** Public `FirebaseOptions` (`projectId`, `apiKey`, `appId`, `senderId`) are fetched from `GET /api/v1/push/config`, applied via `RuntimeFirebaseCoordinator`, and persisted to Android `SharedPreferences`. Crucially, `DeepSkyApplication.onCreate()` invokes `ensureInitializedFromStorage()` so FCM background cold-starts initialize `FirebaseApp` and the notification channel even when `MainActivity` is never created.
- **Server-Side FCM HTTP v1 Without `firebase-admin` Bloat:** `ServiceAccountTokenProvider` mints RS256 OAuth2 assertions directly using JDK 25 `java.security.Signature` from a runtime `serviceAccountFile`, and `FcmHttpV1PushProvider` posts data-only high-priority payloads containing only `{ "l10nKey", "event": "wakeup", "ts" }` — omitting any `notification` block so the client always renders device-localized strings (`S-02`).
- **Token Hygiene:** HTTP `404 UNREGISTERED` responses from FCM trigger `PushTokenUnregisteredException` and immediately delete the stale row from `push_registrations`.

## Alternatives Considered

- **UnifiedPush / persistent SSE foreground service (`AR-10` fallback):** Higher user setup friction or battery overhead on stock Android; kept documented as Plan B if real-device matrix reveals unacceptable FCM suppression.
- **`com.google.firebase:firebase-admin` server SDK:** Pulls a heavy transitive dependency tree into Spring Boot; JDK RS256 + `RestClient` keeps footprint small for `SP-05`.

## Consequences

- **Verified in M1 (`G-1` closure):** Automated tests (`Sp01FcmHttpClientTest`, `Sp01PushIntegrationTest`, `ArchitectureTest`, `11/11` Flutter tests, debug APK build) plus promoter verification of foreground and background notification delivery (`docs/m0-m1-operative-plan.md`).
- **Verified in M2 on physical hardware (`AR-10` frozen, 2026-11-15):** Real-device end-to-end verification completed across foreground, background, task-switcher swipe-dismissed state, post-reboot, and Doze / Battery Saver; runtime `DeepSkyApplication.onCreate()` initialization via `ensureInitializedFromStorage()` delivers localized generic wakeup notifications reliably without `google-services.json`, so Plan B (`PushProvider` -> UnifiedPush / dedicated build) is **not** activated (`AR-10` closed with runtime FCM). As expected under Android OS rules, explicit Settings *Force Stop* suspends delivery until the user reopens the app.
