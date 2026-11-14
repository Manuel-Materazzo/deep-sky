# Real-Device Testing Procedure (Android)

**Reference IDs:** `APP-01`, `APP-03`, `PD-06`, `N-02`

## Prerequisites

- Android phone with **USB Debugging** (or Wireless Debugging) enabled in Developer Options
- `adb` available on PATH (`adb version`)
- Flutter SDK (`flutter doctor -v` clean for Android toolchain)

## 1. Debug Build & Installation (`APP-01`)

1. Connect the device and verify authorization:
   ```bash
   adb devices
   ```
2. Run pre-flight checks:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
3. Build and install the debug APK:
   ```bash
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
   Or launch directly with `flutter run`.

## 2. Two-Device Verification Checklist (for M1+ / M2+ slices)

When testing features involving pairing, E2EE, push notifications, or in-app APK updates across two physical phones:

- Record device model, Android API level, and OEM battery-saver settings.
- Never use real personal photos, names, or secrets before `G-2` (`PD-05`).
- For APK update tests (`SP-03`, `F-19`), test exclusively with a **test signing key** (never the production key) until official releases begin.
- Capture redacted logs (`adb logcat -d`) and screenshots (without personal info) as PR evidence.
