# Getting Started — Deep Sky

Quick guide to getting a server instance running with Docker Compose and connecting the couple's two Android phones.

---

## Part 1 · Starting the Server (Self-Hosting)

### Prerequisites
- A Linux host (e.g., OCI VM / VPS) with **Docker** and **Docker Compose** installed.
- A public domain pointed to the server's IP (ports **80** and **443** open: Caddy automatically manages HTTPS certificates).

### 1. Prepare configuration and secrets
Navigate to the `deploy/` folder in the repository:

```bash
cd deploy
cp .env.example .env
mkdir -p secrets
```

Create the two required secret files (never commit them to Git):

1. `deploy/secrets/db_password.txt`: strong password for PostgreSQL.
2. `deploy/secrets/admin_secret.txt`: administrative secret of at least **24 characters** (different from development placeholders).

Edit `deploy/.env` setting at least:

```env
DEEPSKY_DOMAIN=your-domain.example.com
SPRING_PROFILES_ACTIVE=prod
```

> [!NOTE]
> If you want to enable push notifications (FCM), follow the dedicated section in [Server Operations, Firebase & Backups](server-operations.md#firebase-push-notifications-fcm) before or after the first startup.

### 2. Start the containers
```bash
docker compose up -d
```

Three services will be started:
- `proxy` (`caddy:2.9-alpine`, the only service exposed on `80`/`443`)
- `api` (Spring Boot backend, isolated in the internal Docker network)
- `db` (`postgres:17-alpine`)

### 3. Verify that the server responds
```bash
docker compose ps
curl -fsS https://your-domain.example.com/actuator/health/liveness
```

Expected output: `{"status":"UP"}` (or `healthy` status in `docker compose ps`).

---

## Part 2 · Installing and Configuring the Android App

### 1. Install the APK
Download the official APK from the repository's **Releases** page (or from your server's `/join` URL) and install it on both Android phones.

### 2. Connect your server (if self-hosted)
If you are using a personal server instance instead of the default server, open the server configuration panel on the initial screens (onboarding / recovery) and enter the URL `https://tuo-dominio.esempio.com`.

### 3. Couple Pairing
1. **Phone A:** tap **Create a new home**, generate the QR code / invite link, and show it to your partner.
2. **Phone B:** tap **Join**, scan the QR code (or paste the link).
3. **Security verification (SAS):** both phones display a 6-digit code. Compare it verbally or in person before confirming entry.

### 4. Save the Recovery Key (critical)
Immediately after pairing, the app displays **24 BIP-39 words** (and an offline backup QR code):
- Write them down in a safe place (e.g., password manager or paper stored offline).
- **Warning:** Deep Sky is end-to-end encrypted (`E2EE`). If you lose both phones and do not have the 24 words, **no one** (not even the server operator) can recover the home's data.

---

## Part 3 · Updating Home Graphics
The app already includes the base graphics pack (`v1.0.0`). When you publish new packs on the server (e.g., `v1.1.0`, `v1.2.0`):
- Over an unmetered Wi-Fi network, the app downloads the new files in the background and activates them on the next restart.
- To force an immediate update even on mobile data, open **Settings** in the app and tap **Update graphics** ([Content Packs Management](content-packs-operations.md)).
