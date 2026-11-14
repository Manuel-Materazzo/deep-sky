# ADR-0006: Runtime-Configured FCM Push Notifications (`SP-01`)

- **Status:** Proposed (pending physical-device delivery matrix verification)
- **Date:** 2026-11-14
- **Reference IDs:** `S-02`, `TC-04`, `AD-04`, `SP-01`

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

- **Verified in M1 automation (`proto/sp-01`):** `Sp01FcmHttpClientTest` (RSA JWT signature math verification, token caching, notification-free JSON check, `404 UNREGISTERED` mapping), `Sp01PushIntegrationTest` (Testcontainers PostgreSQL 17), `ArchitectureTest`, Flutter bridge/API/widget tests (`11/11` passed), and Android APK compilation (`flutter build apk --debug`).
- **Remaining physical verification before `G-1`:** Execute the 2-device field matrix (foreground, background, task-switcher swipe-dismissed, post-reboot, long screen-off Doze / Battery Saver, and documented Settings Force Stop suppression) using a promoter-provisioned Firebase project. Activate Plan B (`AR-10`) only if task-switcher-closed delivery fails unacceptably across devices.
