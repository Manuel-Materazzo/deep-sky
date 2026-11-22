# Server Operations, Firebase, and Backups

Operational summary for anyone managing a Deep Sky server instance in production (`deploy/`).

---

## Main Variables in `deploy/.env`

| Variable | Purpose | Notes |
| :--- | :--- | :--- |
| `DEEPSKY_DOMAIN` | Public domain of the instance | Required in `prod` (cannot be `localhost`) |
| `SPRING_PROFILES_ACTIVE` | Spring Boot profile | Default `prod` |
| `DEEPSKY_MIN_CLIENT_VERSION_CODE` | Minimum allowed APK version | Raise only to block old clients with critical bugs (`HTTP 426`) |
| `DEEPSKY_MIN_PACK_VERSION` | Minimum content pack version | Anti-downgrade exposed to clients |
| `DEEPSKY_CONTENT_TRUSTED_KEY_V1` / `_V2` | Ed25519 public keys for content packs | Recommended in production to verify packs on the server |
| `DEEPSKY_FIREBASE_ENABLED` | Enables FCM push notifications | `false` by default; see below to enable |

For the full list of all variables and memory/rate-limiting limits, see [server-configuration.md](../server-configuration.md).

---

## Firebase Push Notifications (FCM)

Deep Sky does not use `google-services.json` inside the app: public parameters are passed by the server at runtime, and the server uses a Service Account JSON mounted as a Docker secret.

1. Create the project in the Firebase Console, enable **Firebase Cloud Messaging API (V1)**, and note the 4 public values (`project_id`, `project_number` / sender ID, `mobilesdk_app_id`, `current_key`).
2. Download the **Service Account JSON** private key and save it to `deploy/secrets/firebase-service-account.json` (with `chmod 600` permissions).
3. Set in `deploy/.env`:
   ```env
   DEEPSKY_FIREBASE_ENABLED=true
   DEEPSKY_FIREBASE_PROJECT_ID=<project_id>
   DEEPSKY_FIREBASE_API_KEY=<current_key>
   DEEPSKY_FIREBASE_APP_ID=<mobilesdk_app_id>
   DEEPSKY_FIREBASE_SENDER_ID=<project_number>
   DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE=/run/secrets/firebase_service_account.json
   ```
4. Start with the Compose override for Firebase:
   ```bash
   cd deploy
   docker compose -f docker-compose.yml -f docker-compose.firebase.yml up -d
   ```

Complete guide and FCM troubleshooting: [firebase-setup.md](../firebase-setup.md).

---

## Backup and Restore

To keep metadata and encrypted payloads consistent, they must be backed up **within the same time window**:
1. PostgreSQL dump (`db`)
2. `blob_data` volume (E2EE encrypted attachments/blobs)
3. `pack_data` volume (content packs)

Quick example from the `deploy/` folder (see [backup-restore.md](../backup-restore.md) for the full script):

```bash
BACKUP_DIR="/var/backups/deepsky/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-deepsky}" -Fc "${POSTGRES_DB:-deepsky}" > "$BACKUP_DIR/db.dump"
docker run --rm -v deep-sky_blob_data:/data:ro -v "$BACKUP_DIR:/out" alpine tar -czf /out/blobs.tar.gz -C /data .
docker run --rm -v deep-sky_pack_data:/data:ro -v "$BACKUP_DIR:/out" alpine tar -czf /out/packs.tar.gz -C /data .
```

To verify a restore without touching the live instance, use `scripts/verify-backup-restore.sh` and the checklist in [backup-restore.md](../backup-restore.md).
