# Signed Content Micro-Packs Contract (`S2-CTR-01`)

**Version:** 1.1 · **Date:** November 22, 2026 · **References:** `AR-09`, `TC-08`, `TC-10`, `G5-07`, `CNT-01`, `DD-10`, `PD-19`, `AD-06`, independent review `IR-01`, `IR-03`..`IR-06`, `IR-N1`..`IR-N3`

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
  "type": "deep-sky/pack-checksums",
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
- `type`: signing context / domain separator, constant `"deep-sky/pack-checksums"` (`IR-06`). The same Ed25519 key also signs APK release manifests, so this keeps a signed APK manifest from ever being replayed as a pack, and vice versa. **`PD-19` transitional rule:** emitted by `scripts/sign_content.py` from now on; client and server **accept payloads without `type`** (packs already published and signed with the offline key are not re-signed), but if `type` is present it **must equal** `deep-sky/pack-checksums`, otherwise the pack is rejected (`checksumsInvalid` on the client, not loaded on the server). It becomes **mandatory in a later release**, once every published pack has been re-signed; that release will drop the "absent" branch.
- `schemaVersion`: integer `>= 1`.
- `keyId`: string `^[a-z0-9][a-z0-9_-]{0,31}$` identifying the Ed25519 public key used to sign the file.
- `packId`: pack identifier; must match `manifest.json` **and** the `packId` of the Home pack bundled in the APK (`deep-sky-home-v1`); see §2.2 step 6 (`IR-01`).
- `packVersion`: semver `MAJOR.MINOR.PATCH` (`0|[1-9]\d*`).
- `minAppProtocol`: integer `>= 1`; the client rejects packs with `minAppProtocol > appProtocolVersion`.
- `files`: map `relativePath -> { sha256, sizeBytes }`. Must always include `manifest.json`. Every `relativePath` must be relative, use `/`, and contain no `..`, `\`, `:`, leading `/`, or control characters, meaning any code point in `U+0000`-`U+001F` or `U+007F` (`IR-N2`, enforced identically by client, server and `scripts/validate_content.py`).

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
2. Extract `keyId` and the 64 signature bytes from `.sig`. The `keyId:base64` envelope is **mandatory**: a raw 64-byte signature or an unprefixed base64 string is rejected (`signatureInvalid`) and never defaulted to `v1` (`IR-N1`; `scripts/sign_content.py` has always emitted the prefix). The server applies the same rule when it loads a pack.
3. Look up `trustedKeys[keyId]`. If `keyId` is unknown → **immediate rejection** (`unknownKeyId`), without calling `jsonDecode`.
4. Verify the Ed25519 signature on the **raw bytes** of `pack-checksums.json`. If invalid → **immediate rejection** (`signatureInvalid`), without calling `jsonDecode`.
5. Only after a valid signature, run `jsonDecode` on `pack-checksums.json` and verify that `payload.keyId == sigKeyId` (prevents `keyId` substitution between envelope and payload) and, when present, `payload.type == "deep-sky/pack-checksums"` (`IR-06`).
6. **Pack identity pinning (`IR-01`).** The sync caller passes the expected `packId` (taken from the bundled manifest, `deep-sky-home-v1`). A payload whose `packId` differs is rejected with `packIdMismatch` **before** the anti-downgrade check (§4), so a validly signed pack for another purpose can never install as the Home scene nor touch the global `maxSeenVersion` floor. The same check applies to the manifest of every `staged`, `active` and `previous` pack loaded from disk at startup: a pack whose manifest `packId` differs is treated like any other invalid pack (staged: discarded; active/previous: skipped by the fallback chain). If several packs with different `packId` are ever distributed, `maxSeenVersion` and the staged/active/previous slots must first be keyed by `packId`.

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

Server version floor (`IR-04`, `S2-CTR-01`): the server compares `packVersion` of the pack it loads with its own advertised `minPackVersion` (`DEEPSKY_MIN_PACK_VERSION`, numeric `MAJOR.MINOR.PATCH` comparison). A pack **below** it is refused at load and reload, so the previously loaded valid pack keeps being served instead of every client failing with `downgradeRejected`. Server-side `type` (`IR-06`), `keyId:base64` envelope (`IR-N1`) and control-character path (`IR-N2`) checks mirror the client rules in §2. Server-side signature verification itself remains optional when no trusted key is configured (the client is the trust anchor).

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

A pack with `packVersion < minAcceptablePackVersion` is always rejected (`downgradeRejected`). The identity check of §2.2 step 6 (`packIdMismatch`) runs first, so only packs for the Home `packId` can ever raise `localMaxSeenPackVersion`.

---

## 5. Update Modes, Staging, and "Last Known Good Pack" Rollback

### 5.1 Local Disk Layout (app-private storage)
- `content_packs/blobs/<sha256>`: content-addressed cache of individual already-verified files (to avoid re-downloading unchanged files across `v1.0.0`, `v1.1.0`, and `v1.2.0`). After each `staged -> active` promotion (at startup or via manual update), blobs not referenced by the `active`, `previous`, and `staged` packs are deleted.
- `content_packs/staged/<packVersion>/`: fully verified pack (signature + SHA-256 + `SceneManifestParser`), ready for promotion.
- `content_packs/active/<packVersion>/`: active pack.
- `content_packs/previous/<packVersion>/`: previous last-known-good pack.
- Metadata in `SecureKeyStore` / local file (`activeVersion`, `previousVersion`, `stagedVersion`, `maxSeenVersion`, `etag`, `packBootAttempts`).
- The stored `etag` always describes the pack currently staged or active. It is **cleared** whenever a staged pack is discarded at startup (manifest fails to load, wrong `packId`, or below the minimum acceptable version) and whenever the active pack is dropped or rolled back (to `previous` or to the bundled pack), so the next silent check sends no `If-None-Match` and cannot stall on `304` (`IR-05`).

### 5.2 Two Update Modes
1. **Automatic in background (`syncSilently`):**
   - Runs only on an **unmetered** network (Wi-Fi by default via `ConnectivityManager.isActiveNetworkMetered == false`).
   - Uses `If-None-Match` on `/checksums`; if changed, downloads only files whose SHA-256 is missing from the local `blobs/` cache, assembles them in `staged/<packVersion>/`, and **does not replace the UI mid-flight**: it will be promoted to `active` on the next launch.
2. **Manual "Update graphics" button in Settings (`forceUpdateAndReloadNow`, `S2-D09`):**
   - Bypasses the unmetered-network constraint and forces the check even on mobile data.
   - If the server's `packVersion` equals the version already active **and** the `active/<version>` directory still loads and verifies, it returns `upToDate` early without downloading, rebuilding or moving anything, so the files on screen are never replaced under the UI (`IR-N3`). A damaged active directory takes the normal rebuild path.
   - Downloads new files, validates signature and hashes, immediately promotes `staged -> active` (saving the previous one in `previous`), **evicts the previous pack's textures from `PaintingBinding.instance.imageCache`**, and immediately reloads `SceneManifest` in the UI without closing the app.

### 5.3 Automatic "Last Known Good Pack" Rollback
- On app startup, before loading an external `active` pack:
  - if a valid `staged` pack exists, it is promoted to `active` (moving the old `active` to `previous`) and `packBootAttempts` is reset to `0`;
  - then `packBootAttempts` is incremented (`+= 1`) and persisted before rendering the Home screen.
- **Success criterion (`IR-03`).** For a file-system pack, `markHomeBootSucceeded()` is called only after the **active layers have resolved**: `HybridSceneCanvas` reports (`onActiveLayersResolved`) once every image provider it actually renders (background plus the layers of the current slot states, including the bounded `ResizeImage` wrappers, so no extra full-size decode happens, `ADR-0007`) has decoded. If any of them fails to load, the counter is **not** reset, so a signed-but-broken asset leads to the rollback below after two launches. For the bundled pack (cannot be a bad download) it is still called at the first post-frame callback (`WidgetsBinding.instance.addPostFrameCallback`). A decode failure only prevents the reset; it does not itself roll back mid-session. `markHomeBootSucceeded()` resets `packBootAttempts = 0`. The same reset occurs on the first frame of a pre-Home screen for an already-paired device (space setup or recovery key) that does not draw the pack, so a launch that does not show Home does not count as a failure.
- If on the next boot `packBootAttempts >= 2` (the Home screen crashed or never completed its first frame for 2 consecutive launches), the client performs an automatic rollback:
  - restores `previous` if present and valid, otherwise falls back to the pack bundled in the APK (`bundled`);
  - records the faulty pack (`blockedVersion`) so it is not automatically re-promoted until a newer version arrives.
