# ADR-0008: Signed-Manifest Self-Update & PackageInstaller Flow (`SP-03`)

- **Status:** Accepted as M1/M2 baseline (physical 2-device upgrade prompt logging carried into M2)
- **Date:** 2026-11-14
- **Reference IDs:** `F-19`, `TC-10`, `SEC-04`, `D-14`, `SP-03`

## Context

Deep Sky distributes outside Google Play (`TC-10`, `F-19`) and uses offline promoter release signing (`scripts/sign-release.*`, `SEC-04`). The client updater must validate manifest authenticity before trusting metadata, block downgrades or mismatched signing keys that would wipe local keys, support resumable downloads, check free storage upfront, and surface Android's `"Install unknown apps"` permission clearly in plain language.

## Decision

The prototype on branch `proto/sp-03` implements `docs/sp-03-apk-updater.md`:

- **Cryptographic Verification Chain:** `ApkUpdateService` downloads `manifest.json` and `manifest.json.sig` from a configurable repository slug or custom HTTPS base URL, verifies the Ed25519 signature over the raw `manifest.json` bytes before JSON parsing, enforces `packageId` match and strictly increasing `versionCode`, checks storage via `StatFs` (`apkSizeBytes + 20 MB`), resumes interrupted `.part` downloads via HTTP `Range` requests, and verifies the downloaded APK `SHA-256` against `manifest.apkSha256`.
- **Pre-Install Archive Certificate Guard (`ApkInstallerCoordinator.kt`):** Before opening Android's `PackageInstaller.Session`, Kotlin inspects `PackageManager.getPackageArchiveInfo(..., GET_SIGNING_CERTIFICATES)` against the installed package certificates and rejects signature mismatches cleanly without risking app uninstall/data loss.
- **Permission & Session Handling:** Checks `canRequestPackageInstalls()`, opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES`, and commits sessions via `InstallResultReceiver` (`STATUS_PENDING_USER_ACTION`).

## Alternatives Considered

- **Relying solely on Android's package installer to reject signature mismatches or downgrades:** Gives cryptic OS failure codes after committing session bytes and creates poor UX. Pre-flight verification gives clear localized recovery guidance.

## Consequences

- **Verified in M1 automation (`proto/sp-03`):** `test/data/apk_update_service_test.dart` passed all tests (tampered manifest -> `signatureInvalid`, non-increasing `versionCode` -> `versionNotHigher`, HTTP `206` chunked resume after `SocketException`, SHA-256 mismatch rejection -> `apkHashMismatch`, insufficient storage check, alternate repository URL resolution); `flutter analyze` (0 issues), `check-licenses.py --skip-maven` PASSED (39 packages), and `flutter build apk --debug` compiled all Kotlin native code cleanly.
- **Transitioned into M2 (`G-2` gate):** Record exact OS confirmation prompt counts across Android versions during M2's two consecutive offline-signed release upgrades on physical devices (`docs/m2-operative-plan.md`) and verify rejected mismatched-key APK handling on hardware.
