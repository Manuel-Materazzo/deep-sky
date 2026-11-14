# Release Signing & Publishing Workflow

**Reference IDs:** `CI-02`, `SEC-04`, `PD-10`, `TC-10`

## Flow Overview

CI never holds signing keys (`PD-10`). Every release APK and manifest follows a strict three-step flow:

1. **Build release artifacts & draft release in CI (`CI-02`, `SRV-02`):**
   - Run the **Release Artifacts** workflow (`.github/workflows/release.yml`) on GitHub Actions with `version_name` and `version_code`.
   - The workflow builds and pushes the multi-arch backend image (`ghcr.io/manuel-materazzo/deep-sky-server:<version_name>` and `:latest`), builds the unsigned Android APK (`deep-sky-unsigned-<version_name>-<version_code>` workflow artifact), and creates (or updates) a **draft** GitHub Release `v<version_name>` with `release-info.json`, `app-release-unsigned.apk.sha256`, and the server image digest.
   - Download the `deep-sky-unsigned-<version_name>-<version_code>` artifact containing `app-release-unsigned.apk`, its SHA-256 checksum, and `release-info.json`.
2. **Sign locally offline (`SEC-04`):**
   - Verify the downloaded APK checksum (`sha256sum -c app-release-unsigned.apk.sha256`).
   - Run the local signing script against your offline keys (never inside the git repository):
     ```bash
     # Linux / macOS
     DEEPSKY_KS_PASS=... DEEPSKY_KEY_PASS=... ./scripts/sign-release.sh \
       --apk ~/Downloads/app-release-unsigned.apk \
       --version-name 1.0.0 \
       --version-code 1 \
       --prev-version-code 0 \
       --keystore ~/deep-sky-keys/deep-sky-release.p12 \
       --alias deep-sky-release \
       --ed25519-key ~/deep-sky-keys/ed25519/ed25519-private.pkcs8.b64 \
       --ed25519-pub ~/deep-sky-keys/ed25519/ed25519-public.x509.b64 \
       --out-dir ~/deep-sky-releases/1.0.0
     ```
     ```powershell
     # Windows PowerShell
     $env:DEEPSKY_KS_PASS = "..."
     $env:DEEPSKY_KEY_PASS = "..."
     powershell -ExecutionPolicy Bypass -File scripts/sign-release.ps1 `
       -UnsignedApk "$HOME\Downloads\app-release-unsigned.apk" `
       -VersionName "1.0.0" `
       -VersionCode 1 `
       -PreviousVersionCode 0 `
       -KeystorePath "$HOME\deep-sky-keys\deep-sky-release.p12" `
       -KeystoreAlias "deep-sky-release" `
       -Ed25519PrivateKeyPath "$HOME\deep-sky-keys\ed25519\ed25519-private.pkcs8.b64" `
       -Ed25519PublicKeyPath "$HOME\deep-sky-keys\ed25519\ed25519-public.x509.b64" `
       -OutDir "$HOME\deep-sky-releases\1.0.0"
     ```
   - The script rejects non-increasing `versionCode`, signs the APK, verifies it via `apksigner verify --verbose`, generates `manifest.json` with the signed APK's SHA-256, and signs `manifest.json` -> `manifest.json.sig`.
3. **Publish GitHub Release:**
   - Open the auto-created draft release `v<version_name>` on GitHub Releases (targeted at the exact CI-tested commit).
   - Upload `deep-sky-<version_name>-<version_code>.apk`, `manifest.json`, and `manifest.json.sig` to the draft release, then click **Publish release**.
