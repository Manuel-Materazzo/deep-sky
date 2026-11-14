# ADR-0003: Android Minimum and Target SDK Versions

- **Status:** Accepted
- **Date:** 2026-11-14
- **Reference IDs:** `APP-01`, `TC-04`, `N-02`, `D-14`

## Context

Deep Sky targets Android first (`TC-04`, `N-02`), distributed as a signed APK from GitHub Releases (`TC-10`). The native Android layer will host the APK installer bridge (`PackageInstaller`), home screen widgets (`F-13`), runtime-initialized Firebase Cloud Messaging (`TC-13`), and Android Keystore-backed local secret storage (`AD-06`).

## Decision

- **`minSdk`:** **26** (Android 8.0 Oreo)
- **`targetSdk` & `compileSdk`:** Track Flutter's current stable SDK target (`flutter.targetSdkVersion` / `flutter.compileSdkVersion`, currently API **36** in Flutter 3.50.0, verified on Android 15/16)

## Alternatives Considered

- **`minSdk = 24` (Flutter default, Android 7.0):** Pros: slightly wider legacy tail. Cons: lacks standard notification channels (API 26), adaptive icons (API 26), and requires extra compat handling for background execution and keystore features.
- **`minSdk = 29` (Android 10):** Pros: stricter scoped storage baseline. Cons: unnecessarily excludes older secondary devices used by couples.

## Consequences

- Android 8.0+ provides native notification channels (`F-16`), adaptive launcher icons, `PackageInstaller` session APIs (`F-19`), and hardware-backed Keystore improvements.
- Any native Android feature added in `M1` (`SP-01`, `SP-03`) or later (`F-13`) can assume API 26+ without legacy API 24–25 workarounds.
- `applicationId` (`com.vectevo.deep_sky`) and release signing key remain immutable (`PD-07`, `D-14`).
