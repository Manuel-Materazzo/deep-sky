# Deep Sky Deployment (Docker Compose + Caddy)

Reference IDs: `INF-04`, `INF-05`, `INF-06`, `TC-03`, `SRV-02`, `SRV-03`.

## Quick Start (Local or Production VM)

1. Create `.env` from `.env.example`:
   ```bash
   cp .env.example .env
   ```
   For local testing over HTTP/localhost, set `DEEPSKY_DOMAIN=localhost` and `SPRING_PROFILES_ACTIVE=dev` (or keep `prod` with a real domain such as `deepsky.vectevo.com`).
2. Create the required Docker secret files under `deploy/secrets/` (this folder is gitignored):
   ```bash
   mkdir -p secrets
   openssl rand -base64 24 > secrets/db_password.txt
   openssl rand -base64 32 > secrets/admin_secret.txt
   chmod 600 secrets/*.txt
   ```
3. Pull the prebuilt multi-arch server image (or pin a version via `DEEPSKY_SERVER_IMAGE` in `.env`) and start the stack:
   ```bash
   docker compose pull
   docker compose up -d
   ```
   To build the server image locally from source instead:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
   ```
4. Verify health:
   ```bash
   curl -fsS http://localhost/actuator/health
   # Or over HTTPS on production domain:
   curl -fsS https://deepsky.vectevo.com/actuator/health
   ```

## Security & Privacy Defaults

- `db` is attached **only** to the `internal` Docker network (`internal: true`) and publishes no host ports (`INF-04`).
- `Caddyfile` allows `/actuator/health*` and blocks external access to all other `/actuator*` paths (`INF-02`).
- Caddy access logs strip request headers and mask client IPs (`INF-06`, `S-07`); Docker `json-file` logs are capped at `10m` x `3` files.
- `Caddyfile` serves `deploy/web/join/index.html` at `/join` (invite secrets remain strictly in `#fragment`, never sent to the backend) and `deploy/web/.well-known/assetlinks.json` at `/.well-known/assetlinks.json` (`S1-INF-01`). Replace the placeholder SHA-256 certificate fingerprint in `assetlinks.json` once the release signing keystore is generated.
- Secrets are injected via Docker secrets (`/run/secrets/`) and Spring Boot `configtree`, never hardcoded in `docker-compose.yml`.
