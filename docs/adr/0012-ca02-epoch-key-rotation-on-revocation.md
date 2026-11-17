# ADR-0012: Independent Epoch Key Rotation and Recovery Key Rotation on Revocation (`CA-02`, `S1-SEC-02`)

- **Status:** Accepted by promoter (`PD-11`, 2026-11-16); supersedes the key-hierarchy epoch derivation in [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md)
- **Date:** 2026-11-16
- **Reference IDs:** `S-01`, `S-06`, `AD-01`, `PD-19`, `G5-05`, `S1-SEC-02`, `CA-02`

## Context

Under [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md), every channel key for any `keyEpoch >= 1` was derived deterministically from `recoverySeed` (`HKDF(rootKey, "deep-sky:<label>:v1|epoch=N")`). Raising `keyEpoch` after revoking a lost or compromised device could not prevent a device holding the pre-revocation `recoverySeed` (or `rootKey`) from computing future channel keys or authenticating recovery challenges.

## Decision

1. **Random per-epoch secrets for `keyEpoch >= 2`:**
   - `keyEpoch = 1` retains its existing `v1` derivation from `recoverySeed` (`deep-sky:<label>:v1|epoch=1`) so all pre-rotation envelopes remain readable without re-encryption (`PD-19`).
   - Each rotation (`keyEpoch = N >= 2`) generates a fresh random 256-bit `epochSecret_N` (`Random.secure()`), **independent of `recoverySeed`**.
   - Channel keys for `N >= 2` derive from `epochSecret_N` using `HKDF-SHA256(ikm = epochSecret_N, info = "deep-sky:<label>:v2|epoch=N")`.
2. **Recovery Key rotation and encrypted epoch keyring (`S-06`):**
   - When a surviving device revokes another device (`targetDeviceId != callerDeviceId`), it generates both a fresh random `epochSecret_N` (`N = currentKeyEpoch + 1`) and a fresh random 256-bit `newRecoverySeed`, derives the new `recoveryAuthPublicKey`, and encrypts a versioned keyring (`{"v":2,"epochs":{"1":"<epoch1RootKeyB64>","2":"<epochSecret2B64>",...}}`) using `deriveCoupleRootKey(newRecoverySeed)` and XChaCha20-Poly1305 with AAD `deep-sky:recovery-keyring:v1|coupleId=<coupleId>|epoch=<N>`.
   - Note that for `epoch = 1`, the keyring stores the derived `epoch1RootKey` (not the retired `recoverySeed_1`) so the retired `recoverySeed_1` cannot authenticate recovery challenges and cannot unwrap `recovery_keyring_ciphertext` or derive `epoch >= 2` keys.
   - The rotating device sets `recoverySavedConfirmed = false` locally so the user is prompted to save the new 24-word Recovery Key (`S-06`).
3. **Surviving device distribution and stale-epoch enforcement:**
   - The rotating device wraps a `v2` key bundle (`{"v":2,"recoverySeedB64":...,"currentKeyEpoch":N,"epochSecrets":{...}}`) via X25519 ECDH (`deep-sky:key-delivery:v2|coupleId=...|from=...|to=...|epoch=N`) for every other active, approved device in the couple and submits the atomic rotation (`POST /api/v1/pairing/devices/{deviceId}/revoke` with optional rotation payload, or `POST /api/v1/pairing/epoch-rotations`).
   - `couples.current_key_epoch` is incremented on the server, `couples.recovery_auth_public_key` and `recovery_keyring_*` are updated, and `SyncService.storeEnvelope` rejects writes with `keyEpoch < couple.currentKeyEpoch` (`409 STALE_KEY_EPOCH`) so offline surviving devices fetch their `EPOCH_ROTATION` key delivery before writing new events.
   - Voluntary self-unlink (`targetDeviceId == callerDeviceId`) revokes only the calling device without forcing a Recovery Key rotation on the remaining partner.
4. **Zero-second-phone recovery (`F-20`) & single surviving device:**
   - If only one device survives, it holds `newRecoverySeed` and `epochSecrets[1..N]` directly and re-encrypts the keyring on the server for future zero-second-phone recovery.
   - `POST /api/v1/recovery/complete` returns `currentKeyEpoch`, `recoveryKeyringNonceB64`, and `recoveryKeyringCiphertextB64`, allowing a recovering phone with the current 24-word Recovery Key to unwrap all epochs `1..N` (`PD-19`) while rejecting the retired pre-revocation 24 words.

## Alternatives Considered

- **Keeping the original `recoverySeed` valid across revocations and wrapping `epochSecret_N` under it:** Rejected because a stolen device holding the original `recoverySeed` could still authenticate `/recovery/challenges` and unwrap `epochSecret_N`.
- **Re-encrypting all historical envelopes on every revocation:** Rejected due to bandwidth/storage cost on low-end mobile devices and risk of partial migration failure; the versioned keyring preserves `epoch = 1..N-1` readability cleanly (`PD-19`).

## Consequences

- A revoked device holding only pre-revocation keys (`recoverySeed_1`, `epochSecret_1..N-1`) cannot decrypt envelopes written after rotation (`epoch >= N`) and cannot recover the couple via `/recovery/challenges`.
- After revoking another device, the surviving partner(s) must save the newly issued 24-word Recovery Key (`S-06`).
- Verified by automated cross-epoch revocation tests in `test/domain/deep_sky_crypto_test.dart`, `test/data/pairing_and_sync_repository_test.dart`, and server `Sp02PairingAndSyncIntegrationTest`.
