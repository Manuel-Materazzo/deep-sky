#!/usr/bin/env bash
set -euo pipefail

# Non-destructive isolated backup/restore verification script for Deep Sky (INF-05, G-2).
# Requires an already running source Compose stack (`deep-sky`) or backup directory, plus Docker.
# Usage:
#   ./scripts/verify-backup-restore.sh [SOURCE_COMPOSE_DIR]

SOURCE_DIR="${1:-deploy}"
PROJECT_SRC="${DEEPSKY_COMPOSE_PROJECT:-deep-sky}"
PROJECT_TEST="deepsky-restore-test-$(date -u +%s)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" down -v >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[1/5] Taking consistent backup from project '$PROJECT_SRC' into '$TMP_DIR'..."
docker compose -p "$PROJECT_SRC" -f "$SOURCE_DIR/docker-compose.yml" exec -T db \
  pg_dump -U "${POSTGRES_USER:-deepsky}" -Fc "${POSTGRES_DB:-deepsky}" > "$TMP_DIR/db.dump"

docker run --rm -v "${PROJECT_SRC}_blob_data:/data:ro" -v "$TMP_DIR:/out" alpine \
  tar -czf /out/blobs.tar.gz -C /data .
docker run --rm -v "${PROJECT_SRC}_pack_data:/data:ro" -v "$TMP_DIR:/out" alpine \
  tar -czf /out/packs.tar.gz -C /data .

echo "[2/5] Starting isolated restore database container ('$PROJECT_TEST')..."
docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" up -d db
until docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" exec -T db \
  pg_isready -U "${POSTGRES_USER:-deepsky}" -d "${POSTGRES_DB:-deepsky}" >/dev/null 2>&1; do
  sleep 2
done

echo "[3/5] Restoring PostgreSQL dump and volume archives..."
docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" exec -T db \
  pg_restore -U "${POSTGRES_USER:-deepsky}" -d "${POSTGRES_DB:-deepsky}" --clean --if-exists < "$TMP_DIR/db.dump"

docker run --rm -v "${PROJECT_TEST}_blob_data:/data" -v "$TMP_DIR:/in:ro" alpine \
  tar -xzf /in/blobs.tar.gz -C /data
docker run --rm -v "${PROJECT_TEST}_pack_data:/data" -v "$TMP_DIR:/in:ro" alpine \
  tar -xzf /in/packs.tar.gz -C /data

echo "[4/5] Starting restored API service and checking health..."
docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" up -d api
for _ in $(seq 1 30); do
  if docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" exec -T api \
    wget -qO- http://127.0.0.1:8080/actuator/health/liveness | grep -q '"status":"UP"'; then
    echo "[5/5] Restored API is UP. Comparing couple/device/envelope row counts..."
    for tbl in couples devices encrypted_envelopes; do
      src_cnt=$(docker compose -p "$PROJECT_SRC" -f "$SOURCE_DIR/docker-compose.yml" exec -T db \
        psql -U "${POSTGRES_USER:-deepsky}" -d "${POSTGRES_DB:-deepsky}" -tAc "SELECT COUNT(*) FROM $tbl;")
      dst_cnt=$(docker compose -p "$PROJECT_TEST" -f "$SOURCE_DIR/docker-compose.yml" exec -T db \
        psql -U "${POSTGRES_USER:-deepsky}" -d "${POSTGRES_DB:-deepsky}" -tAc "SELECT COUNT(*) FROM $tbl;")
      echo "  - $tbl: source=$src_cnt restored=$dst_cnt"
      test "$src_cnt" = "$dst_cnt"
    done
    echo "Backup/restore verification PASSED."
    exit 0
  fi
  sleep 2
done

echo "Restored API failed liveness check within timeout." >&2
exit 1
