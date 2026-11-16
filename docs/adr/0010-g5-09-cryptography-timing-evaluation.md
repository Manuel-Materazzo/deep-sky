# ADR-0010: Cryptography Library Evaluation: `cryptography` (pure Dart) vs `cryptography_flutter` (`G5-09`)

- **Status:** Proposed (decision deferred to the external security review `G-5`; technical request prepared in `M2` / `G-2`)
- **Date:** 2026-11-15
- **Reference IDs:** `G5-09`, `S-01`, `S-06`, `N-06`, `AD-01`, `AD-06`, [Architecture](../architecture.md) §7.1, [Development plan](../development-plan.md) ch. 6.3 / 6.7

## Context

Since the M2 review (`PR-M2-01`, `PR-M2-04`), the Flutter client uses only `package:cryptography ^2.9.0` (pure-Dart implementation) for:

- **Ed25519:** per-request HTTP signature (`X-Signature` toward `DeviceAuthFilter`), Recovery Key verification (`RecoveryController`) and APK manifest verification (`ApkUpdateService`);
- **X25519:** ECDH key agreement in pairing and multi-device enrollment (`AD-02`);
- **HKDF-SHA256:** derivation of `K_root`, `recoveryAuthKeyPair`, wrap keys and the offline local cache key (`AD-06`);
- **XChaCha20-Poly1305:** authenticated end-to-end encryption of all envelopes (`EVENT`, `SNAPSHOT`) and of the encrypted local cache.

`cryptography_flutter` has not been added in M2, to keep the Android build uniform across Kotlin/Flutter until the `G-5` security audit.

Timing-risk profile:

| Aspect | Current state (`cryptography`, pure Dart) | Candidate (`cryptography_flutter` + native providers) |
| :--- | :--- | :--- |
| **Execution model** | Dart AOT VM (arm64/x86_64 Android) with no runtime guarantee of constant-time dedicated crypto/SIMD instructions | Delegates to native Android providers (`Cipher` / BoringSSL / Conscrypt where supported) or falls back to Dart |
| **Timing attack surface** | Very low remote exposure: envelopes use per-couple symmetric keys and the server is not an interactive decryption oracle (`XChaCha20-Poly1305` verifies the tag before releasing plaintext); **residual local risk** from co-resident processes (cache/timing side channels) on scalar X25519/Ed25519 operations in pure Dart | Reduced local side-channel risk for natively supported primitives; needs verification of which algorithms have a real native backend on API 26–35 (notably `XChaCha20` vs standard `AES-GCM` / `ChaCha20-Poly1305`) |
| **Keystore / backup impact** | Keys stay in `flutter_secure_storage` with `allowBackup="false"` (`AD-06`) | To be evaluated in `G-5`: whether to add a hardware-backed `AndroidKeyStore` wrapper for the device auth key or the local cache encryption key |

## Decision

Deferred. In M2 the dependency is not changed: `cryptography: ^2.9.0` stays pinned in `pubspec.yaml`, annotated `G5-09`. Any adoption of `cryptography_flutter` or native bindings will be a dedicated PR after the `G-5` reviewer responds, without breaking the existing E2EE envelope format.

Formal questions for the `G-5` security reviewer:

1. Does pure-Dart `cryptography` for **X25519** and **Ed25519** on Android ARM64 pose an acceptable risk for Deep Sky's threat model (private couple, personal non-shared device, `allowBackup="false"`), or is an upgrade to a constant-time native backend (`cryptography_flutter` / FFI libsodium/BoringSSL) required?
2. For local/network encryption, is pure-Dart `XChaCha20-Poly1305` preferable to `ChaCha20-Poly1305` / `AES-256-GCM` accelerated via `cryptography_flutter` (Conscrypt/BoringSSL) on API >= 26?
3. Is a hardware-backed `AndroidKeyStore` binding (`StrongBox` / `TEE`) recommended for the device Ed25519 private key and the offline cache key (`EncryptedLocalCache`), keeping only the 24-word recovery seed portable (`F-20`)?

## Alternatives Considered

- **Adopt `cryptography_flutter` now:** Pros: possible native constant-time backends. Cons: coverage on API 26–35 unverified (notably `XChaCha20`), added native build complexity before the audit, risk of format drift.
- **Keep pure-Dart `cryptography` (current):** Pros: uniform behavior across devices, simple build, already covered by tests and hardware verification. Cons: no constant-time guarantee from the runtime (low residual local risk).

## Consequences

- No code change in M2; the question is tracked as `G5-09` in the `G-5` review list.
- The outcome of `G-5` will either confirm this ADR (Accepted) or lead to a new ADR superseding it, with a dedicated migration PR that preserves the envelope format.
