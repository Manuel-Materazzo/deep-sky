# Server Configuration Reference

**Reference IDs:** `SRV-03`, `INF-04`, `TC-02`, `TC-10`, `TC-13`

All configuration is supplied via environment variables (or Docker secrets mapped into environment/property files). The server validates required production settings at startup and fails fast with explicit diagnostic messages.

## Parameters

| Property (`deepsky.*`) | Environment Variable | Default (`dev` / base) | Required in `prod` | Description |
| :-- | :-- | :-- | :-- | :-- |
| `deepsky.domain` | `DEEPSKY_DOMAIN` | `localhost` | Yes | Public domain of the instance (e.g. `deepsky.vectevo.com`) |
| `deepsky.admin-secret` | `DEEPSKY_ADMIN_SECRET` | `dev-admin-secret-change-me` (dev only) | Yes (>= 24 chars, non-default) | Reserved admin secret for future self-hoster operational endpoints (`AU-28`: currently validated at startup in `prod`, no active endpoint consumes it yet) |
| `deepsky.protocol.min-client-version-code` | `DEEPSKY_MIN_CLIENT_VERSION_CODE` | `1` | No (`1`) | Minimum Android `versionCode` allowed by the server (`F-19`, `N-10`) |
| `deepsky.protocol.min-protocol-version` | `DEEPSKY_MIN_PROTOCOL_VERSION` | `1` | No (`1`) | Minimum E2EE/snapshot protocol version (`TC-05`, `8.2`) |
| `deepsky.quotas.max-blob-bytes` | `DEEPSKY_MAX_BLOB_BYTES` | `10485760` (10 MiB) | No | Maximum single encrypted blob upload size (note `AU-21`: signed JSON `/api/v1/sync/envelopes` requests are additionally capped at 1 MiB in `DeviceAuthFilter`, giving ~750 KiB effective ciphertext per envelope after base64url) |
| `deepsky.quotas.max-couple-storage-bytes` | `DEEPSKY_MAX_COUPLE_STORAGE_BYTES` | `1073741824` (1 GiB) | No | Total encrypted blob storage quota per couple |
| `deepsky.content.packs-dir` | `DEEPSKY_CONTENT_PACKS_DIR` | `""` (compose: `/var/lib/deepsky/packs`, volume `pack_data`) | No | Directory of signed content micro-packs served by `/api/v1/content/pack/**` |
| `deepsky.content.min-pack-version` | `DEEPSKY_MIN_PACK_VERSION` | `1.0.0` | No | Minimum pack version exposed in `GET /api/v1/system/compatibility` (anti-downgrade, `AD-06`) |
| `deepsky.content.trusted-public-keys.v1` / `.v2` | `DEEPSKY_CONTENT_TRUSTED_KEY_V1` / `DEEPSKY_CONTENT_TRUSTED_KEY_V2` | `""` (signature verification disabled) | Recommended | Ed25519 public keys (base64, 32-byte raw or 44-byte SPKI) by `keyId`. If at least one is set, the server verifies the signature of `pack-checksums.json` and rejects unknown `keyId`s. If the packs directory is configured without any key, the server logs a `WARN` at startup (only SHA-256/path verification remains active; the trust anchor is the client regardless) |
| `deepsky.firebase.enabled` | `DEEPSKY_FIREBASE_ENABLED` | `false` | No (`false`) | Enables FCM push delivery and runtime client config endpoint (`TC-13`) |
| `deepsky.firebase.project-id` | `DEEPSKY_FIREBASE_PROJECT_ID` | `""` | If `firebase.enabled=true` | Firebase project ID sent to clients at pairing |
| `deepsky.firebase.api-key` | `DEEPSKY_FIREBASE_API_KEY` | `""` | If `firebase.enabled=true` | Firebase Web/Android API key sent to clients at pairing |
| `deepsky.firebase.app-id` | `DEEPSKY_FIREBASE_APP_ID` | `""` | If `firebase.enabled=true` | Firebase Android App ID (`1:...:android:...`) |
| `deepsky.firebase.sender-id` | `DEEPSKY_FIREBASE_SENDER_ID` | `""` | If `firebase.enabled=true` | Firebase Cloud Messaging sender ID |
| `deepsky.firebase.service-account-file` | `DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE` | `""` | If `firebase.enabled=true` | Filesystem path to mounted Firebase service account JSON (never in repo) |

## Database & Spring Profiles

| Variable | Description |
| :-- | :-- |
| `SPRING_PROFILES_ACTIVE` | Defaults to `prod` (`AU-11`). Explicitly set `dev` for local development (enables Swagger UI, visibility endpoints, and Spring Docker Compose). |
| `SPRING_DATASOURCE_URL` | JDBC URL (e.g. `jdbc:postgresql://db:5432/deepsky`) |
| `SPRING_DATASOURCE_USERNAME` | PostgreSQL user |
| `SPRING_DATASOURCE_PASSWORD` | PostgreSQL password (or injected via `/run/secrets/db_password`) |
| `JAVA_TOOL_OPTIONS` | JVM heap/memory flags (e.g. `-XX:MaxRAMPercentage=70.0 -XX:+ExitOnOutOfMemoryError`) |

## Reverse Proxy, Single-Instance Limiters & Retention (`CA-12`, `AU-20`, `AU-23`)

- The Spring Boot API sets `server.forward-headers-strategy: native` so Tomcat's `RemoteIpValve` resolves `request.getRemoteAddr()` from `X-Forwarded-For` **only** when the direct TCP connection comes from a trusted private/loopback proxy (`internal-proxies`, which by default covers RFC 1918 / Docker bridge subnets), ignoring forged `X-Forwarded-For` headers from untrusted peers.
- In `deploy/docker-compose.yml`, only Caddy (`proxy`) publishes ports `80`/`443`, while `api` listens exclusively on the Docker `internal` network. Self-hosters must **not** expose `api:8080` directly to untrusted networks or disable proxy header sanitization.
- **Single-instance deployment constraint (`AU-23`):** IP and per-couple/per-device rate limiters (`PublicEndpointRateLimiter`, `PairingService`, `PushService`) are kept in JVM memory and reset on restart. Deploy the API as a **single replica** per instance.
- **Data retention (`AU-20`):** `PairingCleanupService` permanently purges unpaired couples (together with their encrypted envelopes, devices, invites, key deliveries, recovery challenges, and push registrations) **30 days** after `unpaired_at`, and removes never-paired orphan couples (including those with only revoked never-approved joiners) after 24 hours.

## Startup Validation Behavior (`SRV-03`)

- In `prod` profile, `DEEPSKY_DOMAIN` cannot be `localhost` or blank, and `DEEPSKY_ADMIN_SECRET` must be at least 24 characters and must not equal the dev placeholder.
- Whenever `DEEPSKY_FIREBASE_ENABLED=true`, all five Firebase fields (`project-id`, `api-key`, `app-id`, `sender-id`, `service-account-file`) must be non-blank, and `service-account-file` must point to a readable file. See [Firebase Setup Guide](firebase-setup.md) for step-by-step setup without `google-services.json`.
- Quotas (`max-blob-bytes`, `max-couple-storage-bytes`) and protocol versions must be strictly positive, and `max-couple-storage-bytes >= max-blob-bytes`.

## Publishing Content Packs (`S2-SRV-01`, `TC-10`)

The server serves the active pack read from the Docker `pack_data` volume (mounted at `/var/lib/deepsky/packs` in the `api` container). The directory can contain the pack files directly or a `current/` subdirectory. Expected structure:

```text
pack-checksums.json
pack-checksums.json.sig
manifest.json
assets/*.png
```

Procedure to publish a new version (e.g., `v1.1.0`):

1. Generate and sign the pack locally (`scripts/build_content_pack.py`, `scripts/sign_content.py`, `scripts/validate_content.py`); the signing private key never leaves the promoter's machine.
2. Publish the files into a new versioned directory and update the `current` symlink (never modify files in place to avoid mismatches with `ETag`/`Cache-Control: immutable`, `AU-15`). The `api` container runs as the non-root `deepsky` user (Alpine/BusyBox image), while `docker compose cp` writes as root: `exec` must therefore run with `-u root` and the new directory must be owned by `deepsky`. The server resolves the root with `toRealPath()`, so changing the symlink target is safe. `mv -T` may not be available in BusyBox: the command falls back to `ln -sfn` (near-atomic; if the reload falls within the few-microsecond window, the server keeps the last valid pack and retries on the next cycle).
   ```bash
   docker compose cp ./pack-v1.1.0 api:/var/lib/deepsky/packs/v1.1.0
   docker compose exec -u root api sh -c 'cd /var/lib/deepsky/packs && chown -R deepsky:deepsky v1.1.0 && ln -sfn v1.1.0 current.next && { mv -fT current.next current || ln -sfn v1.1.0 current; }'
   ```
   **One-time migration:** if `current` is still a real directory (not a symlink), `mv -T` cannot replace it. Before the first symlink-based publish, move the existing directory into a versioned directory and create the symlink (e.g., if the current pack is `v1.0.0`):
   ```bash
   docker compose exec -u root api sh -c 'cd /var/lib/deepsky/packs && if [ -d current ] && [ ! -L current ]; then mv current v1.0.0 && ln -sfn v1.0.0 current; fi'
   ```
   If `current` does not exist (pack files are directly in the root), create `v1.0.0/` first and move the pack files there, then create the symlink as above. After this migration, the standard publish command can be used.
3. Within 60 seconds the server reloads the pack (`@Scheduled`, interval configurable with `deepsky.content.reload-interval`, `PT60S` format), verifies it (signature if keys are configured, SHA-256, sizes, paths), and begins serving it. If verification fails, the last valid pack continues to be served and the reason appears in the log (`Rejected content pack ...`). No container restart is needed; if in doubt, `docker compose restart api` forces a reload.
4. Verify: `curl -s https://<domain>/api/v1/content/pack/checksums` and, for a file, `curl -I https://<domain>/api/v1/content/pack/blobs/<sha256>`.

Increase `DEEPSKY_MIN_PACK_VERSION` only to exclude old versions (anti-downgrade); clients download files from `/api/v1/content/pack/blobs/<sha256>` (immutable) and revalidate `/files/**` paths with `ETag`.
