# Deep Sky: Project Audit, 2026-11-21

- **Branch:** `development` @ `03d5c32`
- **Status:** Completed (non-protocol-changing items): `AU-01`, `AU-02`, `AU-04`..`AU-28` fixed & verified in automated tests (`AU-08`, `AU-29` physical device checks pending `G-3a`; `AU-03` requires an ADR + promoter approval per §8; `AU-30` & `AU-31` are informational design items).
- **Scope:** whole repository (server, Flutter client, Android native, deploy, CI, scripts, content pipeline).
- **Method:** the initial review was a manual, read-only code review (no builds, tests or tools were run); the fixes were later verified by the automated tests listed per item. Every finding comes from reading the code. Findings marked **Verify** depend on platform behaviour that should be checked on a device or a running stack before acting.
- **Relation to earlier work:** this audit follows `docs/code-audit-2026-11-16.md` (`CA-xx`). It concentrates on the areas that audit did not cover (UI and enrollment flows, scene, repository, API client, local cache, CI, scripts, Android bridge) and on the code added since then: the S3-2 content packs and blobs, and the CA-01/CA-02 fixes. New IDs use the prefix `AU-`.

---

## 1. Summary

The codebase is careful overall. Security reasoning is documented, it uses mature crypto primitives, error responses are uniform, the auth filter checks signature, timestamp and nonce, and pack verification is defence-in-depth. Most `CA-xx` fixes are in place.

The most important new issues:

1. **OTA content-pack updates cannot work in production (AU-01).** The server's device-auth filter rejects the unsigned requests the client sends for `/api/v1/content/pack/**`. The controller test bypasses the security filters, so CI stays green.
2. **Epoch rotation can permanently lock a couple out (AU-02).** The new Recovery Key and epoch secret live only in memory until the revoke call returns. A crash, kill or timeout after the server commits loses them for good.
3. **The server controls device membership (AU-03).** A malicious server can add a "phantom" device. Rotations then wrap fresh keys to that device, or it can push server-chosen keys to a client. This undermines `S-01` (the operator cannot read content), which the earlier audit put in scope.
4. **One bad envelope breaks the whole timeline (AU-04),** and every sync re-downloads and re-encrypts the full history (AU-05).
5. **No client-side HTTP timeouts (AU-06),** so the offline fallback built on `TimeoutException` never triggers on stalled connections.

| Severity | Count |
| :-- | :-- |
| High | 3 |
| Medium | 12 |
| Low / Info | 16 |

---

## 2. High severity

### AU-01: Content-pack endpoints are rejected by `DeviceAuthFilter` (OTA graphics broken) — **FIXED**

- **Status:** Fixed (`PublicRoutes` single source of truth shared by `SecurityConfig` and `DeviceAuthFilter`; verified by `PublicRoutesWebMvcTest` through the real security filter chain).

- **Where:**
  - `server/.../config/DeviceAuthFilter.java:44-63` (`shouldNotFilter`)
  - `server/.../config/SecurityConfig.java:37` (`permitAll` for `/api/v1/content/pack/**`)
  - `lib/data/content_pack_service.dart:454-487, 578-582` (unsigned `GET`s)
  - `server/src/test/.../content/ContentPackStoreAndControllerTest.java:58` (`MockMvcBuilders.standaloneSetup`)
- **Problem:**
  - `SecurityConfig` marks the content-pack routes `permitAll()`, but `DeviceAuthFilter.shouldNotFilter` only exempts `/system/compatibility`, `/push/config`, and the public pairing and recovery `POST`s.
  - Every `GET /api/v1/content/pack/checksums|checksums.sig|files/**|blobs/**` therefore runs through `doFilterInternal`. With no `X-Device-Id`/`X-Signature` headers, it returns `401 Missing device authentication headers`.
  - The client sends only version headers.
- **Impact:**
  - `syncFromServer` throws `networkError` on every attempt.
  - The background check swallows it silently. The manual "Aggiorna grafiche" action shows a network error.
  - The whole S3-2 OTA path is dead in production.
  - It is not caught because the controller test uses `standaloneSetup` without the security filter chain.
- **Fix:**
  - Add `GET` on `/api/v1/content/pack/` (prefix) to `shouldNotFilter`. Ideally derive both lists from one shared constant, so `SecurityConfig` and the filter cannot drift apart again.
  - Add a `@WebMvcTest`/`@SpringBootTest` case that requests each content-pack route **through the security chain** with no auth headers and expects `200/304/404`.
- **Acceptance:** that test passes. A manual `curl` against the compose stack returns the checksums.

### AU-02: Epoch rotation is not crash-, kill- or timeout-safe and can lose the new Recovery Key — **FIXED**

- **Status:** Fixed (write-ahead `deep_sky.pending_rotation.v1` in `SecureKeyStore` before server call + `reconcilePendingRotation()` on error, startup, and sync; verified by `pairing_and_sync_repository_test` drop-after-commit & restart test).
- **Follow-up fix (review):** (1) promotion now requires `currentKeyEpoch == targetEpoch` and no `EPOCH_ROTATION` delivery at that epoch addressed to this device (`pendingDelivery == null` or `keyEpoch < targetEpoch`): the server returns the latest delivery even if already delivered, so the old check discarded valid pending keys on any device that had ever received a rotation. A server-side recovery-key field was not added because API contract changes need an ADR (`CONTRIBUTING.md`). (2) `revokeDevice` first resolves any pending record (definitive server answer required), never overwrites it, throws `PendingRotationUnresolvedException` if still unknown, and returns the committed result when retrying the same target. (3) Rotation and reconcile are serialized by an in-repository mutex, and a transient network error never deletes the pending record. Tests: `AU-02 follow-up` group in `pairing_and_sync_repository_test`.

- **Where:** `lib/data/pairing_and_sync_repository.dart:695-808` (`revokeDevice`), server `PairingService.applyEpochRotation` (`:507-587`).
- **Problem:**
  - `revokeDevice` generates `newRecoverySeed` and `newEpochSecret` in memory, sends them to the server (`:782`), and only persists them locally afterwards (`:806`).
  - The server then switches `recovery_auth_public_key` to the new key and bumps `current_key_epoch`.
  - The initiating device is explicitly excluded from receiving an `EPOCH_ROTATION` delivery (`"Cannot target initiating device"`).
- **Failure scenarios:**
  - The app is killed or crashes, or the OS reclaims it, between the server commit and `saveIdentity`.
  - Much more likely: the response is lost (mobile network drop, proxy timeout) after the server committed. The client sees an exception and discards the new keys.
  - In both cases:
    - The initiator is left on epoch N. It can no longer upload (`STALE_KEY_EPOCH`), and `_syncEpochFromServer` finds no delivery for it.
    - The **old** Recovery Key no longer matches the server, so recovery is refused.
    - In the most common real case (one surviving phone revokes the partner's lost phone), no other device holds the new seed. The couple **permanently loses** access to new content and to recovery.
- **Fix (write-ahead):**
  1. Before calling the server, persist a `pendingRotation` record (target epoch, new seed, epoch secrets) in `SecureKeyStore`.
  2. On success, promote it to the identity and delete the record.
  3. On any error, and at every app start, reconcile: if `GET /pairing/epoch-rotations/me` reports `currentKeyEpoch == pending.targetEpoch` and the server recovery key matches the pending seed, adopt the pending keys. Otherwise discard them.
  - Optionally let the server also store an `EPOCH_ROTATION` delivery to the initiator itself (wrapped to its own KEM key), so the server becomes a recovery path.
- **Acceptance:** a test that throws after the server mock commits but before the response is returned (and a "restart" test) ends with the initiator on epoch N+1 holding the new seed.

### AU-03: Device membership is server-authoritative ("phantom device" key capture) — **OPEN (requires ADR & promoter approval)**

- **Status:** Open — protocol-changing item requiring an ADR and promoter approval per §8 before implementation.

- **Where:**
  - `pairing_and_sync_repository.dart:706-717` (rotation recipients taken from `GET /pairing/devices`)
  - `:823-844` (`_syncEpochFromServer` takes the sender's KEM key from the same list)
  - Server: `approved_at` is set purely server-side (`PairingService.storeKeyDelivery`).
- **Problem:**
  - The SAS (CA-01) authenticates only the *initial* pairing or enrollment peer. After that, the client trusts the server's device list for:
    - which devices must receive new epoch keys on rotation, and
    - which KEM public key to use when unwrapping a received rotation bundle.
  - A malicious or compromised server (in scope per `S-01`) can:
    1. insert a phantom device with the operator's KEM key and `approved = true`. The next legitimate rotation wraps the new recovery seed and all epoch secrets to it, because the server demands a delivery for every active approved device.
    2. or deliver an `EPOCH_ROTATION` package "from" a phantom device carrying operator-chosen secrets. The victim adopts them via `_syncEpochFromServer`, and the operator can read everything written afterwards.
  - Only the label in Settings might reveal the phantom device.
- **Fix (needs an ADR, protocol change):**
  - Keep a client-side **pinned set of verified device keys** (TOFU from SAS-verified pairing or enrollment, plus keys introduced by an already-pinned device through a signed "device added" statement).
  - Wrap rotation keys only to pinned devices.
  - Accept rotation bundles only from pinned senders. Have the sender sign the delivery with its Ed25519 auth key, bound to `(coupleId, from, to, epoch)`.
  - Surface unknown devices in the UI as unverified.
- **Acceptance:** a test where a mock server injects an extra approved device shows that (a) a rotation does not wrap to it and (b) a bundle "from" it is rejected.

---

## 3. Medium severity

### AU-04: A single undecryptable envelope breaks sync for the whole couple — **FIXED**

- **Status:** Fixed (per-envelope `try/catch` quarantine with epoch-sync retry in `PairingAndSyncRepository.fetchAndDecryptEvents` + calm localized `unreadableEnvelopesNotice` in `DeepSkyController`; verified by `pairing_and_sync_repository_test`).
- **Follow-up (review):** the persisted sync cursor never advances past the lowest quarantined `seq`, so quarantined envelopes are retried after an app restart (test: `AU-04: quarantined envelope is retried after app restart`).

- **Where:** `pairing_and_sync_repository.dart:559-567` (`fetchAndDecryptEvents`), `:606-631`.
- **Problem:**
  - Any envelope that fails to decrypt throws out of the loop and aborts the whole sync. Causes include a missing epoch secret, a buggy older client, corrupted data, or a hostile partner device or server.
  - Because the controller always syncs from `afterSeq = 0` (see AU-05), the failure repeats on every refresh, so the timeline never updates again.
  - Only `SocketException`/`ClientException`/`TimeoutException` fall back to the cache. A `SecretBoxAuthenticationError` or `FormatException` surfaces as a raw error.
- **Fix:**
  - Decrypt per envelope with `try/catch`. Collect failures into a quarantined list (envelope id, seq, reason) and keep processing.
  - Show a calm "some items could not be read" notice. Retry quarantined items after the next epoch sync.

### AU-05: Every sync re-downloads the full history and rewrites the whole cache in secure storage — **FIXED**

- **Status:** Fixed (`EncryptedLocalCache` persists `lastSeq` & `lastEpoch`, caps stored events to 500, and writes atomically to an encrypted file in app-private storage via `getOfflineCacheRootDir` instead of `flutter_secure_storage`; `PairingAndSyncRepository.syncEventsWithOfflineFallback` syncs incrementally with `afterSeq = lastSeq`; verified by `pairing_and_sync_repository_test`).

- **Where:** `deep_sky_controller.dart:433` → `syncEventsWithOfflineFallback()` → `fetchAndDecryptEvents(afterSeq: 0)`; `couple_api_client.dart:535-558` (loops over all pages); `encrypted_local_cache.dart:73-99` (single value under `deep_sky.offline_cache.v1`).
- **Problem:**
  - No sync cursor is persisted. Each refresh (start, pull-to-refresh, after every send) downloads, decrypts and re-encrypts **all** envelopes.
  - The result is written as one JSON blob into `flutter_secure_storage`, which on Android is a SharedPreferences value loaded whole into memory.
  - With the 1 GB per-couple quota this grows without bound: data usage, battery, start latency, and eventually storage or OOM failures.
- **Fix:**
  - Persist `lastSeq` (and the epoch) next to the cache and request `afterSeq = lastSeq`.
  - Move the cache to an encrypted file or database (for example per-record AEAD in `getApplicationSupportDirectory`), with the key-encryption key kept in secure storage.
  - Cap or window what is kept locally.

### AU-06: No timeouts on client API calls; the offline fallback depends on them — **FIXED**

- **Status:** Fixed (`requestTimeout` / `uploadTimeout` / `chunkIdleTimeout` added across `CoupleApiClient`, `ContentPackService`, and `ApkUpdateService`; verified by `pairing_and_sync_repository_test`, `content_pack_security_test`, and `apk_update_service_test`).

- **Where:** `lib/data/couple_api_client.dart:223-227, 602-659` (no `.timeout`). Only push and native calls have timeouts (`deep_sky_controller.dart:1449,1461`).
- **Problem:**
  - `package:http` has no default timeout. On captive portals, half-open TCP or slow servers, requests can hang for minutes, leaving `busy == true` and a spinner.
  - `syncEventsWithOfflineFallback` catches `TimeoutException`, but nothing throws one.
- **Fix:**
  - Wrap each request in `.timeout()` (for example 15 s for API calls, longer for uploads), or use an `IOClient` with `connectionTimeout`/`idleTimeout`.
  - Apply the same to `ContentPackService` and `ApkUpdateService` downloads, with a per-chunk idle timeout.

### AU-07: Background and manual content-pack updates race and corrupt pack metadata — **FIXED**

- **Status:** Fixed (`ContentPackService` serializes `resolveStartupPack`, `markHomeBootSucceeded`, and `syncFromServer` behind an in-process async lock and re-reads `_PackMeta` inside the lock before committing; `DeepSkyController.forceUpdateContentPack` joins any in-flight startup check; verified by `content_pack_security_test`).

- **Where:** `deep_sky_controller.dart:288` (`unawaited(checkContentPackInBackground())` at start), `:634-692` (`forceUpdateContentPack`); `content_pack_service.dart:416-702`.
- **Problem:**
  - Nothing serialises `syncFromServer`. If the user taps "Aggiorna grafiche" while the start-up check is running:
    - both write the same `staged/<version>` directory, and one may `deleteSync` it under the other;
    - each saves a `_PackMeta` derived from the snapshot it loaded at the start. The background run can overwrite `activeVersion`/`previousVersion` written by the manual run (lost update). On the next boot the active directory no longer matches the metadata, and the app silently falls back to the bundled pack.
- **Fix:**
  - Guard `syncFromServer` and `resolveStartupPack` with a single in-process lock (a `Future` chain or mutex). In the controller, let a manual request join or await an in-flight background check.
  - Re-read the metadata inside the lock before saving.

### AU-08: Sensitive clipboard auto-clear is probably ineffective on Android 10+ (Verify) — **FIXED (code; device check pending `G-3a`)**

- **Status:** Code fixed (`PlatformBridgePlugin.kt` now calls `clearPrimaryClip()` unconditionally on API 28+ when the delayed timer fires and re-checks expired deadlines in `MainActivity.onResume()`; keep `EXTRA_IS_SENSITIVE`; physical device check pending `G-3a`).
- **Note (informational):** the clear now wipes whatever is on the clipboard when the timer fires, even an unrelated later copy. This is an accepted trade-off.

- **Where:** `android/.../platform/PlatformBridgePlugin.kt:168-198`.
- **Problem:**
  - The delayed task clears the clipboard only if `clipboard.primaryClip` still equals the copied text.
  - Since Android 10, `getPrimaryClip()` returns `null` for apps that are not in the foreground (unless they are the default IME).
  - The normal flow is "copy, switch to a messenger, paste", so the app is in the background when the task fires. The check fails and the Recovery Key or invite link stays on the clipboard.
  - The `Handler` delay is also lost if the process is killed.
- **Fix:**
  - On API 28+ call `clearPrimaryClip()` unconditionally when the timer fires, accepting that it may clear an unrelated later copy.
  - Run the check again on `onResume`.
  - Keep `EXTRA_IS_SENSITIVE`.
  - Re-test CA-10's acceptance on a device with the app in the background.

### AU-09: "Private host" detection is a prefix match, so public names can use plain HTTP — **FIXED**

- **Status:** Fixed (`InviteLinkCodec._isLocalOrPrivateHost` now parses strict IPv4/IPv6 literals via `Uri.parseIPv4Address`/`Uri.parseIPv6Address` and never matches DNS prefixes; verified by `invite_link_codec_test`).

- **Where:** `lib/domain/pairing/invite_link_codec.dart:280-294`.
- **Problem:**
  - `lower.startsWith('10.')`, `startsWith('192.168.')` and the `172.16-31.` regex run on the **hostname string**.
  - `http://10.attacker.example`, `http://192.168.evil.com` or `http://172.20.x.example.org` are therefore treated as LAN, and `normalizeServerUrl` accepts plain HTTP for a public host.
  - Combined with a malicious invite link (the custom-server confirmation still shows the host, but it looks "local"), the API traffic, including the unauthenticated pairing responses carrying peer KEM keys, goes over cleartext.
- **Fix:**
  - Use `InternetAddress.tryParse(host)` and allow HTTP only for literal IPs in the RFC 1918, loopback or link-local ranges, plus `localhost`.
  - Never apply this to DNS names.
  - Add unit tests for the cases above.

### AU-10: The server allows revoking another approved device without rotating keys — **FIXED**

- **Status:** Fixed (`PairingService.revokeDevice` rejects revoking another approved device without a rotation body with `409 ROTATION_REQUIRED` via `RotationRequiredException` + `GlobalExceptionHandler`; verified by `PairingServiceUnitTest`).

- **Where:** `PairingController.revokeDevice` (`@RequestBody(required = false)`), `PairingService.revokeDevice:485-500`.
- **Problem:**
  - CA-02's protection depends entirely on the client sending a rotation body. An older client, a bug, or a direct API call can revoke a peer's approved device with no rotation.
  - The revoked device then keeps the current epoch secret, and the server keeps accepting envelopes at that epoch.
- **Fix:** when `target != principal` and the target was approved, require a rotation body (respond `409 ROTATION_REQUIRED` otherwise). Keep self-revocation (unlink) without rotation.

### AU-11: Default Spring profile is `dev` (fail-open configuration) — **FIXED**

- **Status:** Fixed (`application.yaml` defaults to `prod` with Docker Compose and Swagger/OpenAPI disabled by default; `DeepSkyPropertiesValidator` uses `environment.acceptsProfiles(Profiles.of("prod"))`; `server/Dockerfile` sets `ENV SPRING_PROFILES_ACTIVE=prod`; verified by `ProdVisibilityDisabledWebMvcTest` and `DeepSkyPropertiesValidationTest`).

- **Where:** `server/src/main/resources/application.yaml:5` (`spring.profiles.default: dev`), `application-dev.yaml`, `@Profile({"dev","audit","test"})` on the visibility controllers, `DeepSkyPropertiesValidator` (prod checks only when `prod` is active).
- **Problem:**
  - Running the image or jar without `SPRING_PROFILES_ACTIVE` gets all of these:
    - the `/pairing/visibility` and `/sync/visibility` audit endpoints;
    - Swagger UI and the OpenAPI docs;
    - `spring.docker.compose.enabled=true`;
    - no production validation of the domain or admin secret.
  - `deploy/docker-compose.yml` sets `prod`, but `docker run ghcr.io/.../deep-sky-server` or a hand-written compose file does not.
- **Fix:**
  - Make the safe profile the default: no default, or `prod`, and have developers opt into `dev`.
  - Or invert the logic and enable the audit endpoints only when an explicit `deepsky.audit.enabled=true` is set.
  - Set `ENV SPRING_PROFILES_ACTIVE=prod` in the `Dockerfile`.

### AU-12: FCM and OAuth HTTP calls have no timeouts; the client-wakeup path holds a DB transaction during FCM I/O — **FIXED**

- **Status:** Fixed (`PushConfiguration` configures `JdkClientHttpRequestFactory` with 5s connect / 8s read timeouts; `ServiceAccountTokenProvider` uses single-flight `CompletableFuture` refresh outside monitor locks; `PushService.dispatchClientWakeup` & `dispatchPartnerWakeup` no longer wrap FCM I/O in `@Transactional`, and client wakeups publish `PartnerWakeupRequestedEvent` asynchronously; verified by `SyncAndPushAuditUnitTest` & `Sp01FcmHttpClientTest`).
- **Note (informational):** `POST /push/wakeup` now returns 0 counts because dispatch is asynchronous; the client does not use them.

- **Where:** `config/PushConfiguration.java:46` (`RestClient.create()`), `push/ServiceAccountTokenProvider.java:72` (`synchronized getAccessToken()` doing HTTP), `push/PushService.java:146` (`@Transactional dispatchClientWakeup` calling `dispatchPartnerWakeup` → `pushProvider.sendWakeup`).
- **Problem:**
  - The default `RestClient` request factory has no read timeout.
  - A stalled call to `oauth2.googleapis.com` blocks every push thread on the `synchronized` method.
  - A stalled FCM call ties up the bounded `@Async` pool and, for `/push/wakeup`, a request thread **and** a pooled DB connection (the CA-07 pattern on the client-triggered path).
- **Fix:**
  - Build the `RestClient` with a request factory that has connect and read timeouts of a few seconds.
  - Refresh the OAuth token outside the lock, or with a single-flight future.
  - Make `dispatchClientWakeup` publish a `PartnerWakeupRequestedEvent` (after commit, async) instead of sending inline.

### AU-13: Release builds silently fall back to the debug signing key — **FIXED**

- **Status:** Fixed (`android/app/build.gradle.kts` now supports `android/key.properties` or `DEEPSKY_KEYSTORE_*` env vars, honors `-Punsigned=true`, and fails release build tasks if neither is configured instead of falling back to the debug key).

- **Where:** `android/app/build.gradle.kts:28-32`.
- **Problem:**
  - Any `flutter build apk --release` without `-Punsigned=true` is signed with the developer's local debug keystore.
  - If such an APK is ever distributed (a manual build or a test hand-off), devices that install it pin the update path to the debug key. The installer's certificate check then rejects the real release, and the reverse also holds.
- **Fix:** for `release`, fail the build unless either `-Punsigned=true` or a proper signing config (from environment variables or a `key.properties` that is not committed) is provided.

### AU-14: No request-body size limit on unauthenticated endpoints — **FIXED**

- **Status:** Fixed (`deploy/Caddyfile` adds `request_body { max_size 2MB }`; `RequestBodySizeLimitFilter` enforces 64 KiB on public `/api/v1/**` routes and 1 MiB across all `/api/v1/**` via both `Content-Length` and bounded stream wrapper; verified by `PublicRoutesWebMvcTest`).

- **Where:** `deploy/Caddyfile` (no `request_body`), the public `POST`s in `PairingController`/`RecoveryController` (not covered by the 1 MiB cap in `DeviceAuthFilter:117`), JVM heap `-Xmx256m`.
- **Problem:** Jackson reads the full JSON body of `POST /pairing/invites`, `/invites/accept` and `/recovery/*` before validation. Rate limits allow 5 to 20 requests per minute per IP. A handful of multi-MB bodies from a few IPs can push a 256 MB heap into `ExitOnOutOfMemoryError` restarts.
- **Fix:** add `request_body { max_size 2MB }` in Caddy, and in Spring cap the body for all `/api/v1/**` (a filter that rejects `Content-Length > N` and wraps the stream with a limit).

### AU-15: Content-pack transfer is fully buffered, and the server can serve bytes that no longer match the ETag — **FIXED**

- **Status:** Fixed (client streams blobs via `http.Client.send` with per-chunk idle timeout and aborts immediately when `received > entry.sizeBytes`; server streams files via `FileSystemResource`, verifies disk size & mtime/SHA-256 against the verified snapshot returning `500` on in-place tampering, and `docs/server-configuration.md` documents atomic `current` symlink swap publishing; verified by `ContentPackStoreAndControllerTest` and `content_pack_security_test`).

- **Where:**
  - Client: `content_pack_service.dart:578-596` (`fileResp.bodyBytes` is checked against `entry.sizeBytes` only after the full download).
  - Server: `ContentPackController.java:145` (`Files.readAllBytes` per request).
  - `ContentPackStore` verifies hashes only at load and reload time.
- **Problem:**
  1. A malicious or broken server can stream an arbitrarily large body for a blob, and the client buffers all of it before rejecting it (OOM on low-RAM phones).
  2. On the server, files are re-read from disk on every request. If an operator edits files in place, the served bytes differ from the verified SHA-256 while `ETag` and `Cache-Control: immutable` still advertise the old hash. Intermediate caches can then pin bad bytes for a year. The client rejects them, so updates fail until the cache entry expires.
  3. Concurrent downloads each allocate whole-file `byte[]`s on a 256 MB heap.
- **Fix:**
  - Client: use `http.Client.send` with streaming and abort once more than `sizeBytes` bytes have been read.
  - Server: serve with `FileSystemResource`/`InputStreamResource` (streaming), and either keep verified bytes in memory (packs are small) or re-hash while streaming and return 500 on mismatch.
  - Document that packs must be published by atomically swapping the `current` symlink, never edited in place.

---

## 4. Low severity and info

| ID | Status | Finding | Where | Suggested fix |
| :-- | :-- | :-- | :-- | :-- |
| AU-16 | **Fixed** (`DeviceAuthFilter`, `CoupleApiClient`, `DeepSkyController`, `SecurityApprovalWebMvcTest`) | Revocation is detected by substring match on the 401 message (`'revoked'`/`'unknown'`). The uniform message also covers "invalid signature", so a proxy that rewrites the path, or a canonical-form bug, is reported as "device revoked". `completeJoinDelivery` then **wipes the joining identity** (`deep_sky_controller.dart:1129-1131`). A clock skew over 5 minutes shows a raw English error. | `couple_api_client.dart:16-22`, `DeviceAuthFilter` | Return stable error codes (`DEVICE_AUTH_FAILED`, `CLOCK_SKEW`, `AUTH_HEADERS_INVALID`, `NONCE_REPLAYED`) without weakening the uniform message. Show a localized "check your phone's clock" hint. Do not wipe the identity on an ambiguous 401. |
| AU-17 | **Fixed** (`DeepSkyController._friendlyErrorMessage`, `DeepSkyStrings`, `PairingAndSyncRepository`) | Raw exception text reaches the UI (`errorNotice = error.toString()`). Some strings are English-only or developer-facing, and one embeds the **invite token** (`'Missing out-of-band SAS secret for invite $inviteToken'`), which can end up in screenshots or bug reports. | `deep_sky_controller.dart:1771,1774`, `pairing_and_sync_repository.dart:213` | Map exceptions to localised `DeepSkyStrings`. Never interpolate tokens or secrets into exception messages. |
| AU-18 | **Fixed** (`DeepSkyApp`, `DeepSkyController.syncOnResumeSilently`, `NativeBridge`, `PlatformBridgePlugin.kt`, `DeepSkyFirebaseMessagingService.kt`) | The app does not sync on resume, and an FCM wakeup received while the app is open does not trigger a sync (data-only messages go to the native service). The scene shows stale partner state until pull-to-refresh. | `deep_sky_app.dart:40-45`, `DeepSkyFirebaseMessagingService` | On `resumed`, call a throttled silent sync. Forward wakeups to Dart over the method channel when the engine is attached. |
| AU-19 | **Fixed** (`ContentPackService._pruneUnusedPackDirs`, `content_pack_security_test`) | Pack directories leak: moving `active → previous` only replaces a `previous/` folder of the *same* version, so older `previous/<v>` folders are never deleted. Blob GC treats every file under `previous/` as referenced. Each file is also stored twice (in `blobs/` and in the pack directory). | `content_pack_service.dart:279-288, 661-668, 706-749` | Delete everything in `previous/` except `meta.previousVersion`, and everything in `staged/` except `meta.stagedVersion`. |
| AU-20 | **Fixed** (`PairingCleanupService.purgeUnpairedCouples`, `CoupleRepository`, `V6__stored_bytes_and_cleanup_indexes.sql`, `docs/server-configuration.md`) | No data-retention policy: after `unpair`, ciphertext, devices, key deliveries and push rows stay forever. Couples where the joiner was never approved (so the joiner device was revoked by cleanup) are never purged, because the orphan query needs exactly one device. | `PairingService.unpairCouple`, `CoupleRepository.findOrphanNeverPairedCoupleIds` | 30-day retention window after `unpaired_at` with full child-table purge; orphan query extended to couples with revoked never-approved joiners. |
| AU-21 | **Fixed for (a)-(c); (d) is documented, not changed** (`V6__stored_bytes_and_cleanup_indexes.sql`, `CoupleRepository.tryReserveStorageBytes`, `DeviceAuthLookup`, `SyncService`, `SyncServiceUnitTest`, `docs/server-configuration.md`) | Quota and size checks: (a) sum-then-insert is not atomic, so parallel uploads can exceed the quota; (b) `SUM(octet_length)` over the whole couple on every upload is O(n); (c) `keyEpoch` greater than the couple's current epoch is accepted; (d) `max-blob-bytes` (10 MiB) cannot be reached because `DeviceAuthFilter` caps bodies at 1 MiB (about 750 KiB of ciphertext after base64). | `SyncService.storeEnvelope:103-143`, `DeviceAuthFilter:34` | Atomic `stored_bytes` counter on `couples`; reject `keyEpoch > current`; effective envelope cap documented. |
| AU-22 | **Fixed** (`PushDtos.RegisterTokenRequest`, `SecurityApprovalWebMvcTest`) | `RegisterTokenRequest.platform` has no length check (column `VARCHAR(16)`), so a longer value causes a constraint error and a 500. `fcmToken` is unbounded. | `PushDtos.RegisterTokenRequest`, `V3__push_registrations.sql` | Added `@Size(max = 16)` on `platform` and `@Size(max = 4096)` on `fcmToken`. |
| AU-23 | **Fixed** (`PushService.consumeClientWakeupQuota`, `PairingService`, `PairingServiceUnitTest`, `docs/server-configuration.md`) | In-memory limiters: `PushService.clientWakeupWindows` is an unbounded map. Anyone who knows a couple's recovery **public** key can use up its per-couple recovery bucket and block a real recovery for 15 minutes. All limits reset on restart and do not work across multiple instances. | `PushService`, `PairingService.createRecoveryChallenge:610` | Prune `clientWakeupWindows` when large; count per-couple recovery limit only on invalid-signature `completeRecovery` failures; documented single-instance deployment constraint. |
| AU-24 | **Fixed** (`DeepSkyController.acquireSecureScreen`/`releaseSecureScreen`, `content_pack_security_test`) | `FLAG_SECURE` is toggled per page with no reference counting. Popping a secure page that sits on top of another secure page (for example the recovery or verification page over the welcome invite panel) clears the flag while sensitive content is still visible. | `code_verification_page.dart:32`, `recovery_key_setup_page.dart:33`, `welcome_invite_panel.dart:60` | Reference-counted `setSecureScreen` in `DeepSkyController`. |
| AU-25 | **Partially fixed; exclusions recorded** (`.github/workflows/release.yml`, `docs/audit-exclusions.md`) | CI and supply chain: (a) CI runs only for `master`, while daily work happens on `development`; (b) `release.yml` interpolates `${{ inputs.* }}` directly into `run:` scripts (script injection by anyone allowed to dispatch); (c) third-party actions are pinned by tag, not SHA; (d) the release pushes `:latest` without running server tests, and `deploy/.env.example` defaults to `:latest`. | `.github/workflows/*.yml`, `deploy/.env.example` | Passed `release.yml` inputs via `env:` with regex validation and added `./mvnw -B verify` before pushing the server image. Per `docs/audit-exclusions.md`, (a) `development` CI trigger and (d) version-pinning as default in `deploy/.env.example` are intentionally excluded. |
| AU-26 | **Fixed** (`deploy/Caddyfile`, `deploy/web/join/index.html`) | Web hardening: Caddy sets no HSTS, and the join page has no CSP or `frame-ancestors`. The join page copies the full link, including `token` and `sas`, to the clipboard without the sensitive flag (the browser cannot set it), and shows it in clear text. | `deploy/Caddyfile`, `deploy/web/join/index.html:271-293` | Added HSTS, `X-Frame-Options: DENY`, and strict CSP on `/join*`; masked preview box, copy `deepsky://pair#…` only, and added clipboard-clear reminder. |
| AU-27 | **Fixed** (`PairingService`, `PairingServiceUnitTest`) | `fetchPendingKeyDelivery` falls back to *any* delivery kind, so it can hand an `EPOCH_ROTATION` package to the enrollment path. `storeKeyDelivery` does not check `keyEpoch` against the couple's current epoch. | `PairingService:404-415, 375-382` | Removed fallback (strictly `PAIRING_SEED` only); rejected `keyEpoch ≠ current_key_epoch`. |
| AU-28 | **Documented** (`docs/server-configuration.md`) | `deepsky.admin-secret` is required and validated in prod but nothing uses it. Operators must create and guard a secret that has no effect. | `DeepSkyProperties`, `DeepSkyPropertiesValidator` | Documented explicitly as reserved for future self-hoster operational endpoints (avoiding breaking existing Compose secret mounts). |
| AU-29 | **Verify (`G-3a` device check)** | **Verify:** there is no `network_security_config`/`usesCleartextTraffic`, while the codec allows `http://` for LAN self-hosting. Depending on how the Flutter/Dart networking stack applies Android's cleartext policy at `targetSdk ≥ 28`, LAN HTTP servers may fail in release builds with an unclear error. | `AndroidManifest.xml`, `invite_link_codec.dart` | Test on a release build. If it is blocked, either document HTTPS-only or add a scoped config for private ranges. |
| AU-30 | **Info (protocol / ADR)** | Info: all couple devices share symmetric channel keys, so any device in the couple can write an envelope that claims another `senderDeviceId`. The AAD does not bind `seq`, so the server can reorder or withhold envelopes without detection. | `deep_sky_crypto.dart:500-511` | Accept and document in `ADR-0005`, or add per-device Ed25519 signatures inside the payload when sender attribution matters (for example capsules). |
| AU-31 | **Info (product / ADR)** | Info: any approved device, including a stolen and unlocked phone, can `unpair`. This is irreversible: recovery is refused afterwards and history becomes unreachable. | `PairingService.unpairCouple`, `completeRecovery:653-655` | Consider a grace period (soft unpair, reversible with the Recovery Key for N days) or a confirmation from a second device. |

---

## 5. Status of earlier audit items (spot-checked, not re-verified in full)

| ID | Observation |
| :-- | :-- |
| CA-03 | In place: `SecurityConfig` allows only `key-deliveries/me`, `devices/me` and `invites/status` for unapproved devices. |
| CA-04 | In place: `findByTokenHashForUpdate` / `findByIdForUpdate` (pessimistic lock). |
| CA-05 | In place: token in the body; the Caddy log deletes `request>uri`. |
| CA-07 | Fixed for server-originated events (`@Async @TransactionalEventListener(AFTER_COMMIT)`). **Not** for `/push/wakeup` (see AU-12). |
| CA-08 | Page size is clamped. The client follows pages, but always from `seq 0` (AU-05). |
| CA-10 | `FLAG_SECURE` and the sensitive flag are present. The **clipboard clear is probably ineffective in the background** (AU-08). Nested-page flag handling: AU-24. |
| CA-12 | In place: the limiter uses `remoteAddr` with `forward-headers-strategy: native`. Still depends on Tomcat's default internal-proxy regex trusting the Docker bridge; worth a line in `docs/server-configuration.md`. |
| CA-D2, CA-D4 | Still open, as recorded. |

---

## 6. Test-coverage gaps

- **Security chain vs. route list:** no test runs public routes (content pack, compatibility, push config) through the real filter chain without auth headers. This is how AU-01 slipped through. A single parameterised test over a "public routes" table would cover it.
- **Rotation failure paths:** no test for a lost response or a crash during `revokeDevice` (AU-02), or for a phantom device in `listDevices` (AU-03).
- **Sync robustness:** no test with one corrupted or unknown-epoch envelope among valid ones (AU-04), or with more than 100 envelopes and incremental sync (AU-05).
- **Concurrency:** no test for parallel `syncFromServer` calls (AU-07) or parallel quota uploads (AU-21).
- **Codec edge cases:** add tests for hosts such as `10.example.com` (AU-09).
- **Device checks still pending** from `G-3a`: clipboard in the background, `FLAG_SECURE` across navigation, release-build cleartext.

---

## 7. Improvement areas (non-defect)

- **Server**
  - Serve content-pack files by streaming.
  - Add a `stored_bytes` counter.
  - Add an index on `request_nonces(expires_at)` and `pairing_invites(expires_at)` for the cleanup deletes.
  - Use `clock` consistently. `createInitialInvite`, `acceptInvite` and `storeKeyDelivery` use `Instant.now()`, which makes time-based tests harder.
- **Client architecture**
  - `deep_sky_controller.dart` (about 1,800 lines) and `home_shell_page.dart`/`onboarding_page.dart` (more than 1,100 lines each) mix orchestration, state and strings. Splitting them along the existing boundaries (pairing, sync, content packs, updates, push) would make each flow testable on its own.
  - Hard-coded IT/EN strings inside the controller (for example `:1044`, `:1058`, `:1124`) bypass `DeepSkyStrings`.
- **`_runGuarded`** sets `busy` but does not reject re-entry. The UI mostly disables buttons when busy, but an early return when `busy` is already true would make double-submits impossible, including from deep links and lifecycle callbacks.
- **Operations**
  - Document that the stack must run as a single API instance (in-memory limiters).
  - Document how content packs are published (atomic `current` symlink swap).
  - Ship a `restore` drill that covers the pack volume, not only Postgres.
- **Key custody:** the content-signing and update Ed25519 keys are plain base64 PKCS#8 files passed by path. Consider encrypting them at rest (a passphrase-protected PKCS#8 or a hardware token) to match `docs/key-custody.md`.

---

## 8. Suggested order of work

1. **Now (cheap, high impact):** AU-01 (one-line filter fix plus the test), AU-06, AU-09, AU-11, AU-13.
2. **Before real data (`G-3a`):** AU-02, AU-04, AU-08, AU-10, AU-14, then the ADR and design for AU-03.
3. **Next sprint:** AU-05 (incremental sync and a file-based cache), AU-07, AU-12, AU-15, AU-16, AU-17, AU-18.
4. **When convenient:** AU-19 to AU-31, the test gaps in §6, and the improvements in §7.

Protocol-changing items (AU-02 if the server stores a self-delivery, AU-03, AU-30) need an ADR and promoter approval, following the process in `docs/code-audit-2026-11-16.md` §2.
