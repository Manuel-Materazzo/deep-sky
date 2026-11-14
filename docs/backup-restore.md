# Backup and Restore Procedure (OCI VM)

**Reference IDs:** `INF-05`, `TC-11`, `S-01`

## What Must Be Backed Up Together

To keep database metadata and encrypted binary payloads consistent (`INF-05`), a single backup window must capture:

1. **PostgreSQL dump** (`pg_dump -Fc` from the `db` service in `deploy/docker-compose.yml`)
2. **Encrypted blob volume** (`blob_data`)
3. **Content packs volume** (`pack_data`)

Because of end-to-end encryption (`S-01`), backups contain only encrypted couple payloads and operational metadata; couple content cannot be decrypted without the partner keys (`TC-06`).

## Example Backup Script (to integrate into existing OCI VM scripts)

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/deepsky/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

cd /opt/deep-sky/deploy
docker compose exec -T db pg_dump -U "${POSTGRES_USER:-deepsky}" -Fc "${POSTGRES_DB:-deepsky}" > "$BACKUP_DIR/db.dump"
docker run --rm -v deep-sky_blob_data:/data:ro -v "$BACKUP_DIR:/out" alpine tar -czf /out/blobs.tar.gz -C /data .
docker run --rm -v deep-sky_pack_data:/data:ro -v "$BACKUP_DIR:/out" alpine tar -czf /out/packs.tar.gz -C /data .

# Encrypt the bundle with age or gpg before off-host upload and enforce retention
```

## Restore Verification Checklist (`INF-05`)

- [ ] Provision a clean test host or isolated Docker Compose project name (`-p deepsky-restore-test`)
- [ ] Decrypt the backup archive
- [ ] Start `db` first and restore `db.dump` with `pg_restore`
- [ ] Restore `blob_data` and `pack_data` volumes
- [ ] Start `api` and verify `/actuator/health` returns `UP` and row counts match pre-backup state

On the OCI VM (with Docker running the `deep-sky` Compose project), the isolated restore verification above can be run non-destructively via [scripts/verify-backup-restore.sh](../scripts/verify-backup-restore.sh).
