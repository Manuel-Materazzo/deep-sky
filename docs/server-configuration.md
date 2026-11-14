# Server Configuration Reference

**Reference IDs:** `SRV-03`, `INF-04`, `TC-02`, `TC-10`, `TC-13`

All configuration is supplied via environment variables (or Docker secrets mapped into environment/property files). The server validates required production settings at startup and fails fast with explicit diagnostic messages.

## Parameters

| Property (`deepsky.*`) | Environment Variable | Default (`dev` / base) | Required in `prod` | Description |
| :-- | :-- | :-- | :-- | :-- |
| `deepsky.domain` | `DEEPSKY_DOMAIN` | `localhost` | Yes | Public domain of the instance (e.g. `deepsky.vectevo.com`) |
| `deepsky.admin-secret` | `DEEPSKY_ADMIN_SECRET` | `dev-admin-secret-change-me` (dev only) | Yes (>= 24 chars, non-default) | Admin secret for self-hoster operational endpoints |
| `deepsky.protocol.min-client-version-code` | `DEEPSKY_MIN_CLIENT_VERSION_CODE` | `1` | No (`1`) | Minimum Android `versionCode` allowed by the server (`F-19`, `N-10`) |
| `deepsky.protocol.min-protocol-version` | `DEEPSKY_MIN_PROTOCOL_VERSION` | `1` | No (`1`) | Minimum E2EE/snapshot protocol version (`TC-05`, `8.2`) |
| `deepsky.quotas.max-blob-bytes` | `DEEPSKY_MAX_BLOB_BYTES` | `10485760` (10 MiB) | No | Maximum single encrypted blob upload size |
| `deepsky.quotas.max-couple-storage-bytes` | `DEEPSKY_MAX_COUPLE_STORAGE_BYTES` | `1073741824` (1 GiB) | No | Total encrypted blob storage quota per couple |
| `deepsky.firebase.enabled` | `DEEPSKY_FIREBASE_ENABLED` | `false` | No (`false`) | Enables FCM push delivery and runtime client config endpoint (`TC-13`) |
| `deepsky.firebase.project-id` | `DEEPSKY_FIREBASE_PROJECT_ID` | `""` | If `firebase.enabled=true` | Firebase project ID sent to clients at pairing |
| `deepsky.firebase.api-key` | `DEEPSKY_FIREBASE_API_KEY` | `""` | If `firebase.enabled=true` | Firebase Web/Android API key sent to clients at pairing |
| `deepsky.firebase.app-id` | `DEEPSKY_FIREBASE_APP_ID` | `""` | If `firebase.enabled=true` | Firebase Android App ID (`1:...:android:...`) |
| `deepsky.firebase.sender-id` | `DEEPSKY_FIREBASE_SENDER_ID` | `""` | If `firebase.enabled=true` | Firebase Cloud Messaging sender ID |
| `deepsky.firebase.service-account-file` | `DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE` | `""` | If `firebase.enabled=true` | Filesystem path to mounted Firebase service account JSON (never in repo) |

## Database & Spring Profiles

| Variable | Description |
| :-- | :-- |
| `SPRING_PROFILES_ACTIVE` | `dev` (local development) or `prod` (containerized deployment) |
| `SPRING_DATASOURCE_URL` | JDBC URL (e.g. `jdbc:postgresql://db:5432/deepsky`) |
| `SPRING_DATASOURCE_USERNAME` | PostgreSQL user |
| `SPRING_DATASOURCE_PASSWORD` | PostgreSQL password (or injected via `/run/secrets/db_password`) |
| `JAVA_TOOL_OPTIONS` | JVM heap/memory flags (e.g. `-XX:MaxRAMPercentage=70.0 -XX:+ExitOnOutOfMemoryError`) |

## Startup Validation Behavior (`SRV-03`)

- In `prod` profile, `DEEPSKY_DOMAIN` cannot be `localhost` or blank, and `DEEPSKY_ADMIN_SECRET` must be at least 24 characters and must not equal the dev placeholder.
- Whenever `DEEPSKY_FIREBASE_ENABLED=true`, all five Firebase fields (`project-id`, `api-key`, `app-id`, `sender-id`, `service-account-file`) must be non-blank, and `service-account-file` must point to a readable file. See [Firebase Setup Guide](firebase-setup.md) for step-by-step setup without `google-services.json`.
- Quotas (`max-blob-bytes`, `max-couple-storage-bytes`) and protocol versions must be strictly positive, and `max-couple-storage-bytes >= max-blob-bytes`.
