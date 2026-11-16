# ADR-0008: Signed-Manifest Self-Update & PackageInstaller Flow (`SP-03`)

- **Status:** Accepted (verified on real Android hardware across offline-signed GitHub Release upgrades)
- **Date:** 2026-11-15 (baseline 2026-11-14)
- **Reference IDs:** `F-19`, `TC-10`, `SEC-04`, `D-14`, `SP-03`

## Context

Deep Sky distributes outside Google Play (`TC-10`, `F-19`) and uses offline promoter release signing (`scripts/sign-release.*`, `SEC-04`). The client updater must validate manifest authenticity before trusting metadata, block downgrades or mismatched signing keys that would wipe local keys, support resumable downloads, check free storage upfront, and surface Android's `"Install unknown apps"` permission clearly in plain language.

## Decision

The prototype on branch `proto/sp-03` implements `docs/sp-03-apk-updater.md`:

- **Cryptographic Verification Chain:** `ApkUpdateService` downloads `manifest.json` and `manifest.json.sig` from the pinned repository slug (`Manuel-Materazzo/deep-sky`) or a developer-unlocked HTTPS mirror (plain `http://` is restricted to local/private addresses), verifies the Ed25519 signature over the raw `manifest.json` bytes before JSON parsing, enforces `packageId` match and strictly increasing `versionCode`, checks storage via `StatFs` (`apkSizeBytes + 20 MB`), resumes interrupted `.part` downloads via HTTP `Range` requests with exponential backoff, deletes corrupted/oversized `.part` files on any length or hash mismatch, and verifies the downloaded APK `SHA-256` against `manifest.apkSha256` via streaming (`Sha256().newHashSink()`) without buffering the entire APK in RAM.
- **Trust Anchor Policy (`CA-11`):** The release signing Ed25519 public key and repository slug are pinned in the client (`DeepSkyController.trustedUpdatePublicKeyB64` / `defaultUpdateSource`). Custom mirrors and custom Ed25519 keys are ignored by default and gated behind an explicit collapsed developer/advanced switch (`allowCustomUpdateTrustAnchor`) so non-technical users cannot accidentally weaken the trust anchor.
- **Pre-Install Archive Certificate Guard (`ApkInstallerCoordinator.kt`):** Before opening Android's `PackageInstaller.Session`, Kotlin inspects `PackageManager.getPackageArchiveInfo(..., GET_SIGNING_CERTIFICATES)` against the installed package certificates and rejects signature mismatches cleanly without risking app uninstall/data loss.
- **Permission & Session Handling:** Checks `canRequestPackageInstalls()`, opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES`, and commits sessions via `InstallResultReceiver` (`STATUS_PENDING_USER_ACTION`).

## Alternatives Considered

- **Relying solely on Android's package installer to reject signature mismatches or downgrades:** Gives cryptic OS failure codes after committing session bytes and creates poor UX. Pre-flight verification gives clear localized recovery guidance.

## Consequences

- **Verified in M1 automation (`proto/sp-03`):** `test/data/apk_update_service_test.dart` passed all tests (tampered manifest -> `signatureInvalid`, non-increasing `versionCode` -> `versionNotHigher`, HTTP `206` chunked resume after `SocketException`, SHA-256 mismatch rejection -> `apkHashMismatch`, insufficient storage check, alternate repository URL resolution); `flutter analyze` (0 issues), `check-licenses.py --skip-maven` PASSED (39 packages), and `flutter build apk --debug` compiled all Kotlin native code cleanly.
- **Verified in M2 on physical hardware (2026-11-15):** Real Android device testing passed for signed manifest verification, APK download, and in-place offline-signed release upgrades via GitHub Releases (`F-19`, `PD-06`). Also fixed repository slug (`Manuel-Materazzo/deep-sky`) and integer `versionCode` serialization in `scripts/sign-release.ps1` discovered during live testing.
