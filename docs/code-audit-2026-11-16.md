# Code Audit, 2026-11-16

- **Status:** In progress (`CA-01`..`CA-14`, `CA-16`, `CA-17`, `CA-19`..`CA-21`, and `CA-D3` implemented & verified in unit/widget/WebMvc/ArchUnit tests; `CA-15` deferred to `S3-3`/`S3-4`; `CA-18` accepted & documented in `ADR-0005`; `CA-D1`, `CA-D2`, `CA-D4` open; DB integration tests await Docker).
- **Date:** 2026-11-16 (branch `development`)
- **Reference IDs:** `S-01`, `S-02`, `S-03`, `S-06`, `S-07`, `P-02`, `P-03`, `AD-01`, `AD-02`, `AD-03`, `G5-01`..`G5-09`, `S1-SEC-01`, `S1-SEC-02`, `G-3a`, `ADR-0004`, `ADR-0005`, `ADR-0006`, `ADR-0008`, `ADR-0010`

## 1. Scope and method

This was a manual, read-only review of the implemented code. **No tests, builds or tools were run.** Findings come from reading the code and have not been reproduced. Each finding gives a file and line to start from; line numbers may drift.

**Reviewed**

- Server: `DeviceAuthFilter`, `SecurityConfig`, `PublicEndpointRateLimiter` and its filter, `ClientCompatibilityFilter`, `PairingService`, `PairingController`, `RecoveryController`, `SyncService`, `SyncController`, `PushService`, `PushController`, `PairingCleanupService`, `DeepSkyPropertiesValidator`, `GlobalExceptionHandler`, Flyway `V2`, `deploy/Caddyfile`, `deploy/docker-compose.yml`.
- Client: `lib/domain/crypto/deep_sky_crypto.dart`, `lib/data/apk_update_service.dart`, `InviteLinkCodec`, the update-check part of `deep_sky_controller.dart`.
- Android: `AndroidManifest.xml`, backup and data-extraction rules, `ApkInstallerCoordinator.kt`, `DeepSkyFirebaseMessagingService.kt`.
- Web: `deploy/web/join/index.html`, `deploy/web/.well-known/assetlinks.json`.

**Not reviewed (follow-up needed)**

- Flutter UI and the enrollment state machine (`presentation/`), including timers, polling, `BuildContext` use across async gaps, and strings in IT/EN.
- Scene code (`lib/scene/`) and the manifest parser.
- `pairing_and_sync_repository.dart`, `couple_api_client.dart`, `encrypted_local_cache.dart`, `secure_key_store.dart`.
- `.github/workflows/*`, `scripts/*` (beyond a grep of the signing scripts), `.githooks`.
- The test suites (coverage and quality).
- Everything behind the `blob` module (the package is empty).

## 2. How to use this document

- Fix in the order of section 7. Items marked **before real data** belong to the `G-3a` gate (`m3-operative-plan.md` ch. 3).
- Each finding has *Acceptance* criteria. Close it only when they are met and the evidence (test name, PR) is recorded in the *Status* column.
- Findings that change a cryptographic format or protocol (`CA-01`, `CA-02`) need an ADR first (`ADR-0001`) and promoter approval (`PD-11`).
- `CA-02` is the design input for task `S1-SEC-02`.

## 3. High severity

| ID | Status | Finding |
| :-- | :-- | :-- |
| CA-01 | Fixed (`ADR-0011`, `deep_sky_crypto_test`, `invite_link_codec_test`, `s3_1_enrollment_flows_test`) | SAS verification can be defeated by a malicious server |
| CA-02 | Fixed (`ADR-0012`, `V5__epoch_key_rotation.sql`, `deep_sky_crypto_test`, `pairing_and_sync_repository_test`, `deep_sky_e2e_flow_test`, `PairingServiceUnitTest`, `SyncServiceUnitTest`) | Key epochs derived from the recovery seed cannot revoke a device |
| CA-03 | Fixed (unit/WebMvc verified; DB integration pending Docker) | A device that has just joined has full privileges before it is approved |

### CA-01: SAS verification can be defeated by a malicious server

- **Where:** `lib/domain/crypto/deep_sky_crypto.dart:134-159` (`computeSasCode`), `PairingService.acceptInvite` (peer keys returned by the server), `ADR-0005`.
- **Problem:**
  - The SAS is 6 digits (about 20 bits) with no commitment step.
  - Each side gets the peer's KEM public key from the server's response, so a server acting as man in the middle chooses both substituted keys after seeing the real ones.
  - It can generate key pairs until `SAS(A, M1)` equals `SAS(B, M2)`. This is a birthday-style search of roughly 2^10 to 2^20 X25519 operations, so it is cheap.
  - The invite token gives no protection, because the server receives it (see `CA-05`).
  - `S-01` says the server operator cannot read content, so the operator is in the threat model.
- **Fix (pick one and document it in an ADR):**
  1. Commitment step: the joiner sends a hash of its KEM key first and reveals the key only after the inviter's key is fixed (ZRTP style).
  2. Mix a secret that never reaches the server (for example one carried only in the QR or link fragment and never sent in an API call) into the SAS HKDF.
  3. At minimum, show a longer comparison value (at least 40 bits, such as a word list or key fingerprint).
- **Acceptance:**
  - A test where a simulated malicious server substitutes keys fails verification on at least one phone, without a brute-force search.
  - `ADR-0005` states the threat model and the chosen SAS design.
  - The UX text is approved by the designer and promoter.
- **Refs:** `S-01`, `S-06`, `G5-01`, `G5-03`, `S1-SEC-01`.

### CA-02: Key epochs derived from the recovery seed cannot revoke a device

- **Where:** `deep_sky_crypto.dart:71-114` (`deriveCoupleRootKey`, `deriveChannelKey`), `ADR-0005`, `m3-operative-plan.md` task `S1-SEC-02`.
- **Problem:**
  - Every channel key is `HKDF(rootKey, info = "…|epoch=N")` and `rootKey` is derived from `recoverySeed`.
  - A revoked device that holds the seed (or the root key) can compute the key for any epoch, past or future.
  - Raising `keyEpoch > 1` after a revocation therefore does not stop the revoked device from reading later content.
- **Fix:**
  - Each epoch needs a fresh random secret (for example `epochSecret_N`) generated by a surviving device and delivered to the other surviving devices through the existing key-delivery path.
  - Channel keys derive from `epochSecret_N`, not from the seed alone.
  - Decide how the Recovery Key interacts with rotation: whether the seed stays valid, is re-issued, or wraps the current `epochSecret`. This changes what the user must save, so it needs designer and promoter approval (`S-06`).
  - Decide what happens when only one device survives or none (recovery from the Recovery Key only).
- **Acceptance:**
  - An automated test shows that a device holding only the pre-revocation keys cannot decrypt an envelope written after rotation.
  - Envelopes from earlier epochs stay readable by surviving devices, with a versioned format and migration (`PD-19`).
  - A new ADR supersedes the relevant part of `ADR-0005`.
- **Refs:** `S-06`, `AD-01`, `G5-05`, `S1-SEC-02`.

### CA-03: A device that has just joined has full privileges before it is approved

- **Where:** `DeviceAuthLookup.findActiveDevice`, `PairingService` (`revokeDevice`, `unpairCouple`, `createEnrollmentInvite`, `storeKeyDelivery`), `SyncService`, `PushController`, `DeviceRepository.findStaleUnapprovedDevices`, `PairingCleanupService`.
- **Problem:**
  - `acceptInvite` saves the new device as active and authenticated immediately. "Approved" exists only as a client-side concept.
  - Until `PairingCleanupService` revokes it (after 30 minutes without a key delivery), the device can:
    - revoke the legitimate device or unpair the couple;
    - create enrollment invites, which can then join more devices;
    - upload and list envelopes;
    - send a key delivery to another device in the couple;
    - trigger pushes.
  - Anyone holding an invite link during its 15-minute window gets this access.
- **Fix:**
  - Add an approval state (for example an `approved_at` column).
  - An existing approved device sets it, for example when it stores the key delivery for the joiner.
  - Until it is set, allow only `GET /pairing/key-deliveries/me`, `PATCH /pairing/devices/me`, and the invite-status call, and reject everything else with 403.
- **Acceptance:**
  - Integration tests for each endpoint above, using a joined but unapproved device, return 403.
  - After approval the same calls succeed.
  - The cleanup query uses the same approval state.
- **Refs:** `S-03`, `S-06`, `G5-04`.

## 4. Medium severity

| ID | Status | Finding |
| :-- | :-- | :-- |
| CA-04 | Fixed (unit verified; DB concurrency test pending Docker) | Invite acceptance is not atomically single-use |
| CA-05 | Fixed (unit/WebMvc/client verified; live Caddy log check pending deploy) | Invite token travels in the URL path and is logged |
| CA-06 | Fixed (`invite_link_codec_test`, `s3_1_enrollment_flows_test`, `welcome_screen_test`) | A link or QR code can switch the app to an arbitrary server |
| CA-07 | Fixed (unit verified; DB integration pending Docker) | Push wakeup is sent inside the database transaction, before commit |
| CA-08 | Fixed (`SyncServiceUnitTest`, `ProdVisibilityDisabledWebMvcTest`, `flutter test`) | Unbounded sync responses and no per-couple storage limit |
| CA-09 | Fixed (`SyncAndPushAuditUnitTest`; DB integration pending Docker) | `/push/wakeup` lets any device send push notifications |
| CA-10 | Code fixed (`native_bridge_test`, `pairing_verification_and_setup_test`; device check pending for `G-3a`) | Recovery Key and invite link can leak through the clipboard and screenshots |
| CA-11 | Fixed (`apk_update_service_test`, `ADR-0008`) | APK updater robustness and trust anchor |
| CA-12 | Fixed (`SecurityApprovalWebMvcTest`, `docs/server-configuration.md`) | Rate limiter trusts `X-Forwarded-For` |

### CA-04: Invite acceptance is not atomically single-use

- **Where:** `PairingService.java:185-225` (`acceptInvite`), also `completeRecovery` (`challenge.usedAt`, around line 430).
- **Problem:** the code reads `acceptedAt`, checks it, then writes, with no lock, `@Version` or conditional update. Two concurrent requests with the same token can both pass the check and create two devices. The second overwrites `acceptedDeviceId`.
- **Fix:** use `UPDATE pairing_invites SET accepted_at = ?, accepted_device_id = ? WHERE token_hash = ? AND accepted_at IS NULL AND expires_at > ?` and require an update count of 1, or take a pessimistic lock on the invite row. Do the same for recovery challenges.
- **Acceptance:** a concurrency test (parallel accepts of one token) creates exactly one device, and the loser gets the same uniform 409 as an invalid token.
- **Refs:** `S1-SRV-01`, `S-03`.

### CA-05: Invite token travels in the URL path and is logged

- **Where:** `PairingController` (`/invites/{token}/accept`, `/invites/{token}/status`), `deploy/Caddyfile` log block (strips headers and masks the IP, but the request URI stays in the log).
- **Problem:**
  - The token is in the path and therefore in Caddy's access log. This conflicts with `S-07` and weakens the minimal-logging goal.
  - The server also receives the raw token (it hashes it for lookup). The task `S1-INF-01` wording "il segreto dell'invito non passa per il server" is not true as implemented. Only the browser fragment keeps it away from the static page.
- **Fix:** send the token in a request body (for example `POST /pairing/invites/accept` with `{token, …}`) and the status call as a POST or a header. Remove the URI from the Caddy log or log only a fixed prefix. Correct the wording in `m3-operative-plan.md` (`S1-INF-01`).
- **Acceptance:** with a real request, the Caddy and Spring logs contain no token. A test or manual log check is recorded.
- **Refs:** `S-07`, `S1-INF-01`.

### CA-06: A link or QR code can switch the app to an arbitrary server

- **Where:** `InviteLinkCodec.parseInviteInput` (`#server=`, `?server=`, and the origin taken from `/c/<token>`), `AndroidManifest.xml` (exported `MainActivity` with `https://deepsky.vectevo.com/join` and `deepsky://pair` filters).
- **Problem:**
  - Any app or web page can fire `deepsky://pair#server=…&token=…`.
  - The parser accepts `http://` and any host. The user may end up registering on an attacker-controlled server, which then sees all metadata and runs the SAS man-in-the-middle in `CA-01`.
  - I did not check whether the UI shows or confirms the host before joining.
- **Fix:** for any server other than the official one, show a blocking confirmation that names the host. Require `https` except for private or local addresses. Consider ignoring `server=` from the custom scheme.
- **Acceptance:** widget or unit tests cover accept, reject, and confirmation for a non-default server.
- **Refs:** `P-09`, `S-01`.

### CA-07: Push wakeup is sent inside the database transaction, before commit

- **Where:** `SyncService.storeEnvelope`, `PairingService.acceptInvite`, `PushService.dispatchPartnerWakeup` (blocking HTTP per target).
- **Problem:**
  - The FCM call runs while the `@Transactional` method holds a DB connection, so a slow FCM response slows uploads and ties up the pool.
  - The partner can be woken before the envelope is committed, so its sync can miss the new event until a later sync.
- **Fix:** publish an event and send the push after commit (`@TransactionalEventListener(phase = AFTER_COMMIT)`), preferably asynchronously. Keep errors from failing the write, as today.
- **Acceptance:** a test shows the wakeup is sent only after commit, and a failing push provider does not affect the upload response.
- **Refs:** `N-01`, `ADR-0006`.

### CA-08: Unbounded sync responses and no per-couple storage limit

- **Where:** `SyncController.listEnvelopes`, `SyncService.listEnvelopes` and `getVisibilityAudit`, `PairingService.getVisibilityAudit`, `DeepSkyProperties.quotas` (the blob module is empty, so `max-couple-storage-bytes` is unused).
- **Problem:**
  - `GET /api/v1/sync/envelopes` returns every row after `afterSeq` with no limit, and the visibility endpoints load whole tables, with the JVM heap capped at 256 MB (`ADR-0009`).
  - Nothing limits how many envelopes or bytes a couple can store.
  - Combined with `CA-03`, a single unapproved device can fill the database.
- **Fix:** add a page size limit with a `nextAfterSeq`, a per-couple envelope or byte quota (reuse the configured quota), and disable or restrict the visibility endpoints outside a dev or audit profile.
- **Acceptance:** tests for the page limit, for quota rejection (HTTP 413 or 429 with a stable error code), and for the visibility endpoints being unavailable in `prod`.
- **Refs:** `N-08`, `TC-17`.

### CA-09: `/push/wakeup` lets any device send push notifications

- **Where:** `PushController.sendPartnerWakeup`, `PushService.SUPPORTED_KEYS`.
- **Problem:**
  - Any active device (including an unapproved one, `CA-03`) can trigger any supported key, including `wakeup.pairing_request`, to the partner with no throttle.
  - This is a notification-spam vector and conflicts with `P-02` and `P-03`.
  - Authenticated endpoints have no rate limiting at all.
- **Fix:** remove the public endpoint, since pushes already fire on server events, or restrict it to a safe subset and throttle it per device. Consider a general per-device rate limit for authenticated calls.
- **Acceptance:** a test that repeated calls are throttled or rejected, and that `wakeup.pairing_request` cannot be triggered from this endpoint.
- **Refs:** `P-02`, `P-03`, `S-02`.

### CA-10: Recovery Key and invite link can leak through the clipboard and screenshots

- **Where:** `recovery_key_setup_page.dart:166,186`, `welcome_invite_panel.dart:103`, `code_verification_page.dart:35`, `deep_sky_controller.dart:599`. No `FLAG_SECURE` exists in `android/` or `lib/`.
- **Problem:**
  - The Recovery Key (words and QR) can be copied to the clipboard with no expiry, and the screen can be captured or recorded.
  - Clipboard contents are readable by other apps and clipboard managers on many Android versions.
  - The invite link (which contains the token) and the SAS code are also copied.
- **Fix:**
  - Mark clipboard data as sensitive (`ClipDescription.EXTRA_IS_SENSITIVE` through the native bridge) and clear it after a short delay.
  - Set `FLAG_SECURE` on the Recovery Key, QR and SAS screens.
  - Do not copy the SAS code.
  - Keep the "avoid screenshots and cloud notes" warning.
- **Acceptance:** manual check on a device that a screenshot of the Recovery Key page is blocked and the clipboard is cleared after the delay. Record it in the test evidence for `G-3a`.
- **Refs:** `S-06`, `G5-06`.

### CA-11: APK updater robustness and trust anchor

- **Where:** `lib/data/apk_update_service.dart:387-411` and `:395-399`, `deep_sky_controller.dart:1190-1225`, `home_shell_page.dart:36`, `upgrade_required_page.dart:22`, `ADR-0008`.
- **Problems:**
  1. If the `.part` file is larger than `apkSizeBytes`, the length check fails and the file is **not deleted**. Every retry reuses it and fails forever until the user clears app data.
  2. The whole APK is read into memory (`readAsBytes`) to hash it, which risks out-of-memory on low-RAM phones.
  3. The trusted Ed25519 key defaults to a hardcoded value but is editable in the Settings UI and as a parameter, and `http://` mirrors are accepted. Integrity still depends on the signature, but the trust anchor is user-mutable.
  4. Download retries have no backoff.
- **Fix:** delete the `.part` on any length or hash mismatch, hash as a stream, move the key and mirror options behind an advanced or dev switch (or ignore a user key unless a dev flag is set), and add a short backoff.
- **Acceptance:** unit tests for an oversized `.part` (recovers on the next attempt) and for streaming-hash equivalence. Policy for the trust key is decided and documented in `ADR-0008`.
- **Refs:** `F-19`, `TC-10`, `SEC-04`.

### CA-12: Rate limiter trusts `X-Forwarded-For`

- **Where:** `PublicEndpointRateLimitFilter.extractClientIp`, `application.yaml` (`forward-headers-strategy: framework`), `deploy/docker-compose.yml`.
- **Problem:** the limiter uses the first `X-Forwarded-For` value. This is safe only because Caddy overwrites the header (no trusted proxies configured) and the API port is not published. A self-hoster who exposes the API directly, or changes the proxy, would let attackers bypass every limit by sending their own header.
- **Fix:** resolve the client address from the container's `remoteAddr` plus the proxy setup (`ForwardedHeaderFilter`/`server.forward-headers-strategy`), or fail startup when the header is present without a trusted proxy. At minimum, document the requirement in `docs/server-configuration.md`.
- **Acceptance:** a test sends a forged `X-Forwarded-For` and is still limited, or the requirement is documented and tested in the compose smoke test.
- **Refs:** `G5-03`, `N-04`.

## 5. Low severity

| ID | Status | Finding | Where | Suggested fix |
| :-- | :-- | :-- | :-- | :-- |
| CA-13 | Fixed (`SecurityApprovalWebMvcTest`) | `GlobalExceptionHandler` returns raw `IllegalArgumentException` and `IllegalStateException` messages to clients and has no catch-all handler | `shared/GlobalExceptionHandler.java` | Stable error codes with fixed messages (see `docs/enrollment-state-machine.md`); log details server-side; add a catch-all that returns a generic 500 body |
| CA-14 | Fixed (`SyncServiceUnitTest`) | `storeEnvelope` does `existsById` then insert, so concurrent retries of the same ID raise a unique-violation 500; an ID that belongs to another couple returns a distinct "conflict" error | `SyncService.java` (`storeEnvelope`) | Insert with `ON CONFLICT DO NOTHING` and re-read; return the same response for foreign IDs as for new ones |
| CA-15 | Deferred to `S3-3`/`S3-4` (`docs/m3-operative-plan.md`) | Every `EVENT` envelope sends `wakeup.thinking_of_you`, whatever the event type | `SyncService.storeEnvelope` | Derive the key from an explicit, non-secret hint chosen by the client, or send a generic key; revisit when mood and countdown events exist (`P-03`) |
| CA-16 | Fixed (`SecurityApprovalWebMvcTest`) | `DeviceAuthFilter` reads up to 2 MB of body before authenticating, and answers "unknown or revoked" and "invalid signature" differently | `config/DeviceAuthFilter.java` | Verify headers and timestamp first; use one generic message; lower the pre-auth body cap |
| CA-17 | Fixed (`PairingCleanupService`, `PairingServiceUnitTest`, `Sp02PairingAndSyncIntegrationTest`) | Public `POST /pairing/invites` creates a couple and a device with no cleanup of couples that never get a second partner | `PairingService.createInitialInvite`, `PairingCleanupService` | Cleanup of never-paired couples after a retention period; keep the rate limit |
| CA-18 | Accepted & documented (`ADR-0005`) | Key delivery uses static-static X25519, so there is no forward secrecy for the wrapped seed | `wrapRecoverySeed` / `unwrapRecoverySeed` | Accept and document in `ADR-0005`, or use an ephemeral sender key |
| CA-19 | Fixed (`compileDebugKotlin`) | The installer compares the whole signing-certificate history, so a legitimate future certificate rotation would be refused | `ApkInstallerCoordinator.kt` (`signingDigests`) | Accept if the installed certificate is in the archive's history; add a test when rotation is planned (`D-14`) |
| CA-20 | Fixed (`deploy/web/.well-known/assetlinks.json`, `.github/workflows/ci.yml`) | `assetlinks.json` still holds the all-zero placeholder fingerprint, so Android App Links verification fails (the `/join` page fallback still works) | `deploy/web/.well-known/assetlinks.json` | Replace with the real SHA-256 at `S1-REL-01`; add a CI check that rejects the placeholder |
| CA-21 | Fixed (`compileDebugKotlin`) | The installer copies the APK into the session on the calling thread | `ApkInstallerCoordinator.installVerifiedApk`, `PlatformBridgePlugin` | Confirm the bridge calls it off the main thread; move it to a background executor if not |

No XSS was found on the join page: the fragment is only prefixed to a `deepsky://` link and displayed with `textContent`.

## 6. Documentation that does not match the code

| ID | Status | Mismatch | Fix |
| :-- | :-- | :-- | :-- |
| CA-D1 | Open | `ADR-0005` lists channels `timeline`, `capsules`, `profile`, `scene`, `countdowns`; the code has only `events` and `snapshots` (`EnvelopeChannel`, `deriveChannelKey`) | Correct `ADR-0005` through a new ADR, or implement the channels when the features land |
| CA-D2 | Open | `ADR-0004` and `architecture.md` `AD-03` describe snapshots with optimistic `version` / `schemaVersion` control; the server stores `SNAPSHOT` as an ordinary envelope with no version check | Implement it, or mark it as planned in both documents |
| CA-D3 | Fixed (`docs/m3-operative-plan.md` `S1-INF-01`) | `m3-operative-plan.md` `S1-INF-01` says the invite secret does not pass through the server | Fix after `CA-05` is resolved |
| CA-D4 | Open | `ADR-0004` rule list now matches `ArchitectureTest`, but sibling-module isolation is still not enforced by any rule | Add the rule or keep the ADR note |

## 7. Suggested order of work

1. **Before real data (`G-3a`):** `CA-03`, `CA-04`, `CA-05`, `CA-06`, then the design and ADR for `CA-01` and `CA-02` (together with `S1-SEC-02`).
2. **Soon after:** `CA-07`, `CA-08`, `CA-09`, `CA-10`, `CA-11`, `CA-12`.
3. **When convenient:** `CA-13`..`CA-21` and the documentation items.
4. **Complete the audit:** review the areas listed under "Not reviewed", then add the findings to this document with new IDs.

## 8. Relationship to other plans

- `S1-SEC-01` (internal security review) should use this document as input and record which findings it confirmed, rejected or deferred.
- `S1-SEC-02` is the home of `CA-02` and should depend on the `CA-01` decision, because both change the pairing and key-delivery protocol.
- Findings that are deferred on purpose must be listed in the `G-5` hand-off (`architecture.md` `G5-xx`) with a reason.
