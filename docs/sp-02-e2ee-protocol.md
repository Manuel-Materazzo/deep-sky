# SP-02 Prototype Protocol Specification: E2EE, Pairing, Recovery, and Device Enrollment

**Status:** M1 Prototype (`proto/sp-02`)  
**Reference IDs:** `SP-02`, `SP02-01`, `S-01`, `S-03`, `S-06`, `F-01`, `F-20`, `AD-01`, `AD-02`, `TC-05`, `TC-06`

> **Purpose:** Validate end-to-end encryption, MITM-resistant pairing, zero-second-phone recovery, cross-device enrollment, device revocation, and minimal server visibility before locking Architecture v0.2 (`G-1`).

---

## 1. Cryptographic Primitives

All primitives come from mature, standard implementations without custom cryptography (`TC-05`, `6.3`):

- **Client (`package:cryptography`, Apache-2.0):**
  - Key Exchange: **X25519**
  - Signatures / Device Auth: **Ed25519**
  - Key Derivation: **HKDF-SHA256** (RFC 5869)
  - Authenticated Encryption (AEAD): **XChaCha20-Poly1305** (192-bit CSPRNG nonce, 128-bit Poly1305 tag)
  - Hashing: **SHA-256**
- **Server (JDK 25 `java.security`):**
  - **Ed25519** signature verification (`Signature.getInstance("Ed25519")`)
  - **SHA-256** request body hashing
  - **SecureRandom** challenge/invite token generation
  - The server performs **no** symmetric encryption/decryption of couple content.

---

## 2. Key Hierarchy

### 2.1 Couple Recovery Seed & Derived Keys

1. At couple creation, Device A generates a 32-byte (256-bit) `recoverySeed` from a CSPRNG.
2. `recoverySeed` is encoded for human backup as:
   - **24-word mnemonic** (256-bit entropy + 8-bit SHA-256 checksum mapped to the standard 2048-word BIP-39 English wordlist), and
   - **Recovery QR payload**: `deepsky-rk:v1:<base64url(recoverySeed + first4Bytes(SHA256(recoverySeed)))>`.
3. From `recoverySeed`, domain-separated **HKDF-SHA256** derives:
   - **Couple Root Key (`K_root`, 32 bytes):**
     `HKDF-SHA256(ikm: recoverySeed, salt: "deep-sky:salt:v1", info: "deep-sky:couple-root:v1")`
   - **Recovery Authentication Seed (`recoveryAuthSeed`, 32 bytes):**
     `HKDF-SHA256(ikm: recoverySeed, salt: "deep-sky:salt:v1", info: "deep-sky:recovery-auth:v1")`
     -> Deterministically seeds the Ed25519 `recoveryAuthKeyPair`. Only `recoveryAuthPublicKey` is stored by the server; `recoveryAuthSeed` and `K_root` never leave devices in plaintext.
4. From `K_root` and `keyEpoch >= 1`, per-channel symmetric keys are derived:
   - **Events Key:** `HKDF-SHA256(ikm: K_root, salt: "", info: "deep-sky:events:v1|epoch=<n>")`
   - **Snapshots Key:** `HKDF-SHA256(ikm: K_root, salt: "", info: "deep-sky:snapshots:v1|epoch=<n>")`
   - **Blobs Key:** `HKDF-SHA256(ikm: K_root, salt: "", info: "deep-sky:blobs:v1|epoch=<n>")`

### 2.2 Per-Device Keys

Each physical device generates locally and keeps in platform keystore-backed storage (`flutter_secure_storage` / Android Keystore):

- **`deviceAuthKeyPair` (Ed25519):** Authenticates every HTTP request from this device.
- **`deviceKemKeyPair` (X25519):** Receives wrapped `recoverySeed` during pairing or new-device enrollment.

---

## 3. Encrypted Envelope Format & Anti-Tampering AAD

### 3.1 Plaintext Payload (Inside Ciphertext Only)

```json
{
  "schemaVersion": 1,
  "eventType": "thinking_of_you | mood | countdown | time_capsule | drawing_turn | snapshot",
  "createdAtClient": "2026-11-14T21:00:00.000Z",
  "authorDeviceId": "<uuid>",
  "body": {
    "text": "...",
    "unlockAt": "2027-02-14T00:00:00.000Z"
  }
}
```

### 3.2 Canonical AEAD Associated Data (AAD)

Before encrypting with XChaCha20-Poly1305 (`K_events` or `K_snapshots`), the client constructs UTF-8 AAD:

```text
deep-sky:envelope:v1|coupleId=<coupleId>|envelopeId=<envelopeId>|senderDeviceId=<senderDeviceId>|channel=<EVENT|SNAPSHOT>|keyEpoch=<keyEpoch>
```

**Security guarantees verified in SP-02:**
- Any bit flip in `nonce`, `ciphertext`, or `tag` fails Poly1305 verification.
- Moving an envelope between couples or altering `coupleId`/`envelopeId`/`senderDeviceId`/`channel`/`keyEpoch` fails AAD verification on the receiving client.
- The server stores only `envelopeId`, `coupleId`, `senderDeviceId`, `seq`, `channel`, `keyEpoch`, `nonce` (24 B), `ciphertext` (ciphertext + 16 B tag), and `createdAt`. Event types, texts, moods, and time-capsule unlock dates are completely opaque to the server.

---

## 4. Device Request Authentication (`AD-02`)

Every authenticated endpoint requires four headers:

- `X-Device-Id`: Device UUID
- `X-Timestamp`: Unix epoch seconds (UTC); server rejects skew > ±300 s
- `X-Nonce`: Unique per-request random nonce (min 16 chars); server rejects replays within the ±300 s window
- `X-Signature`: Base64url-encoded Ed25519 signature over:

```text
<HTTP_METHOD>\n<REQUEST_URI_WITH_QUERY>\n<X-Timestamp>\n<X-Nonce>\n<LOWERCASE_HEX_SHA256(BODY)>
```

If the device is unknown or `revoked_at IS NOT NULL`, the server rejects with `401 Unauthorized`.

---

## 5. Flows

### 5.1 Initial Pairing (`F-01`, `SP02-04`)

1. **Partner A (Initiator):** Generates `recoverySeed`, `deviceAuthKeyPair_A`, `deviceKemKeyPair_A`, and `recoveryAuthKeyPair`. Calls `POST /api/v1/pairing/invites` -> receives `coupleId`, `deviceId_A`, `inviteToken`, and `expiresAt`. Displays QR/link `deepsky://pair?token=<inviteToken>`.
2. **Partner B (Joiner):** Generates `deviceAuthKeyPair_B`, `deviceKemKeyPair_B`. Calls `POST /api/v1/pairing/invites/{token}/accept` -> receives `coupleId`, `deviceId_B`, `peerDeviceId` (`deviceId_A`), `peerAuthPublicKey`, `peerKemPublicKey`.
3. **SAS Verification Code (MITM Check):**
   - Both compute `sharedSecret = X25519(myKemPriv, peerKemPub)`.
   - Both order `(kemPubA, kemPubB)` lexicographically and compute:
     `sasHash = HKDF-SHA256(ikm: sharedSecret, salt: coupleIdUtf8, info: "deep-sky:pairing-sas:v1|" + b64(kemPub1) + "|" + b64(kemPub2), len: 4)`
   - 6-digit code: `(uint32_be(sasHash) % 1000000)` formatted `XXX-XXX`.
4. **Root Key Delivery (only after Partner A confirms SAS match):**
   - Device A derives `K_wrap = HKDF-SHA256(ikm: sharedSecret, salt: coupleIdUtf8, info: "deep-sky:pairing-wrap:v1", len: 32)`.
   - Device A encrypts `recoverySeed` with XChaCha20-Poly1305 using `K_wrap` and AAD `deep-sky:key-delivery:v1|coupleId=<coupleId>|from=<deviceId_A>|to=<deviceId_B>`.
   - Device A uploads wrapped payload via `POST /api/v1/pairing/key-deliveries` (signed by `deviceAuthKeyPair_A`).
   - Device B fetches `GET /api/v1/pairing/key-deliveries/me` (signed by `deviceAuthKeyPair_B`), unwraps `recoverySeed`, derives `K_root`, and marks its recovery backup confirmation.

### 5.2 New Device Enrollment from Other Phone (`F-20`)

1. Active Device A calls `POST /api/v1/pairing/enrollment-invites` (signed by `deviceAuthKeyPair_A`) -> receives short-lived `inviteToken`.
2. New Device B2 accepts via `POST /api/v1/pairing/invites/{token}/accept`.
3. Same X25519 + 6-digit SAS verification + `key-deliveries` flow delivers `recoverySeed` from Device A to Device B2.

### 5.3 Recovery with Recovery Key Alone (`S-06`, `SP02-05`)

1. New Device R accepts the 24-word mnemonic (verifying checksum) or scans the recovery QR.
2. Device R reconstructs `recoverySeed`, `K_root`, and `recoveryAuthKeyPair`.
3. Device R requests a single-use challenge: `POST /api/v1/recovery/challenges` with `recoveryAuthPublicKey` -> receives `challengeId`, `coupleId`, `nonce`.
4. Device R generates fresh `deviceAuthKeyPair_R` and `deviceKemKeyPair_R`, and signs with `recoveryAuthKeyPair`:
   `deep-sky:recovery:v1|<coupleId>|<challengeId>|<nonce>|<b64url(deviceAuthPub_R)>|<b64url(deviceKemPub_R)>`
5. Device R calls `POST /api/v1/recovery/complete` -> server verifies the signature against `couples.recovery_auth_public_key`, consumes the challenge, activates `deviceR`, and returns `deviceId_R` + `coupleId`.
6. Device R downloads all historical `encrypted_envelopes` and decrypts them with `K_root`.

### 5.4 Device Revocation (`SP02-06`) & Unilateral Unpairing (`S-03`)

- `POST /api/v1/pairing/devices/{deviceId}/revoke` (authenticated by any active couple device): sets `revoked_at` on target device; subsequent requests from that device fail with `401`.
- `POST /api/v1/pairing/unpair` (authenticated by any active couple device): sets `unpaired_at` and revokes all devices in the couple.
- **Note for ADR / G-5:** Revoking a lost device prevents server access immediately, while `K_root` epoch rotation for forward secrecy after revocation is evaluated in the SP-02 ADR.
