# Firebase Setup Guide (Runtime FCM Push)

**Reference IDs:** `TC-04`, `S-02`, `AD-04`, `SRV-03`, `SP-01`

Deep Sky uses **Firebase Cloud Messaging (FCM)** only for empty wakeup signals (`S-02`) and configures Firebase **strictly at runtime** (`TC-04`, `AD-04`):

- **Never place `google-services.json` inside `android/app/`** and never add the `com.google.gms.google-services` Gradle plugin. Both `google-services.json` and `firebase-service-account*.json` are listed in `.gitignore`.
- The Android client fetches the four public Firebase parameters from the server (`GET /api/v1/push/config`) and initializes `FirebaseApp` programmatically with `FirebaseOptions.Builder`.
- The server holds a Firebase **Service Account JSON** outside Git and mints short-lived OAuth2 tokens for the FCM HTTP v1 API.

---

## Step 1 · Create the Firebase Project and Extract Client Parameters

1. Open the [Firebase Console](https://console.firebase.google.com/) and click **Add project** (for example `deep-sky-proto` for M1 testing or `deep-sky-prod`). You can **disable Google Analytics** — it is not required for FCM.
2. In **Project settings** (gear icon) -> **Cloud Messaging**, verify **Firebase Cloud Messaging API (V1)** is enabled. If disabled, click the menu -> **Manage API in Google Cloud Console** and enable it.
3. Click **Project settings -> General -> Your apps -> Add app -> Android**:
   - **Android package name:** `com.vectevo.deep_sky` (must match `applicationId` in `android/app/build.gradle.kts`).
   - App nickname (optional): e.g. `Deep Sky Android`.
   - Debug signing certificate SHA-1: optional, leave blank.
4. Click **Register app**, then **Download `google-services.json`** to a **temporary folder outside this repository** (do not put it inside `android/app/`).
5. Open the downloaded `google-services.json` and copy only these four **public** values:

| JSON path in `google-services.json` | Deep Sky Env Variable | Example |
| :--- | :--- | :--- |
| `project_info.project_id` | `DEEPSKY_FIREBASE_PROJECT_ID` | `deep-sky-proto` |
| `project_info.project_number` | `DEEPSKY_FIREBASE_SENDER_ID` | `123456789012` |
| `client[0].client_info.mobilesdk_app_id` | `DEEPSKY_FIREBASE_APP_ID` | `1:123456789012:android:a1b2c3d4e5f6` |
| `client[0].api_key[0].current_key` | `DEEPSKY_FIREBASE_API_KEY` | `<your Firebase Android API key>` |

6. You can delete the downloaded `google-services.json` (or archive it in your password vault) once you have copied those four values.

---

## Step 2 · Generate the Server Service Account Key

1. In Firebase Console, open **Project settings -> Service accounts**.
2. Keep **Firebase Admin SDK** selected and click **Generate new private key -> Generate key**.
3. Save the downloaded JSON outside version control — for example under `deploy/secrets/firebase-service-account.json` (both `deploy/secrets/` and `firebase-service-account*.json` are gitignored).
4. On Linux/macOS, restrict file permissions:
   ```bash
   chmod 600 deploy/secrets/firebase-service-account.json
   ```

---

## Step 3 · Configure the Server

At startup, `DeepSkyPropertiesValidator` checks that when `DEEPSKY_FIREBASE_ENABLED=true`, all five variables are non-blank and `DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE` points to a readable file.

### Option A · Local Spring Boot Run (Development / Phone Testing Over USB or LAN)

1. Ensure PostgreSQL is running (for example from `server/`):
   ```bash
   cd server
   docker compose up -d
   ```
2. Set the environment variables and start the server:

   **Windows PowerShell:**
   ```powershell
   $env:DEEPSKY_FIREBASE_ENABLED = "true"
   $env:DEEPSKY_FIREBASE_PROJECT_ID = "<project_id>"
   $env:DEEPSKY_FIREBASE_API_KEY = "<current_key>"
   $env:DEEPSKY_FIREBASE_APP_ID = "<mobilesdk_app_id>"
   $env:DEEPSKY_FIREBASE_SENDER_ID = "<project_number>"
   $env:DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE = "C:\path\outside\repo\firebase-service-account.json"

   cd server
   ./mvnw.cmd spring-boot:run
   ```

   **Linux / macOS:**
   ```bash
   export DEEPSKY_FIREBASE_ENABLED=true
   export DEEPSKY_FIREBASE_PROJECT_ID="<project_id>"
   export DEEPSKY_FIREBASE_API_KEY="<current_key>"
   export DEEPSKY_FIREBASE_APP_ID="<mobilesdk_app_id>"
   export DEEPSKY_FIREBASE_SENDER_ID="<project_number>"
   export DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE="$HOME/deep-sky-secrets/firebase-service-account.json"

   cd server
   ./mvnw spring-boot:run
   ```

3. Verify the runtime config endpoint returns the four public fields (and **never** exposes `serviceAccountFile`):
   ```bash
   curl -fsS http://127.0.0.1:8080/api/v1/push/config
   ```
   Expected response (`"enabled": true` plus your four public IDs/key).

### Option B · Docker Compose Deployment (`deploy/`)

The container image runs as a non-root `deepsky` user (`server/Dockerfile`). Mounting the service account via `deploy/docker-compose.firebase.yml` injects it as a Docker secret at `/run/secrets/firebase_service_account.json` with clean container read permissions.

1. Place your downloaded key at `deploy/secrets/firebase-service-account.json`.
2. Edit `deploy/.env` (copied from `deploy/.env.example`):
   ```env
   DEEPSKY_FIREBASE_ENABLED=true
   DEEPSKY_FIREBASE_PROJECT_ID=<project_id>
   DEEPSKY_FIREBASE_API_KEY=<current_key>
   DEEPSKY_FIREBASE_APP_ID=<mobilesdk_app_id>
   DEEPSKY_FIREBASE_SENDER_ID=<project_number>
   DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE=/run/secrets/firebase_service_account.json
   ```
3. Start Docker Compose with the Firebase override file:
   ```bash
   cd deploy
   docker compose -f docker-compose.yml -f docker-compose.firebase.yml up -d
   ```

---

## Step 4 · Verify Push on Two Android Devices (`proto/sp-01`)

1. Install the `proto/sp-01` debug APK on two real Android devices (per [Real-Device Testing Procedure](device-testing.md)):
   ```bash
   git checkout proto/sp-01
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
   - Note: Real phones or emulators **must include Google Play Services** for FCM delivery.
2. Point both phones to your server URL:
   - **USB testing:** run `adb reverse tcp:8080 tcp:8080` and enter `http://127.0.0.1:8080` in the app.
   - **Same Wi-Fi LAN:** enter `http://<PC-LAN-IP>:8080`.
   - **Remote VM / domain:** enter `https://<your-domain>`.
3. On Phone A (`device-a`) and Phone B (`device-b`), using the same `Couple ID`:
   - Tap **1. Fetch Runtime Config from Server** -> confirms runtime options populate without `google-services.json`.
   - Tap **2. Init Runtime Firebase & Register Token** -> grants Android 13+ notification permission, initializes `FirebaseApp`, fetches the FCM token, and saves it via `PUT /api/v1/push/token`.
4. Send test wakeups across the SP-01 matrix (`SP01-04` in [m0-m1-operative-plan.md](m0-m1-operative-plan.md)):
   - App in foreground, background, **swiped away from recent apps**, after **device reboot** (without opening the app first), long screen-off / Battery Saver, and **Settings -> Force Stop** (confirming Android suppresses delivery until reopened).

---

## Troubleshooting

- **Startup error `DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE does not point to a readable file`:**
  Check that the path exists **inside the container** (`/run/secrets/firebase_service_account.json` when using `docker-compose.firebase.yml`) or matches the host path when running `./mvnw spring-boot:run`.
- **FCM `400 SENDER_ID_MISMATCH` or `UNREGISTERED`:**
  Confirm `projectId`, `senderId`, `appId`, `apiKey`, and `firebase-service-account.json` all belong to the exact same Firebase project and Android app ID (`com.vectevo.deep_sky`). If `UNREGISTERED` is returned, Deep Sky automatically deletes the stale row in `push_registrations`.
- **Token request hangs or fails on emulator:**
  Ensure the AVD uses a **Google Play** or **Google APIs** system image with network access and current Google Play Services; AOSP images without Play Services cannot obtain FCM tokens.
