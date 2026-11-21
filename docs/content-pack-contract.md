# Signed Content Micro-Packs Contract (`S2-CTR-01`)

**Version:** 1.0 · **Date:** November 21, 2026 · **References:** `AR-09`, `TC-08`, `TC-10`, `G5-07`, `CNT-01`, `DD-10`, `PD-19`, `AD-06`

This document defines the contract between the publishing pipeline (`scripts/`), the server (`com.vectevo.deep_sky_server.content`), and the Flutter client (`ContentPackService`) for the secure, incremental distribution of the Home graphic packs.

---

## 1. Principles and Trust Model (`G5-07`)

- **Cryptographic trust anchor on the client:** the client embeds an immutable map of **Ed25519** public keys indexed by `keyId` (e.g., `{"v1": "<base64-spki-or-raw-32B>"}`).
- **Server-side verification as an additional operational defense:** the server validates the signature (if trusted public keys are configured), the SHA-256 integrity of all files, and path safety on startup/reload of the `pack_data` volume, refusing to serve corrupted or tampered packs; however, device security depends exclusively on the verification performed by the client.
- **No `.zip`/`.tar` archives:** **file-by-file** distribution driven by `pack-checksums.json`, so the client downloads only new or modified files (micro-packs `v1.0.0 -> v1.1.0 -> v1.2.0` without re-downloading an unchanged floor or window).

---

## 2. Format of `pack-checksums.json` and `pack-checksums.json.sig`

### 2.1 `pack-checksums.json`

```json
{
  "schemaVersion": 1,
  "keyId": "v1",
  "packId": "deep-sky-home-v1",
  "packVersion": "1.0.0",
  "minAppProtocol": 1,
  "files": {
    "manifest.json": {
      "sha256": "<64-hex-lowercase>",
      "sizeBytes": 1824
    },
    "assets/floor.png": {
      "sha256": "<64-hex-lowercase>",
      "sizeBytes": 195420
    }
  }
}
```

Field constraints:
- `schemaVersion`: integer `>= 1`.
- `keyId`: string `^[a-z0-9][a-z0-9_-]{0,31}$` identifying the Ed25519 public key used to sign the file.
- `packId`: pack identifier; must match `manifest.json`.
- `packVersion`: semver `MAJOR.MINOR.PATCH` (`0|[1-9]\d*`).
- `minAppProtocol`: integer `>= 1`; the client rejects packs with `minAppProtocol > appProtocolVersion`.
- `files`: map `relativePath -> { sha256, sizeBytes }`. Must always include `manifest.json`. Every `relativePath` must be relative, use `/`, and contain no `..`, `\`, leading `/`, or control characters.

### 2.2 `pack-checksums.json.sig`

To strictly comply with `G5-07` (**Ed25519 signature verification on raw bytes before any JSON parsing**), the `.sig` file carries the `keyId` outside the JSON in a single-line text format:

```text
<keyId>:<base64-signature-64-bytes>
```

Example:
```text
v1:9f3b...==
```

Client-side verification rules (mandatory order):
1. Read the raw bytes of `pack-checksums.json` and the contents of `pack-checksums.json.sig`.
2. Extract `keyId` and the 64 signature bytes from `.sig` (format `keyId:base64`; in the absence of a `keyId:` prefix, for test backward-compatibility only, `v1` is assumed if and only if the decoded bytes are exactly 64).
3. Look up `trustedKeys[keyId]`. If `keyId` is unknown → **immediate rejection** (`unknownKeyId`), without calling `jsonDecode`.
4. Verify the Ed25519 signature on the **raw bytes** of `pack-checksums.json`. If invalid → **immediate rejection** (`signatureInvalid`), without calling `jsonDecode`.
5. Only after a valid signature, run `jsonDecode` on `pack-checksums.json` and verify that `payload.keyId == sigKeyId` (prevents `keyId` substitution between envelope and payload).

---

## 3. Distribution HTTP API (`S2-SRV-01`)

All endpoints are served under `/api/v1/content/pack` as read-only (`GET`) and are integrated with `GET /api/v1/system/compatibility`:

| Endpoint | Response | HTTP Caching |
| :-- | :-- | :-- |
| `GET /api/v1/system/compatibility` | `{ minClientVersionCode, minProtocolVersion, minPackVersion }` | No strong caching |
| `GET /api/v1/content/pack/checksums` | Raw bytes of `pack-checksums.json` (`application/json`) | `ETag: "<sha256>"`, `Cache-Control: no-cache`, `If-None-Match` support -> `304` |
| `GET /api/v1/content/pack/checksums.sig` | Raw bytes of `pack-checksums.json.sig` (`text/plain; charset=utf-8`) | `ETag: "<sha256>"`, `Cache-Control: no-cache`, `If-None-Match` support -> `304` |
| `GET /api/v1/content/pack/blobs/{sha256}` | Raw bytes of the active pack file whose SHA-256 matches (`image/png`, `image/jpeg`, `application/json`). `sha256` must match `^[0-9a-f]{64}$` (otherwise `400`); hash not present in the active pack -> `404` | `ETag: "<sha256>"`, `Cache-Control: public, max-age=31536000, immutable`, strict `Content-Length`, `If-None-Match` support -> `304`. **Endpoint used by the client** |
| `GET /api/v1/content/pack/files/{*relativePath}` | Raw bytes of the file specified by path (same content types). Kept for compatibility | `ETag: "<file-sha256>"`, `Cache-Control: no-cache` (mandatory revalidation), strict `Content-Length`, `If-None-Match` support -> `304` |

Caching rules (`S2-SRV-01`):
- Only **content-addressed** URLs (`/blobs/{sha256}`) may be `immutable`: the URL changes when the bytes change, so no intermediate cache can serve stale content.
- **Path-based** URLs (`/files/**`) reuse the same path across pack versions (`v1.0.0` -> `v1.1.0`): therefore they respond with `no-cache` + `ETag` and the client does not use them for downloads. Marking them `immutable` would cause permanent SHA-256 mismatches on the client behind an intermediate cache.
- `checksums` and `checksums.sig` remain `no-cache` + `ETag`.

Publishing and reloading on the server: the active pack is read from the `pack_data` volume (`DEEPSKY_CONTENT_PACKS_DIR`) at startup and automatically reloaded every 60 s if `pack-checksums.json` or `.sig` changes; if verification fails, the last valid pack continues to be served. See `docs/server-configuration.md`.

Server security:
- Any path not present in the `files` allowlist of the active `pack-checksums.json` or containing `..` / `\` / external symlinks returns `400` or `404`.
- If no valid pack is present on the server (or defensive verification at startup fails), `/api/v1/content/pack/**` endpoints respond with `404 Not Found` and the client continues using the pack bundled in the APK without blocking errors.

---

## 4. Persistent Anti-Downgrade Protection (`AD-06`, `PD-19`)

Because Android has `allowBackup="false"` (`AD-06`), after a reinstall the local `localMaxSeenPackVersion` starts back from zero. To prevent silent downgrades even after a reinstall, the minimum acceptable version is always:

```text
minAcceptablePackVersion = max(
    bundledPackVersion,       // e.g. "1.0.0" compiled into the APK
    localMaxSeenPackVersion,  // highest valid version ever activated locally
    serverMinPackVersion      // exposed by GET /api/v1/system/compatibility
)
```

A pack with `packVersion < minAcceptablePackVersion` is always rejected (`downgradeRejected`).

---

## 5. Update Modes, Staging, and "Last Known Good Pack" Rollback

### 5.1 Local Disk Layout (app-private storage)
- `content_packs/blobs/<sha256>`: content-addressed cache of individual already-verified files (to avoid re-downloading unchanged files across `v1.0.0`, `v1.1.0`, and `v1.2.0`). After each `staged -> active` promotion (at startup or via manual update), blobs not referenced by the `active`, `previous`, and `staged` packs are deleted.
- `content_packs/staged/<packVersion>/`: fully verified pack (signature + SHA-256 + `SceneManifestParser`), ready for promotion.
- `content_packs/active/<packVersion>/`: active pack.
- `content_packs/previous/<packVersion>/`: previous last-known-good pack.
- Metadata in `SecureKeyStore` / local file (`activeVersion`, `previousVersion`, `stagedVersion`, `maxSeenVersion`, `etag`, `packBootAttempts`).

### 5.2 Two Update Modes
1. **Automatic in background (`syncSilently`):**
   - Runs only on an **unmetered** network (Wi-Fi by default via `ConnectivityManager.isActiveNetworkMetered == false`).
   - Uses `If-None-Match` on `/checksums`; if changed, downloads only files whose SHA-256 is missing from the local `blobs/` cache, assembles them in `staged/<packVersion>/`, and **does not replace the UI mid-flight**: it will be promoted to `active` on the next launch.
2. **Manual "Update graphics" button in Settings (`forceUpdateAndReloadNow`, `S2-D09`):**
   - Bypasses the unmetered-network constraint and forces the check even on mobile data.
   - Downloads new files, validates signature and hashes, immediately promotes `staged -> active` (saving the previous one in `previous`), **evicts the previous pack's textures from `PaintingBinding.instance.imageCache`**, and immediately reloads `SceneManifest` in the UI without closing the app.

### 5.3 Automatic "Last Known Good Pack" Rollback
- On app startup, before loading an external `active` pack:
  - if a valid `staged` pack exists, it is promoted to `active` (moving the old `active` to `previous`) and `packBootAttempts` is reset to `0`;
  - then `packBootAttempts` is incremented (`+= 1`) and persisted before rendering the Home screen.
- When the Home screen successfully completes its first frame (`WidgetsBinding.instance.addPostFrameCallback`), the controller calls `markHomeBootSucceeded()`, which resets `packBootAttempts = 0`. The same reset occurs on the first frame of a pre-Home screen for an already-paired device (space setup or recovery key) that does not draw the pack, so a launch that does not show Home does not count as a failure.
- If on the next boot `packBootAttempts >= 2` (the Home screen crashed or never completed its first frame for 2 consecutive launches), the client performs an automatic rollback:
  - restores `previous` if present and valid, otherwise falls back to the pack bundled in the APK (`bundled`);
  - records the faulty pack (`blockedVersion`) so it is not automatically re-promoted until a newer version arrives.
