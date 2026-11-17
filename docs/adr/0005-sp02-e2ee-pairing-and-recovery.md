# ADR-0005: E2EE Pairing, Recovery, Cross-Device Enrollment, and Revocation (`SP-02`)

- **Status:** Accepted (verified on real Android hardware; SAS derivation superseded by [ADR-0011](0011-ca01-sas-out-of-band-secret.md); key-epoch & recovery rotation superseded by [ADR-0012](0012-ca02-epoch-key-rotation-on-revocation.md); `PD-05` and `G-5` remain tracked before real couple data)
- **Date:** 2026-11-15 (baseline 2026-11-14)
- **Reference IDs:** `S-01`, `S-03`, `S-06`, `F-01`, `F-02`, `AD-01`, `AD-02`, `AD-03`, `SP-02`

## Context

Deep Sky must establish end-to-end encrypted communication between two partner devices (`S-01`), support enrollment of an additional device without leaking long-term secrets to the server, enable full couple-key recovery using only a user-held Recovery Key when no other device is available, and support immediate revocation of lost or compromised devices (`S-06`), all while ensuring the server stores zero readable couple content (`S-01`); unilateral unpairing is handled by `S-03`.

## Decision

The prototype (branch `proto/sp-02`, since merged into `development`) implements and validates the protocol specified in `docs/sp-02-e2ee-protocol.md` (available on branch `proto/sp-02`; not present on `development`):

- **Cryptographic Primitives:** X25519 (ECDH pairing & ephemeral wrapping), Ed25519 (per-device HTTP request authentication `AD-02` & recovery proof), HKDF-SHA256 (key derivation), XChaCha20-Poly1305 AEAD (`package:cryptography` `2.9.0`), BIP-39 24-word mnemonic + checksummed `deepsky-rk:v1:` QR (`bip39_mnemonic` `4.1.0`).
- **Key Hierarchy:** A random 256-bit `recoverySeed` (the Recovery Key) is generated at couple creation. The couple root key and per-channel keys (`timeline`, `capsules`, `profile`, `scene`, `countdowns`) derive from it via HKDF-SHA256 (salt `deep-sky:salt:v1`, info `deep-sky:couple-root:v1` and `deep-sky:<label>:v1|epoch=<keyEpoch>`). The seed reaches a partner device through a pairwise X25519 SAS-verified delivery (HKDF salt `coupleId`, info `deep-sky:pairing-wrap:v1`, AAD `deep-sky:key-delivery:v1|coupleId=…|from=…|to=…`). The Recovery Key itself (24-word BIP-39 / QR) is the user-held recovery path.
- **Canonical AAD (`S-01`, `AD-01`):** Every `EncryptedEnvelope` authenticates `deep-sky:envelope:v1|coupleId=…|envelopeId=…|senderDeviceId=…|channel=…|keyEpoch=…` (the format version is the `v1` prefix; the key generation is called `keyEpoch` in code and schema). Cross-couple replay, channel confusion, or byte tampering fails AEAD tag verification (`SecretBoxAuthenticationError`).
- **Zero-Second-Phone Recovery & Revocation (`AD-01`, `AD-03`):** Recovering devices claim a server-issued single-use challenge nonce (5-minute TTL) by signing it with the Ed25519 keypair deterministically derived from the Recovery Key and register a fresh device keypair, unwrapping `CMK` locally. `POST /api/v1/pairing/devices/{deviceId}/revoke` revokes a device and removes it from future delivery targets.

## Alternatives Considered

- **Passwords / server-side KMS escrow:** Rejected (`S-01`, `S-06`) — would violate zero-knowledge custody and expose keys on server compromise.
- **Skipping per-device Ed25519 HTTP auth in favor of shared bearer tokens:** Rejected (`AD-02`) — prevents fine-grained revocation and replay protection.

## Consequences & Points for Independent Review (`G-5`)

- **Verified in M1 automation (`proto/sp-02`; re-run on `development` 2026-11-16):** Domain crypto tests (`test/domain/deep_sky_crypto_test.dart`, 7 tests), repository + UI harness tests (`flutter test` -> 60 passed on `development`; 17 at prototype time), `flutter analyze` -> 0 issues, `check-licenses.py --skip-maven` PASSED (82 packages on `development`; 75 at prototype time), and backend ArchUnit + Testcontainers PostgreSQL 17 integration suite (`./mvnw.cmd -B verify`).
- **Verified in M2 on physical hardware (2026-11-15):** Real Android multi-device verification passed for SAS-verified pairing (`F-01`), Recovery Key restoration (`F-20`), cross-device enrollment, E2EE gesture sync (`F-03`), and device revocation (`S-06`).
- **Independent review (`G-5`) focus areas:**
  1. Entropy, domain separation strings, and AAD canonical encoding in `DeepSkyCrypto` & `RecoveryKeyCodec`.
  2. Recovery challenge rate-limiting / brute-force resistance: a per-IP `PublicEndpointRateLimiter` (HTTP 429) now covers the recovery route; review its limits and per-couple lockout behavior.
  3. Key-rotation (`keyEpoch > 1`) automation strategy (not yet implemented) upon `S-06` revocation of a stolen device.
  4. Pure-Dart cryptography (`package:cryptography` without `cryptography_flutter`): evaluate constant-time guarantees and timing side-channel risk on Android devices for `X25519`, `Ed25519`, and `XChaCha20-Poly1305`, deciding whether to add `cryptography_flutter` before `G-5` (`G5-09`).
  5. Android Auto Backup & offline cache exclusion (`AD-06`): verify `AndroidManifest.xml` (`allowBackup="false"`, `dataExtractionRules`, `fullBackupContent`) prevents Google Auto Backup, `adb backup`, or device-to-device transfer from extracting key material, `SharedPreferences`, or local cache (`G5-06`).
- **Remaining pre-dogfooding gate (`PD-05`):** Observe completion by two non-technical testers without verbal coaching (tracked in `docs/m2-operative-plan.md`) before storing real couple data (`PD-05`).
