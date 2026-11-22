# Key Custody and Offline Signing Procedure

**Reference IDs:** `SEC-03`, `SEC-04`, `PD-10`, `AD-08`, `D-14`, `TC-10`

> **Strict rule:** No private key, keystore, passphrase, or recovery seed may ever enter this repository, GitHub Actions, or any chat log. This document records **only** procedures and public fingerprints.

## Keys Managed Offline

Deep Sky requires two offline signing keys controlled by the promoter:

1. **Android APK Signing Key (PKCS#12 / JKS)**
   - Used by `apksigner` to sign every official release APK (`com.vectevo.deep_sky`).
   - Losing this key prevents in-place updates of existing installations (`TC-06`, `D-14`), forcing reinstallation and key recovery.
2. **Ed25519 Manifest & Content Signing Key**
   - Used to sign release manifests (`manifest.json`) and content packs (`content/packs/*`).
   - The corresponding **public key** is embedded in the client app (`TC-10`, section 8.2) so the app verifies manifest authenticity independently before invoking Android installation.

## Offline Generation Procedure (Promoter Workstation / Air-gapped Media)

Perform the following steps locally in an offline working directory outside the repository (e.g. `~/deep-sky-keys/`, never inside the git clone):

### 1. Generate the Android APK Signing Keystore

```bash
keytool -genkeypair \
  -v \
  -keystore deep-sky-release.p12 \
  -storetype PKCS12 \
  -alias deep-sky-release \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=Deep Sky, OU=Vectevo, O=Vectevo, C=IT"
```

Record the SHA-256 certificate fingerprint:

```bash
keytool -list -v -keystore deep-sky-release.p12 -storetype PKCS12 -alias deep-sky-release
```

### 2. Generate the Ed25519 Manifest Signing Keypair

Using JDK 25 via the repository helper (run against an offline directory):

```bash
java scripts/Ed25519Tool.java generate --out-dir ~/deep-sky-keys/ed25519
```

This creates:
- `ed25519-private.pkcs8.b64` (keep **offline** and encrypted)
- `ed25519-public.x509.b64` (public key, safe to embed in app and register below)
- `ed25519-public.sha256` (SHA-256 fingerprint of the SPKI public key)

## Encrypted Backup & Restore Verification (`SEC-03`)

1. Package the offline key directory into a deterministic archive and encrypt it in **two physically distinct locations** (e.g. an encrypted hardware USB drive + an encrypted password-manager/cloud vault using a separate high-entropy passphrase).
2. **Restore test (mandatory before closing `SEC-03`):**
   - On a clean machine or clean user account, restore both backup copies.
   - Verify SHA-256 checksums of the restored files match the originals.
   - Run `scripts/sign-release.sh` / `scripts/sign-release.ps1` on a dummy/debug APK using the restored keys and verify with `apksigner verify` and `Ed25519Tool.java verify`.
   - Securely shred temporary decrypted copies on the test machine after verification.

## Public Fingerprints Registry

Update this table via PR once the promoter generates the production keys (`SEC-03`):

| Key | Algorithm | Status | Public Fingerprint (SHA-256) | Public Key / Notes |
| :-- | :-- | :-- | :-- | :-- |
| APK Release Signing Key (`deep-sky-release`) | RSA 4096 (PKCS#12) | *Pending offline generation by promoter* | `03:6D:19:F4:98:40:12:CC:CD:F2:1D:4E:6E:7E:C2:9A:95:84:2F:E9:78:2B:1D:70:A4:6A:55:59:84:E6:D6:0A` | Never rotate without migration plan (`D-14`) |
| Manifest & Content Signing Key | Ed25519 | **Active**: public key embedded in the app (`DeepSkyController.trustedUpdatePublicKeyB64`, content `keyId` `v1`); fingerprint of the embedded SPKI verified identical on 2026-11-22 (`IR-08`) | `b6bc0deb3a056a1c2e4f28378915cb20a45a926da1f631e7892a43b2fb299292` | Public key will be embedded in app for `F-19` / `N-10` |
