# Local State and Shared Snapshot Separation Contract (`S2-CTR-02`)

**Version:** 1.0 · **Date:** November 21, 2026 · **References:** `AR-03`, `AR-07`, `TC-05`, `P-02`, `P-03`, `P-07`, `S-05`, `F-02`, `PD-19`

This document formalizes the boundary between what belongs to the couple's shared state (synchronized over E2EE) and what must remain **exclusively local to the individual device**.

---

## 1. `CoupleRoomSnapshot` (shared, E2EE encrypted, `schemaVersion = 1`)

Contains exclusively shared objective artifacts and states of the couple, deterministically derivable from the log of encrypted envelopes (`EncryptedEnvelope`):

```json
{
  "schemaVersion": 1,
  "coupleId": "<uuid>",
  "lastEventSeq": 42,
  "latestThought": {
    "envelopeId": "<uuid>",
    "seq": 42,
    "authorDeviceId": "<uuid>",
    "createdAtUtc": "2026-11-21T17:30:00Z",
    "note": "Un caffè insieme?"
  }
}
```

**Explicitly forbidden fields (`P-02`, `P-07`, `S-05`):**
- No `lastSeenEventSeq`, `readAt`, `seenByDeviceId`, or read receipt.
- No `lastOpenedAt`, `lastActiveAt`, or online presence indicator.
- No absence, inactivity, streak, or sending-frequency counters.
- No GPS coordinates, city, or weather data.

---

## 2. `LocalSceneViewState` (strictly local, never synchronized)

Persisted exclusively in the device's local secure storage (`SecureKeyStore`, excluded from Android backup `AD-06`) and **never** included in envelopes, snapshots, or HTTP calls to the server:

| Field | Type | Purpose |
| :-- | :-- | :-- |
| `lastSeenEventSeq` | `int` (default `0`) | Last event `seq` seen/reciprocated locally on the phone. Used together with the timestamp to decide whether the *Thinking of you* card shows the `"<Partner> thought of you"` + `♥ Send back` banner and whether `floor_lamp` is in the `lit` state. |
| `lastSeenThoughtEnvelopeId` | `String?` | Fallback for local events or events without an assigned `seq` (e.g., test compatibility / `n-1`). |
| `lastOpenedAtLocal` | `DateTime?` (UTC ISO-8601) | Local timestamp of the previous Home opening. If `>= 72 hours` (`3 days`) elapse since the last opening, Home shows a calm welcome-back message (*"Che bello rivederti, la casa ti aspettava"* / *"Welcome back, home was waiting for you"*), without ever showing day counts or saving inactivity counters (`P-02`, `P-03`). |
| `skyPreference` | `enum { auto, day, night }` | Local preference for the home's atmosphere/sky (`Auto` follows the local clock; `Day` and `Night` force the corresponding period and matching theme). |

### 6-hour window rule for the *Thinking of you* banner and the lamp (`F-03`, `S2-APP-03`)

A thought received from the partner (`latestThought.authorDeviceId != localDeviceId`) is considered **active and not yet seen** if and only if:
1. `nowUtc.difference(latestThought.createdAtClient) < Duration(hours: 6)` (and not anomalously in the future), **AND**
2. it has not already been marked as seen locally:
   - if `latestThought.seq != null`: `latestThought.seq! > localState.lastSeenEventSeq`;
   - otherwise: `latestThought.envelopeId != localState.lastSeenThoughtEnvelopeId`.

When this condition is true:
- The top *Thinking of you* card shows the **Received** state (`"<Partner> thought of you"`, relative time, optional note, and `♥ Send back` button).
- The `floor_lamp` slot (from micro-pack `v1.1.0`) enters the `lit` state with a warm amber glow on the background wall.

When the partner taps **`♥ Send back`** (or marks as read / sends a reply), the device updates only its own `LocalSceneViewState.lastSeenEventSeq` locally without sending any read receipt to the server (`P-07`, `S-05`).

---

## 3. Fixed Local Time Bands for Sky and Background Wall (`S-05`)

To never require GPS location or third-party weather APIs (`S-05`, `N-06`), the window sky (`window`) and background wall tint are computed from the device's local clock (`DateTime.now()`):

| Band (`SkyPeriod`) | Local time (`hour`) | `window` slot state | Sky asset |
| :-- | :-- | :-- | :-- |
| `day` (`Day`) | `06:00 – 17:59` (`6 <= h < 18`) | `day` | `assets/window_sky_day.png` |
| `twilight` (`Twilight`) | `18:00 – 20:59` (`18 <= h < 21`) | `twilight` | `assets/window_sky_twilight.png` |
| `night` (`Night`) | `21:00 – 05:59` (`h >= 21 || h < 6`) | `night` | `assets/window_sky_night.png` |

### Midnight crossing and time zone change while the app is open
- The controller runs a lightweight timer every **60 seconds** (active only while the controller is mounted and cancelled in `dispose()`) and also immediately recalculates the band on `AppLifecycleState.resumed`.
- Since `DateTime.now()` reads the OS's current local time, both crossing `06:00` / `18:00` / `21:00` / `00:00` and a phone time zone change automatically update `SkyPeriod`.
- On `SkyPeriod` change, the app performs an explicit `.evict()` from `imageCache` for the outgoing sky asset so that **only one time-of-day variant at a time** is kept in memory (`ADR-0007`).
