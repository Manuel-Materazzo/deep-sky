# Content Packs Management & Publishing

The 2D Home scene runs via **signed, data-driven graphic micro-packs**.

## How It Works in Brief

1. **Base pack in the APK (`bundled`):** the app ships with the `v1.0.0` pack (continuous floor + window with day/twilight/night sky). If the server has no packs or is unreachable, the app still works using the embedded pack.
2. **Incremental packs from the server:** updates (e.g., `v1.1.0` with rug, couch, and floor lamp; `v1.2.0` with couple and pet) are served by the server **file by file**, without `.zip` archives. The client downloads only new or modified files whose SHA-256 hash is not already in the local cache.
3. **Replacing or adding elements:** a new pack can both **replace existing graphics** and **add new slots** to the scene (described in the pack's `manifest.json`), without requiring an APK update, as long as they do not require new client-side application logic.
4. **Security and automatic rollback:**
   - The client verifies the **Ed25519** signature (`pack-checksums.json.sig`) before reading any data.
   - If a newly activated pack causes crashes or fails to launch the Home screen 2 consecutive times, the app automatically falls back to the previous working pack (or the bundled APK pack).

---

## Where Packs Live on the Server

Packs **are not inside the `api` Docker image**. They are read from the `pack_data` Docker volume, mounted at `/var/lib/deepsky/packs` in the `api` container.

Expected structure of the active directory (directly at the root or pointed to by the `current` symlink):

```text
pack-checksums.json
pack-checksums.json.sig
manifest.json
assets/*.png
```

---

## Hot-Publishing a New Pack on the Server

You do not need to rebuild the Docker image or restart the `api` container.

### 1. Prepare and sign the pack locally
On the machine where you store the content signing private key (the private key must never be placed on the server):

```bash
# Generate optimized derivatives from masters (if starting from source files)
python scripts/build_content_pack.py --masters content/masters/v1 --out-assets content/packs/v1/assets

# Validate manifest, dimensions, and paths
python scripts/validate_content.py

# Sign pack-checksums.json -> pack-checksums.json.sig
python scripts/sign_content.py ...
```

### 2. Copy the pack to the Docker volume and update `current`
Copy the pack folder (e.g., `./pack-v1.1.0`) into a **new versioned directory** inside the container, assign ownership to the `deepsky` user, and update the `current` symlink (never overwrite files in place):

```bash
cd deploy

docker compose cp ./pack-v1.1.0 api:/var/lib/deepsky/packs/v1.1.0
docker compose exec -u root api sh -c 'cd /var/lib/deepsky/packs && chown -R deepsky:deepsky v1.1.0 && ln -sfn v1.1.0 current.next && { mv -fT current.next current || ln -sfn v1.1.0 current; }'
```

> [!NOTE]
> **First time only (one-time migration):** if `current` is still a real directory instead of a symlink, move it to `v1.0.0` first and create the symlink:
> ```bash
> docker compose exec -u root api sh -c 'cd /var/lib/deepsky/packs && if [ -d current ] && [ ! -L current ]; then mv current v1.0.0 && ln -sfn v1.0.0 current; fi'
> ```

### 3. Verify the publication
Within **60 seconds**, the server automatically reloads the pack (checking the signature if `DEEPSKY_CONTENT_TRUSTED_KEY_V1`/`_V2` are set, SHA-256 hashes, and paths). If anything is invalid, `Rejected content pack ...` appears in the logs and the previous pack remains active.

Verify from the terminal:
```bash
curl -fsS https://your-domain.example.com/api/v1/content/pack/checksums
```

### 4. Updating on phones
- **Automatic:** on the next launch over an unmetered Wi-Fi network.
- **Immediate:** in the app, open **Settings -> Update graphics** (works over mobile data as well and reloads the scene immediately).

For the full endpoint and HTTP caching contract, see [content-pack-contract.md](../content-pack-contract.md) and [server-configuration.md](../server-configuration.md#pubblicazione-dei-pacchetti-di-contenuti-s2-srv-01-tc-10).
