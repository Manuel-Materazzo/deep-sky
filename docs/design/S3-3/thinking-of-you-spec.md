# Advance Design Specification — S3-3: Thinking of You and Notifications (`S2-D10`, `S2-DES-03`)

**Version:** 0.1 (draft for sponsor approval before closing `S3-2`) · **Date:** November 21, 2026
**References:** `F-03`, `F-16`, `P-01`, `P-02`, `P-03`, `P-07`, `S-02`, `V-06`, `V-07`, `V-08`, `V-10..V-12`, `CA-15`

---

## 1. Emotional Goal

Sending a *"Thinking of you"* must take **less than 3 seconds** (`P-01`) and arrive like a gentle light left on in the room, never as an urgent notification or a message demanding a reply (`P-02`, `P-03`, `V-08`).

---

## 2. Flows and States (`F-03`)

### 2.1 Quick send from Home or from the floor lamp
- **Trigger:** **`♥ Thinking of you`** button in the top card or direct tap on the `floor_lamp` slot in the scene (`DD-04`).
- **Optional lightweight sheet (*bottom sheet*):**
  - **Single tap on `♥ Thinking of you`:** immediately sends the thought (with an optional short note entered in the quick field, max 140 characters).
  - **Tap on the lamp (`floor_lamp`):** opens a soft bottom sheet with:
    - title: *"Lascia una piccola luce accesa"* / *"Leave a gentle light on"*;
    - 3 optional one-tap prompts (*"Thinking of you right now"*, *"Hope your day is going well"*, *"Wish I could hug you"* — never mandatory);
    - optional free-text field (max 140 characters);
    - primary button **`♥ Send thought`** (`minHeight: 48dp`).
- **Offline state (`N-03`):** button disabled with calm copy (*"You're offline · Try again as soon as connection returns"*).
- **Sending / confirmation state:** the top card temporarily transitions to a *"Pensiero inviato"* / *"Thought sent"* confirmation banner (replacing the *"Leave a thought"* composer for ~8 seconds, with a preview of the sent note and a discreet button to dismiss immediately), accompanied by a brief expansion animation of the lamp's amber glow (`400 ms`, disabled if *Reduce motion* is active) + light **"heartbeat" haptic** (`HapticFeedback.lightImpact()` + `120 ms` pause + `HapticFeedback.selectionClick()`, respecting system haptic preferences).

### 2.2 Receiving and `< 6h` state
- When a *Thinking of you* arrives from the partner (and has not yet been seen locally: `seq > lastSeenEventSeq` and `< 6h`):
  - The floor lamp transitions to the **`lit`** state (`floor_lamp_lit.png` + amber/pink `RadialGradient` on the background wall).
  - The top card displays **`"<Partner> thought of you"`** (with the partner's optional note), an optional field to reply with a short message, and the **`♥ Send back`** button. Sending the reply marks the received thought as seen locally, and the card briefly displays the *"Thought sent"* banner.
- **No-obligation rule (`P-02`, `P-07`):** no read receipt is sent to the server when the recipient opens Home or ignores the card. After 6 hours, the lamp silently returns to the `calm` state (soft light, never turned off).

---

## 3. Discreet Notifications and Quiet Settings (`F-16`, `S-02`, `CA-15`)

### 3.1 Payload and generic default texts (lock-screen safe `S-02`)
The server sends only a data-only wakeup (`{ "l10nKey": "wakeup.thinking_of_you", "event": "thinking_of_you", "ts": ... }`, never names or plaintext notes). The app composes the notification locally on the device:

| `l10nKey` | Title IT | Body IT | Title EN | Body EN |
| :-- | :-- | :-- | :-- | :-- |
| `wakeup.thinking_of_you` | `Deep Sky` | `C'è una luce accesa nella vostra casa.` | `Deep Sky` | `A gentle light is on in your home.` |
| `wakeup.pairing_request` | `Deep Sky` | `Una richiesta di collegamento attende la tua conferma.` | `Deep Sky` | `A pairing request is waiting for your confirmation.` |

### 3.2 Android Channel & Quiet Hours
- **Android channel:** `deep_sky_gentle_gestures` (*"Gesti gentili"* / *"Gentle gestures"*), importance `IMPORTANCE_DEFAULT`, numeric badge disabled (`setShowBadge(false)` per `V-08`), short soft vibration (`[0, 70, 90, 50]`), silent/gentle default system sound customizable by the user in Android settings.
- **Quiet hours (device-local, optional in `Settings`):**
  - *"Ore di quiete"* / *"Quiet hours"* toggle (disabled by default, suggested schedule `22:30 – 07:30`).
  - During quiet hours, push wakeups produce neither sound nor vibration, while the E2EE event remains normally visible when opening Home (`P-08`).
- **Notification tap:** opens directly to the `Home` tab with the *"\<Partner\> thought of you"* card and the lit lamp.
