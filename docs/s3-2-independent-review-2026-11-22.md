# S3-2 Independent Review, 2026-11-22

- **Task:** `S2-SEC-01` (security verification on the pack supply chain and local state privacy), done by a reviewer who did not write `S2-APP-02`, `S2-SRV-01`, or `S2-APP-03`.
- **Branch / commit:** `development` @ `d2784f3`
- **Reference IDs:** `G5-07`, `TC-10`, `AR-09`, `AD-06`, `PD-19`, `P-02`, `P-07`, `S-05`, `F-02`, `F-03`, `F-20`, `S2-CTR-01`, `S2-CTR-02`
- **Verdict:** All three `S2-SEC-01` checks **pass**. There are 2 medium findings and 4 low findings, and none of them blocks closing `S2-SEC-01`. `IR-01` should be fixed before a second `packId` is published (the per-sprint micro-packs from `S3-4` onwards). `IR-02` should be fixed before `S3-3` closes.

## 1. Scope and method

**Reviewed (read in full):**

- Client: `lib/data/content_pack_service.dart`, the content-pack, boot and local-state parts of `lib/presentation/deep_sky_controller.dart`, `lib/presentation/deep_sky_app.dart` (boot counter reset), `lib/presentation/screens/home_shell_page.dart` (first-frame hook), `lib/scene/local_scene_view_state.dart`, `lib/scene/couple_room_snapshot.dart`, `lib/scene/scene_state_mapper.dart`, `lib/scene/hybrid_scene_canvas.dart` (image providers, eviction), `lib/presentation/widgets/thought_history_sheet.dart`, `lib/main.dart`.
- Server: `content/ContentPackStore.java`, `content/ContentPackController.java`, `content/ContentPackConfig.java`.
- Deploy/docs: `deploy/Caddyfile` (log filter), `deploy/.env.example`, `deploy/docker-compose.yml`, `docs/content-pack-contract.md`, `docs/scene-state-contract.md`, `docs/key-custody.md`.
- Grep sweep for `lastSeen*`, `lastOpened*`, `LocalSceneViewState`, `CoupleRoomSnapshot` across `lib/` and `android/app/src/main`, and for logging calls (`print`, `debugPrint`, `developer.log`) in `lib/`.

**Executed:**

| Suite | Result |
| :-- | :-- |
| `flutter test test/security/content_pack_security_test.dart test/scene test/domain/scene_manifest_parser_test.dart` | 17/17 passed |
| `mvnw test -Dtest=ContentPackStoreAndControllerTest,DeepSkyPropertiesValidationTest` | 5/5 + 4/4 passed |
| Temporary probe tests written by the reviewer (deleted after use, not committed) | reproduced `IR-01` and `IR-02` (section 4) |
| SHA-256 of the embedded content/update public key (SPKI DER) | `b6bc0deb…299292`, matches `docs/key-custody.md` |

**Not reviewed:** `scripts/*.py` and `ImagePackTool.java` beyond the signing entry point, `SceneManifestParser` internals, the `ADR-0007` physical measurements (`S2-QA-01`, still open), and golden image content.

## 2. Verdict on the `S2-SEC-01` checks

| `S2-SEC-01` check | Verdict | Evidence |
| :-- | :-- | :-- |
| Ed25519 (with `keyId` selection) checked on raw bytes **before** any JSON parsing | **Pass** | `verifyAndParseChecksums` (`content_pack_service.dart:126-150`): `.sig` envelope parsed, key looked up, `ed25519.verify` on raw bytes, and `jsonDecode` only after that. The payload `keyId` is then bound to the envelope `keyId` (`:182`). The server mirrors this order (`ContentPackStore.java:166-177`). |
| Automated rejection of unknown `keyId`, invalid signature, tampered checksums, PNG hash mismatch, `../`, downgrade, unsupported `minAppProtocol`, and rollback after `>= 2` failed boots | **Pass** | Covered by `content_pack_security_test.dart` (ran green). Code paths confirmed: path guard `isSafeRelativePath` on both sides plus server symlink-escape check (`ContentPackStore.java:261-277`), streaming size cap (`:664-675`), blob cache re-hashed on reuse (`:632-638`), anti-downgrade persisted in `maxSeenVersion`. See `IR-03` for a limit of the rollback guard. |
| `lastSeenEventSeq` and `lastOpenedAtLocal` never leave the device | **Pass** (independent) | They are only read or written in `LocalSceneViewStateStore` (secure storage, `allowBackup="false"`), `SceneStateMapper` (local derivation), and the controller. There are no references in `couple_api_client.dart`, `pairing_and_sync_repository.dart`, `push_api_client.dart`, `e2ee_models.dart`, or the Kotlin sources. The *Thinking of you* payload is only `{note?}` (`deep_sky_controller.dart:1415-1417`). `CoupleRoomSnapshot` is never serialized to the network (built only inside `SceneStateMapper`). There are no logging calls in `lib/`. See `IR-07` for a behavioural residual and section 5 for the test gap. |

## 3. Findings

| ID | Severity | Status | Finding |
| :-- | :-- | :-- | :-- |
| IR-01 | Medium | Fixed (`packIdMismatch`; tests `IR-01: …` in `content_pack_security_test.dart`) | Pack identity (`packId`) is not pinned on the client, so a foreign pack is accepted and corrupts the anti-downgrade floor |
| IR-02 | Medium | Deferred to `S3-3` design (sponsor, 2026-11-22; `m3-operative-plan.md` ch. 7) | *Thinking of you* authorship is device-based: after a phone replacement (`F-20`), the user's own thoughts are shown as the partner's |
| IR-03 | Low | Fixed (`HybridSceneCanvas.onActiveLayersResolved`; tests `IR-03: …` in `s3_2_home_and_scene_test.dart`) | The "last known good pack" guard resets before pack images are decoded, so it cannot catch a broken asset |
| IR-04 | Low | (a) Excluded (`docs/audit-exclusions.md`); (b) Fixed (`rejectsPackBelowConfiguredMinPackVersionAndKeepsPrevious`) | Server-side defence in depth fails open (a) and does not enforce its own `minPackVersion` (b) |
| IR-05 | Low | Fixed (test group `IR-05: stale ETag is cleared…`) | A stale `ETag` survives a discarded staged pack, so silent updates stall on `304` |
| IR-06 | Low | Fixed, transitional (`type` optional until published packs are re-signed, rejected if wrong; tests on client and server) | One Ed25519 key and one `keyId` (`v1`) for both APK release manifests and content packs, with no signing context |
| IR-07 | Info | Documented (`docs/wiki/server-operations.md`) | Behavioural equivalent of "last opened" is visible to the server operator, who is one of the partners |
| IR-08 | Info | Fixed (`scene-state-contract.md` §1, `key-custody.md` registry) | Documentation drift (`scene-state-contract.md`, `key-custody.md`) |
| IR-09 | Info | Accepted by the sponsor (2026-11-22): the shared total stays | The history sheet shows a total "N thoughts together" counter (`P-02`) |
| IR-N1..N3 | Nit | Fixed (tests `IR-N1`, `IR-N2`, `IR-N3`; see the `IR-N1` release note in section 8) | See section 3.10 |

### IR-01: Pack identity is not pinned on the client

- **Where:** `content_pack_service.dart:559-575` and `:709-719`.
- **Problem:** The client checks that `manifest.packId == checksums.packId`, but never checks that this `packId` is the Home pack (`bundledManifest.packId`, `deep-sky-home-v1`). Any pack signed by a trusted key is accepted as the Home scene. Its version is then written to the single global `maxSeenVersion`.
- **Reproduced:** A signed pack `some-other-pack` `9.0.0` was served and returned `activatedHotReload` with `packId=some-other-pack`. A legitimate `deep-sky-home-v1` `1.2.0` served afterwards was rejected with `downgradeRejected: Remote pack 1.2.0 < min acceptable 9.0.0`.
- **Impact:** This needs the signing key, so it is not an external attack. It is a realistic **publishing mistake**: the plan foresees new micro-packs per sprint (`S3-4` mood slot, `S3-5` calendar, …), which may get their own `packId`. One wrong file in `pack_data` would replace the Home scene and block every later Home update on every phone until a reinstall or a Home pack with a higher version than the foreign one. The same signed key also signs APK manifests (`IR-06`), which widens what "trusted" covers.
- **Fix:** Pass the expected `packId` (from the bundled manifest) into `syncFromServer` and reject on mismatch with a new `ContentPackErrorCode.packIdMismatch` *before* the downgrade check. Also check it in `_loadVerifiedManifestFromDir` at startup. If several packs are planned, key `maxSeenVersion` (and `active`/`previous`/`staged`) by `packId`. Update `content-pack-contract.md` §2.2 step 5.
- **Acceptance:** A security test that serves a correctly signed pack with a different `packId` gets `packIdMismatch`, and `maxSeenVersion` is unchanged.

### IR-02: Authorship is device-based, which breaks after a phone replacement (`F-20`)

> **Sponsor decision (2026-11-22):** deferred to the `S3-3` design (per-partner identity plus an identification step on recovery-key restore). No code change in `S3-2`.

- **Where:** `scene_state_mapper.dart:72` (`authorDeviceId != localDeviceId`), `thought_history_sheet.dart:320-323` (`isMe`), `deep_sky_controller.dart:824-840` (`partnerDisplayLabel`).
- **Problem:** "Partner" means "any device that is not this one". After the supported new-phone flows (recovery key or enrollment from another phone), the user's own earlier thoughts were authored by the old device id:
  - the history sheet (new in `S3-2`) permanently labels them with the partner's name;
  - a thought sent from the old phone less than 6 h earlier lights the lamp and shows "*\<Partner\> thought of you*" on the new phone;
  - `partnerDisplayLabel` returns the first non-revoked foreign device, which can be the user's own old phone while it is not yet revoked.
- **Reproduced:** `SceneStateMapper.derive` with a thought from `dev-me-OLD` and `localDeviceId: dev-me-NEW` returned `unseenPartnerThought=env-1`, `floorLampLit=true`.
- **Impact:** Not a confidentiality issue, but it puts words in the partner's mouth in an intimate feature. Phone replacement was already exercised in the field (`S1-APP-04`).
- **Fix (needs a small contract decision, `PD-19`):** Introduce a person-level identity, for example a stable per-partner `memberId` or slot (`A`/`B`) assigned at pairing. The new device inherits it on recovery or enrollment, and it is carried inside the encrypted payload (`authorMemberId`) and in `DeviceSummary`. Old events without it are resolved through a locally kept set of "my previous device ids", restored on recovery. Attribution in the mapper, the history sheet, and `partnerDisplayLabel` should use the member, not the device.
- **Acceptance:** Tests for the mapper and history sheet where the thoughts were sent from a previous device of the same partner and are attributed to "You".

### IR-03: The rollback guard resets before pack images are decoded

- **Where:** `home_shell_page.dart:55-60` (`addPostFrameCallback` → `markHomeBootSucceeded`), `hybrid_scene_canvas.dart` (`FileImage` without `errorBuilder`).
- **Problem:** Image decoding is asynchronous and finishes *after* the first frame. A truncated or undecodable PNG, or an over-sized one that causes memory pressure, fails after the counter has already been reset. A decode error is reported to `FlutterError.onError` and the layer simply renders empty, with no crash. So the realistic failure modes of a bad pack never trigger the automatic rollback. The guard effectively only catches synchronous build errors, which `_loadVerifiedManifestFromDir` already filters out.
- **Mitigation already present:** The signature and SHA-256 make corruption in transit impossible. What remains is a broken asset that was signed and published, and the manual "Update graphics" button.
- **Fix:** Mark success only after the active layers have resolved: `precacheImage` the active layers of the visible slot states, then call `markHomeBootSucceeded`. Treat a load error of any active layer as a failed boot (do not reset). Alternatively, document the limit in `content-pack-contract.md` §5.3 so `ADR-0007` field checks cover it.

### IR-04: Server-side defence in depth fails open

> **Sponsor decision (2026-11-22):** part (a), optional signature verification on the server, is accepted and recorded in `docs/audit-exclusions.md`. Only part (b) is to be fixed.

- **Where:** `ContentPackStore.java:68-72` and `:169-175`, `deploy/.env.example:16-17`.
- **Problem:**
  1. When `DEEPSKY_CONTENT_TRUSTED_KEY_V1/V2` are blank (the `.env.example` default), signature verification is silently skipped (only a `WARN` at startup).
  2. The server never compares the loaded `packVersion` with its own advertised `minPackVersion`. Publishing a pack below it makes every client fail with `downgradeRejected`.
- **Impact:** Client security is unaffected (`G5-07`, the client is the anchor). This is about catching publishing errors, which is the purpose stated in `S2-CTR-01`.
- **Fix:** Reject packs with `packVersion < minPackVersion` in `loadAndVerify`. Pre-fill `DEEPSKY_CONTENT_TRUSTED_KEY_V1` in `.env.example` with the public key from `key-custody.md`, or refuse to load packs when `DEEPSKY_CONTENT_PACKS_DIR` is set and no key is configured, unless an explicit opt-out is set.

### IR-05: A stale `ETag` survives a discarded staged pack

- **Where:** `content_pack_service.dart:348-355` (staged pack discarded at startup), `:404-414` (rollback to bundled), `:508-528`.
- **Problem:** The `ETag` is saved when a pack is staged. If the staged pack is discarded at startup (manifest fails to load, or it is now below `serverMinPackVersion`), the `ETag` is kept. Every later silent check then gets `304` and never retries until the server publishes a different pack. Recovery is only possible through the manual button.
- **Fix:** Clear `etag` whenever a staged pack is discarded or the active pack is dropped. Add a test for each branch.

### IR-06: One signing key for two protocols, with no signing context

- **Where:** `deep_sky_controller.dart:86-96` (content key `v1` = `trustedUpdatePublicKeyB64`), `docs/key-custody.md` §2.
- **Problem:** This is documented as intentional, but the signed bytes carry no domain separator. Today a cross-protocol replay is not practical, because the APK manifest and `pack-checksums.json` schemas have no overlapping required fields. Every new signed JSON format added later (more pack types, `S3-x` content) increases the risk.
- **Fix (cheap now, expensive after more formats):** Add a `"type": "deep-sky/pack-checksums"` field (or sign `context || bytes`) and require it on the client, and use a distinct `keyId` namespace for content (`content-v1`). This changes the format, so it needs `PD-19` handling: accept both during one release, then require the new form.

### IR-07: Behavioural equivalent of "last opened" reaches the server (Info)

The field-level guarantee holds (section 2). However, each app start and resume triggers authenticated sync (`syncOnResumeSilently`, at most once per 10 s) and a content check. Whoever operates the server can therefore approximate when each device opens the app. Caddy logs already drop URIs and headers and mask IPs to /24, but timestamps remain. In this project the operator is one of the two partners (Persona A), so this is relevant to `P-07`. **Recommendation:** state it plainly in the privacy and self-hosting docs (`P-06`: "private" as a precise promise), and keep access-log retention short. No code change is needed for `S3-2`.

### IR-08: Documentation drift (Info)

- `docs/scene-state-contract.md` §1 calls `CoupleRoomSnapshot` "shared, E2EE encrypted on the server". In the code it is never uploaded: it is derived locally from envelopes. Reword the section, so that nobody later starts syncing it believing that was the design.
- `docs/key-custody.md` fingerprint registry still says *Pending offline generation* for the Ed25519 key, but that key is embedded in the app (fingerprint verified identical). Update the status.

### IR-09: History sheet shows a total counter (Info, `P-02`, sponsor decision)

> **Sponsor decision (2026-11-22):** accepted. A combined total is fine; a per-person count would still be forbidden by `P-02`.

`ThoughtHistorySheet` shows "*N pensieri insieme*" / "*N thoughts together*" (`thought_history_sheet.dart:145`, `deep_sky_strings.dart:529-536`). It is a combined total, not a per-person count, so it is not a direct `P-02` violation. Still, it puts a number on a gesture of affection, and brief ch. 13 says metrics must never become user-facing. The sheet is still awaiting sponsor approval (`S2-D10`), so the sponsor should decide explicitly whether to keep it, replace it with a non-numeric phrase, or remove it.

### 3.10 Nits

- **IR-N1:** `_parseSigEnvelope` (`content_pack_service.dart:1006-1019`) accepts a raw 64-byte or unprefixed signature as `v1`. The contract calls this "test backward-compatibility only", but it is active in production code. Restrict it to tests or remove it.
- **IR-N2:** `isSafeRelativePath` (client `:92`, server `:245`) rejects only `\0`, while the contract says "no control characters". Reject the whole range `\u0000-\u001F` and `\u007F`.
- **IR-N3:** With `manualForce`, a pack of the same version is rebuilt and moved over `active/<sameVersion>` while its files are on screen. This is harmless today because the image cache is cleared right after, but the "already up to date" path could return early when `activeVersion == packVersion` and the files are intact.

## 4. Reproduction notes

The reviewer added a throwaway test file under `test/security/`, ran it, and deleted it. The working tree is clean. Both probes reused the helpers in `content_pack_security_test.dart`:

- **IR-01:** sign `some-other-pack` `9.0.0` with the trusted key, `syncFromServer(manualForce: true)`, then serve `deep-sky-home-v1` `1.2.0`. Result: `activatedHotReload`, then `downgradeRejected`.
- **IR-02:** `SceneStateMapper().derive(events: [thought by dev-me-OLD, 30 min ago], localDeviceId: 'dev-me-NEW')`. Result: `unseenPartnerThought != null`, `floorLampLit == true`.

They can be turned into the regression tests named in the *Acceptance* lines above.

## 5. Test coverage gap on the privacy check

The privacy test (`content_pack_security_test.dart:525`) only checks the snapshot JSON keys and that `markLatestPartnerThoughtSeen` makes zero HTTP calls. It does not exercise `initialize()` (which writes `lastOpenedAtLocal`), `sendThinkingOfYou`, or `replyToPartnerThought`. The manual trace in section 2 found no leak. To keep it that way, add a test that runs `initialize → reply` against a recording `MockClient` and asserts that no request URL, header, or body contains the stored `lastSeenEventSeq`, `lastSeenThoughtEnvelopeId`, or `lastOpenedAtLocal` values.

## 6. What is solid

- The signature is checked before parsing, and the `keyId` binding prevents swapping envelope and payload.
- Defence in depth on paths: allowlist-only file serving on the server, symlink containment, and the client guard on every write and read.
- Content-addressed blobs are `immutable` only where that is safe. Path URLs are `no-cache` with an `ETag`.
- Blob cache entries are re-hashed before reuse. Downloads are streamed with an idle timeout and a hard size cap.
- Pack operations are serialized (`_synchronized`). Metadata is re-read before commit, and there is a clean fallback to the bundled pack on any error.
- Local state is kept strictly in secure storage. There are no read receipts and no presence information, and "Send back" is an explicit gesture, not a receipt.

## 7. Plan updates (applied 2026-11-22)

- `S2-SEC-01` third check ticked in `m3-operative-plan.md`, citing this report. A follow-up item tracks the fixes.
- `IR-01` noted as a precondition for the first micro-pack with a new `packId` (`S3-4` row). `IR-02` added to the `S3-3` design row.
- `IR-09` accepted by the sponsor.

## 8. Fix verification (2026-11-22)

The fixes were implemented by a separate agent and re-verified by the reviewer on the uncommitted working tree:

- `flutter analyze`: no issues.
- `flutter test` (full suite, goldens included): 113 passed, no golden files changed.
- `server/ ./mvnw test`: 47 run, 0 failures, 0 errors, 0 skipped.
- `docs/content-pack-contract.md` bumped to v1.1 to match.
- Section 5 gap closed by the test `Review section 5 / P-07 / S-05: initialize -> replyToPartnerThought / sendThinkingOfYou never put … on the wire`. It also decrypts the uploaded envelopes.

**Release notes:**

- **`IR-N1`:** client and server now require the `keyId:base64` `.sig` envelope. `scripts/sign_content.py` has always produced it, but check the live `pack-checksums.json.sig` on the server's `pack_data` volume before releasing this APK.
- **`IR-06`:** re-sign the published packs with `sign_content.py` (it now emits `type`) at the next publish. Then make `type` mandatory in a later release.
