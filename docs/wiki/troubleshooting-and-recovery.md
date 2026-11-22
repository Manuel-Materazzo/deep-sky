# Emergencies, Troubleshooting, and Recovery

Summary of the most common situations during daily use of the app and server. For complete details, see [emergency-procedure.md](../emergency-procedure.md).

---

## 1. Server Not Responding / No Network
* **What NOT to do:** do not uninstall the app and do not tap "Unlink device".
* **What happens:** the app enters read-only offline mode, showing the content already decrypted on the phone.
* **Server-side:** check the container status and restart them if necessary:
  ```bash
  cd deploy
  docker compose ps
  docker compose up -d
  docker compose logs --tail=100 api proxy
  ```
* As soon as the server comes back online, refresh from the Home screen: the local queue and synchronization resume normally.

---

## 2. Loss or Replacement of ONE Phone
The other partner still has the working app:
1. On the remaining active phone, open **Devices** and tap **Revoke** on the lost device.
   - Revocation immediately blocks the old phone on the server (`HTTP 401`) and **automatically rotates the epoch keys and the Recovery Key**.
2. Immediately save the **new 24 words** shown by the app (the old ones are no longer valid for new data).
3. Start a new device enrollment (QR / link) and pair the new phone by confirming the 6-digit SAS code.

---

## 3. Loss or Reset of BOTH Phones
1. Install the official APK on the new phone and open the **Recover** tab.
2. If you use a custom self-hosted server, enter the server URL before confirming.
3. Enter the **24 BIP-39 words** in the exact order (or scan the offline backup QR code).
4. Tap **Restore and relight the home**, then open **Devices** to revoke any old phones.

> [!CAUTION]
> If **both phones** are lost **and** the 24 words were not saved, the encrypted data on the server cannot be recovered by anyone. The only option is to create a new couple from scratch.

---

## 4. Rollback or Blocking of a Faulty App Version
Android **does not allow** installing an APK with a `versionCode` less than or equal to the one already on the phone:
- Publish a new release with a strictly higher `versionCode` containing the fix (or reverting to the working commit).
- If an old client version has a critical blocking bug against the server, after publishing the fixed APK, raise `DEEPSKY_MIN_CLIENT_VERSION_CODE` in `deploy/.env` and restart `api`: old clients will receive `HTTP 426` with a prompt to update.
