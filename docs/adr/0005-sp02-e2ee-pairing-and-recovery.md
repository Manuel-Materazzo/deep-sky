# ADR-0005: E2EE Pairing, Recovery, Cross-Device Enrollment, and Revocation (`SP-02`)

- **Status:** Proposed (pending physical-device & non-technical usability sign-off)
- **Date:** 2026-11-14
- **Reference IDs:** `S-01`, `S-03`, `S-04`, `S-05`, `S-06`, `F-01`, `F-02`, `AD-01`, `AD-02`, `AD-03`, `SP-02`

## Context

Deep Sky must establish end-to-end encrypted communication between two partner devices (`P-01`, `S-01`), support enrollment of an additional device without leaking long-term secrets to the server, enable full couple-key recovery using only a user-held Recovery Key when no other device is available, and support immediate revocation of lost or compromised devices (`S-06`), all while ensuring the server stores zero readable couple content (`S-01`, `S-03`).

## Decision

The prototype on branch `proto/sp-02` implements and validates the protocol specified in `docs/sp-02-e2ee-protocol.md`:

- **Cryptographic Primitives:** X25519 (ECDH pairing & ephemeral wrapping), Ed25519 (per-device HTTP request authentication `AD-02` & recovery proof), HKDF-SHA256 (key derivation), XChaCha20-Poly1305 AEAD (`package:cryptography` `2.9.0`), BIP-39 24-word mnemonic + checksummed `deepsky-rk:v1:` QR (`bip39_mnemonic` `4.1.0`).
- **Key Hierarchy:** A random 256-bit `CoupleMasterKey` (`CMK`) is sealed under two independent wrappers: a pairwise X25519 SAS-verified delivery (`HKDF(shared, info="deepsky-pair-wrap-v1" || inviteId)`) and a Recovery Key wrapper stored as an opaque AEAD blob (`recovery_wrapped_cmk`). Per-channel keys (`timeline`, `capsules`, `profile`, `scene`, `countdowns`) derive via HKDF-SHA256 from `CMK`.
- **Canonical AAD (`S-05`):** Every `EncryptedEnvelope` authenticates `coupleId | envelopeId | channel | senderDeviceId | version | keyGeneration`. Cross-couple replay, channel confusion, or byte tampering fails AEAD tag verification (`SecretBoxAuthenticationError`).
- **Zero-Second-Phone Recovery & Revocation (`AD-01`, `AD-03`):** Recovering devices claim a server-issued 60-second nonce by signing it with the Ed25519 keypair deterministically derived from the Recovery Key and register a fresh device keypair, unwrapping `CMK` locally. `DELETE /api/v1/devices/{id}` revokes a device and removes it from future delivery targets.

## Alternatives Considered

- **Passwords / server-side KMS escrow:** Rejected (`S-01`, `S-03`) — would violate zero-knowledge custody and expose keys on server compromise.
- **Skipping per-device Ed25519 HTTP auth in favor of shared bearer tokens:** Rejected (`AD-02`) — prevents fine-grained revocation and replay protection.

## Consequences & Points for Independent Review (`G-5`)

- **Verified in M1 automation (`proto/sp-02`):** Domain crypto tests (`test/domain/deep_sky_crypto_test.dart`, 7 tests), repository + UI harness tests (`flutter test` -> 17 passed, `flutter analyze` -> 0 issues), `check-licenses.py --skip-maven` PASSED (75 packages), and backend ArchUnit + Testcontainers PostgreSQL 17 integration suite (`./mvnw.cmd -B verify`).
- **Independent review (`G-5`) focus areas:**
  1. Entropy, domain separation strings, and AAD canonical encoding in `DeepSkyCrypto` & `RecoveryKeyCodec`.
  2. Recovery challenge rate-limiting / brute-force resistance when promoted alongside M2 production controllers.
  3. Key-rotation (`keyGeneration > 1`) automation strategy upon `S-06` revocation of a stolen device.
- **Remaining physical verification before `G-1`:** Two real Android devices completing pairing, recovery, enrollment, revocation, and observed completion by two non-technical testers without verbal coaching.
