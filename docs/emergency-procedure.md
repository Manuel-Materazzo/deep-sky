# Emergency and Recovery Procedure — Deep Sky (`S1-DOC-01`, `G-3a`)

Concise operational document in plain language for handling real incidents during field use.

---

## 1. Server Not Responding / No Network
1. **Do not uninstall and do not tap "Unlink device".** The app automatically enters offline read-only mode, showing memories already decrypted on the phone.
2. Check server-side (`deploy/`):
   ```bash
   docker compose ps
   curl -fsS https://deepsky.vectevo.com/actuator/health/liveness
   ```
3. If the `api` or `db` container is stopped:
   ```bash
   cd deploy
   docker compose up -d
   docker compose logs --tail=100 api proxy
   ```
4. As soon as the server becomes reachable again, tap the refresh button on the Home screen: the local queue and synchronization resume without losing the couple.

---

## 2. Faulty Update Released on the *Stable* or *Preview* Channel
**Android Rule (`m3-operative-plan.md` ch. 3):** Android **does not allow** downgrading to a `versionCode` less than or equal to the installed one.

1. If only the phone on the **preview** channel has a bug:
   - Switch the phone back to the **stable** channel in Settings if needed for future releases.
   - Publish a new release on GitHub (with a **strictly higher `versionCode`**, e.g., `+1` above the faulty build) containing the fix or the code from the previous working commit, signed with the same Android keystore key and Ed25519 manifest (`scripts/sign-release.*`).
2. If an old client version has a critical blocking bug against the server:
   - After publishing the fixed APK with a higher `versionCode`, raise `DEEPSKY_MIN_CLIENT_VERSION_CODE` in the server's `.env` and restart `api`: old clients will receive `HTTP 426` and display the gentle "Update required" screen with direct download.

---

## 3. Loss or Replacement of ONE Phone (the other partner still has the app)
1. On the remaining active phone, open **Devices**:
   - Tap **Revoke** next to the lost/old phone and confirm. The revoked device is immediately blocked on the server (`HTTP 401`, push token removed), and revocation **automatically rotates the epoch keys and the Recovery Key** (`CA-02`, `ADR-0012`) so the revoked phone cannot read or recover anything in the future.
   - Immediately save and confirm the **new 24 words** shown by the app (`RecoveryKeySetupPage`); the previous 24 words are no longer valid for recovery.
   - Start a new **device enrollment** to generate a temporary QR code / link.
2. On the new phone:
   - Install the official APK -> choose **Join** -> scan the QR code or paste the link.
   - Compare the 6-digit SAS code verbally and complete joining.

---

## 4. Both Phones Lost or Reset (Autonomous Recovery with Recovery Key `F-20`)
1. Install the official APK from `https://deepsky.vectevo.com/join` (or GitHub Releases).
2. Open the app -> **Recover** tab (`S1-D10`).
3. Enter the **24 BIP-39 words** in the exact order (or scan the offline backup QR code).
   - If you use a custom self-hosted server, open the server panel at the bottom and enter the URL before confirming.
4. Tap **Restore and relight the home**: the recovery private key recreates the new device's session without needing the old phone and decrypts the entire shared history from the server.
5. Once back in, open **Devices** and revoke any old phones no longer in your possession.

---

## 5. Total Loss of the Recovery Key
If **both phones** are lost **and** the 24 words were not saved, no one — not even the server administrator — can decrypt the room (`S-01`). The only path is to create a new couple from scratch and ask the other partner to do the same.
