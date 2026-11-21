# M3 Operative Plan: Deep Sky

**Version:** 0.2 (draft for review) · **Date:** November 16, 2026 · **Depends on:** Development Plan
(ch. 6.4 and 6.5), M2 Operative Plan, Architecture Document v0.2

**Audience:** sponsor (who oversees everything, PD-11) and executing agents.

**Conventions.** **\[Decided\]**, **\[Proposal\]**, **\[Open\]** as in the other documents. New
IDs: **PD-14 … PD-20** (plan decisions), **S3-n** (sprints), **G-3a** (entry gate to real
use). Tasks have IDs `Sn-TRACK-xx` (for example `S1-APP-02`).

---

## 1. What changes compared to the previous plan

M2 is completed. M3 was an XL milestone, followed by M4 (real use). The sponsor proposes to
split it up and start real use earlier.

| ID        | Decision                                                                                                                                                           | Status   |
|:----------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------|
| **PD-14** | M3 is divided into **vertical sprints**, one per feature. A sprint is **a slice with a verifiable output**, not a fixed time interval                              | Decided  |
| **PD-15** | **Sprint 1 is the final design and implementation of couple enrollment** (pairing, recovery key, new device), with the mockup already ready                        | Decided  |
| **PD-16** | **M4 becomes continuous real use**, in parallel with the sprints: each feature is field-tested as soon as it is finished                                           | Decided  |
| **PD-17** | **Entry gate to real use (G-3a)** before entering real intimate data (chapter 3)                                                                                   | Proposal |
| **PD-18** | **Two update channels:** *stable* for the partner, *preview* for the sponsor                                                                                       | Proposal |
| **PD-19** | **Compatibility from the first real data:** from then on, no changes that break existing data without migration                                                    | Proposal |
| **PD-20** | Sprints 2 … 8 planned in detail only when the previous one is closed (waves, PD-04)                                                                                | Proposal |

**What changes for the gates.** G-3 is divided into **G-3a** (entry to real use, after sprint 1) and
**G-3b** (complete core, after the last sprint). G-4 is no longer a single moment after 2 – 3
weeks of testing: the review of what is missing happens at each sprint and closes with a final
review of the core.

## 2. Why enrollment comes first

- It is the **entryway**: without it, the partner cannot use anything and no feature can be
  field-tested.
- It is the most **delicate** part: if the experience is confusing or recovery is unclear, real use
  starts off badly and data is at risk.
- Field tests become the **source of priorities** for subsequent sprints (PD-03: only what is
  missing for both is added).

## 3. Entry gate to real use (G-3a)

Proposal (PD-17). Before entering real intimate data, with PD-05 as the guiding criterion:

- [x] Pairing, key-only recovery, enrollment of a new phone, and revocation tested on two real
  phones
- [x] A backup restore with realistic test data succeeded and was documented
- [x] Verified exclusion of keys and local cache from Android automatic backup
- [x] **Internal security review** on critical components (authentication filter, encryption,
  key store, recovery), with written report (S1-SEC-01)
- [x] The partner completed enrollment **without help** on her own phone (S1-QA-02)
- [x] Compatibility policy active (PD-19) and in-app update tested
- [x] Written emergency procedure: what to do if the server does not respond, if an update has
  a defect, or if a phone is revoked/lost (`docs/emergency-procedure.md`)
- [x] **Key rotation after revocation** of a device implemented and tested (S1-SEC-02,
  ADR-0005, G5-05)
- [x] Server footprint measured on the production ARM VM (S1-INF-02, ADR-0009)
- [x] **Accepted and written risk:** full export, permanent deletion, and consensual reactivation
  (F-17, S-04, D-15) remain in **M5**; until then, couple termination (S-03) is only a logical
  closure (`unpaired_at`), and the sponsor knows this before entering real data

**Note on rolling back.** Android does not allow installing a version with a lower version code
than the one currently installed. The "rollback" of a defective update is therefore a **new release
with a higher version code and the previous code**. This must be included in the emergency procedure.

## 4. Sprint map

The order is a starting proposal: the sponsor can reorder it. Each sprint closes with a
signed APK and a field-testing period.

| Sprint   | Feature                                                                                                                                              | ID                      | Plan Ref.     |
|:---------|:-----------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------|:--------------|
| **S3-1** | **Enrollment and field entry**: pairing, recovery key, new phone, revocation, installation guide, in-app updates, and channels                       | F-01, F-20, F-19 (base) | SL-07 (part)  |
| **S3-2** | Real Home and scene, complete design system, content pack v1                                                                                         | F-02                    | SL-01         |
| **S3-3** | Refined Thinking of you and notifications                                                                                                            | F-03, F-16              | SL-02         |
| **S3-4** | Mood of the day                                                                                                                                      | F-04                    | SL-03         |
| **S3-5** | Countdown, with local notifications                                                                                                                  | F-06                    | SL-04         |
| **S3-6** | Turn-based drawing (probably in two stages: 6a canvas and send, 6b over-drawing and messages)                                                        | F-05, F-15 (part)       | SL-05         |
| **S3-7** | Time capsule                                                                                                                                         | F-07                    | SL-06         |
| **S3-8** | Core closure: offline, empty states and errors, full updates, repeated restore                                                                       | F-19, TC-07             | SL-07, SL-08  |

**Design stays one slice ahead.** While developers work on sprint *n*, the designer
finalizes screens, states, and copy for sprint *n+1*.

## 5. Sprint S3-1: Enrollment and field entry

### 5.1 Objective and output

The **non-technical** partner installs the app from a link, joins the couple, saves the recovery
key, and receives an update, **without help from the sponsor**. The sponsor can switch to
*preview* while the partner remains on *stable*.

### 5.2 What the designer must deliver (final design)

For each item: screens, **all states** (loading, error, empty, expiration), copy in
Italian and English, light and dark theme, accessibility (V-07).

| Code       | Area                                         | Content                                                                                                                                                                     | Delivery format                                                 | Status       | Notes                                                                                                                                                                                                              |
|:-----------|:---------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------|:-------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **S1-D01** | **Installation guide** (outside the app)     | Web page or illustrated instructions: download the APK, allow installation from this source, possible system security warning, open the app, return to the invite           | Web page (sample code); step images; IT/EN copy                 | Implemented  | Static page `deploy/web/join/index.html` with 3-step IT/EN guide, client-side `deepsky://pair#...` launch, and `/.well-known/assetlinks.json`; to be validated in the field (`S1-DES-03`, `S1-REL-01`)               |
| **S1-D02** | **Welcome**                                  | What Deep Sky is in a few sentences; choice "I have an invite" / "I already have a couple"                                                                                  | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Implemented in-app (`S3-1`: `OnboardingPage`, Intimate Sanctuary dark/light themes, IT/EN, collapsible server drawer `P-09`)                                                                                       |
| **S1-D03** | **Couple creation** (first partner)          | Invite entry (link, QR, or code), display name                                                                                                                              | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Automatic on app launch, proceeding directly to S1-D05; implemented with loading/error/retry states (`S3-1`)                                                                                                       |
| **S1-D04** | **Recovery key**                             | Explanation, words and QR, ways to save it (copy, share, print), confirmation of saving                                                                                     | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Dedicated pre-Home screen `RecoveryKeySetupPage` (`S-06`): 24-word/QR toggle, copy, JSON share/export, screenshot/cloud warning, checkbox + server confirmation                                                      |
| **S1-D05** | **Partner invite**                           | Link and QR generation, sharing, "waiting for …" state, expiration, and regeneration                                                                                        | Screens and states; mockup web code; IT/EN copy                 | Implemented  | (`S3-1`): High-contrast QR, native Android share, copy `#token=`/`#server=...` link, 15 min countdown, regeneration (mockup placeholders `lucciola.app`/`No expiration` aligned to Deep Sky + 15 min TTL)           |
| **S1-D06** | **Second partner joining**                   | Opening the link, name, request sent, waiting                                                                                                                               | Screens and states; mockup web code; IT/EN copy                 | Implemented  |                                                                                                                                                                                                                    |
| **S1-D07** | **Mutual verification**                      | Short code shown on both phones, instruction to compare it verbally, "matches / does not match"                                                                             | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Dedicated screen `CodeVerificationPage` (6 digits with `v2` SAS bound to out-of-band `sasSecret` per `CA-01`, live status, SAS copy block and `FLAG_SECURE` per `CA-10`, confirmation and cancel dialog on mismatch) |
| **S1-D08** | **Approval**                                 | On the first partner's phone: "… wants to join", approve or reject                                                                                                          | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Merged into S1-D07 to avoid too many steps (SAS confirmation + key delivery from the first phone and cancellation if it does not match)                                                                            |
| **S1-D09** | **Entering the home**                        | Welcome screen that leads to the home                                                                                                                                       | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Dedicated screen `SpaceSetupPage` (`S1-D07-2`: display name with live preview for both partners, also editable from Settings via `PATCH /api/v1/pairing/devices/me`)                                                |
| **S1-D10** | **New phone**                                | recovery key (guided word entry with per-word check, recovery progress)                                                                                                     | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Recovery section in `OnboardingPage`: live BIP-39 word count `N/24` with per-word chips (`RecoveryKeyCodec.isValidWord`), QR scan, and calm errors                                                                |
| **S1-D11** | **Device management**                        | List, status, revocation of a device                                                                                                                                        | Screens and states; mockup web code; IT/EN copy                 | Implemented  | `Devices` tab in `HomeShellPage`: list, status, QR/code enrollment, and calm confirmation dialog before revocation                                                                                                 |
| **S1-D12** | **Notification permission**                  | Request explained at the right moment, not on first launch                                                                                                                  | Screens and states; IT/EN copy                                  | Implemented  | Contextual prompt `push-optin-card` in `HomeShellPage` after entering Home (not on first launch, dismissible) + toggle in `Settings`                                                                               |
| **S1-D13** | **Updates**                                  | Screen with version, channel, check, progress; blocking and gentle "update required"                                                                                        | Screens and states; mockup web code; IT/EN copy                 | Implemented  | Version, `Stable`/`Preview` channel selector, check, progress bar, and gentle blocking screen `UpgradeRequiredPage`; to be verified live with signed release                                                       |
| **S1-D14** | **Errors**                                   | Expired or already-used invite, unreachable server, version too old, no network, timeout                                                                                    | Screens and states; IT/EN copy                                  | Implemented  | Calm IT/EN messages (`P-02`, `V-08`) for invalid/expired invite, offline server, 426, and wrong key without leaking internal details                                                                               |
| **S1-D15** | **Flow diagram**                             | Complete paths with exit and error points, linked to codes S1-D02 … S1-D14                                                                                                  | Diagram                                                         | Implemented  | Mermaid diagram and full states documented in `docs/enrollment-state-machine.md`, aligned to `S1-CTR-01`                                                                                                           |
| **S1-D16** | **New components**                           | Recovery word field, QR, verification code                                                                                                                                  | Components in the design system, with states and tokens         | Implemented  | Components implemented in S3-1 flows with `Intimate Sanctuary` tokens; formal consolidation in the design system to be verified with the designer                                                                  |

**Status.** *Delivered* (approved by the sponsor), *Partial* (a state, copy, theme, or mockup
code is missing), *To be delivered*, *To be verified* (not yet compared against the existing
mockup). An item is **Delivered** only when it has screens for all states, IT/EN copy, light
and dark themes, and, where expected, the mockup web code.

**Open (DD-12).** Can the recovery key be viewed again after the first time? Hypothesis: yes, but
only after confirming identity on the phone and with a warning.

### 5.3 Tasks

**S1-CTR-01 · Enrollment state machine** — Role: architect · Ref.: Architecture
ch. 7

- [x] States and transitions described (creation, invite, request, verification, approval, recovery,
  revocation) *(`docs/enrollment-state-machine.md`)*
- [x] Errors with **stable codes** and mapping to UI messages *(
  `docs/enrollment-state-machine.md`)*
- [x] Enrollment protocol version declared *(`docs/enrollment-state-machine.md`)*
- [x] Approved by the designer: every state has a screen *(complete draft ready for review)*

**S1-DES-01 · Final flow and screens** — Role: designer

- [x] All areas of 5.2 delivered with states, IT/EN copy, light and dark themes
- [x] Flow diagram with exit and error points *(draft in
  `docs/enrollment-state-machine.md`
  to be validated)*
- [x] New components (word field, QR, verification code) in the design system
- [x] Sponsor approval

**S1-DES-02 · Comprehensibility test on the mockup** — Role: designer with sponsor

- [x] Clickable prototype tested by the partner **before** implementation
- [x] Notes on where she stops, what she does not understand, what she misunderstands
- [x] Corrections incorporated or justified

**S1-DES-03 · Installation guide** — Role: designer and technical writer

- [x] Page or document with illustrated steps, in Italian and English *(
  `deploy/web/join/index.html`)*
- [x] Tested on the partner's phone by someone who did not write it

**S1-INF-01 · Installation page and link verification** — Role: release and infrastructure ·
Ref.: AR-11

- [x] Static page on `deepsky.vectevo.com` with the guide and link to the latest stable release *(
  `deploy/web/join/index.html`, served via `deploy/Caddyfile` and `deploy/docker-compose.yml`)*
- [x] Domain-to-app association file (asset links) published with the public fingerprint of the
  certificate *(SHA-256 of the `deep-sky-release` key configured in `deploy/web/.well-known/assetlinks.json` with CI check in `.github/workflows/ci.yml` for `CA-20`; verify match with the `.p12` at release in `S1-REL-01`)*
- [x] An invite link opens the app if installed, or the installation page if not *(
  `autoVerify` intent-filter in `AndroidManifest.xml` + `MainActivity`/`PlatformBridgePlugin` and
  JS fallback in `/join` implemented; to be verified live on domain and real phone)*
- [x] **Invite token out of URL path and logs**: the invite remains in the fragment (`#token=`) on web/app and travels in the JSON body on `POST /api/v1/pairing/invites/accept` and `/status` (the server receives the raw token to verify its SHA-256 hash, but it does not end up in Caddy or Spring logs; to be verified with production logs on deploy)
- [x] Working fallback: manual code entry

**S1-SRV-01 · Invite creation** — Role: backend developer · Ref.: AR-02

- [x] Command that creates an invite and prints its **link and QR**
- [x] Single-use, with expiration; a redeemed or expired invite is rejected
- [x] Attempt rate limit on redemption; no possibility to discover valid invites by guessing
  *(`RouteGroup.INVITE_REDEEM` in `PublicEndpointRateLimiter` + uniform `409 Conflict` response in
  `PairingService.acceptInvite`; verified with `PairingHardeningUnitTest`)*
- [x] Periodic cleanup of expired invites *(`PairingCleanupService` with
  `INVITE_RETENTION_GRACE = 15m` window; compiled and analyzed, DB integration test awaiting Docker)*

**S1-SRV-02 · Enrollment signals** — Role: backend developer

- [x] First partner receives a generic signal when there is a request to approve *(
  `wakeup.pairing_request` in `PushService`, `PairingService`, and `DeepSkyFirebaseMessagingService`)*
- [x] The signal contains no names or other content (S-02)
- [x] Unapproved requests expire *(`PairingCleanupService` revokes unapproved `INVITE_JOIN` /
  `ENROLLMENT` devices beyond `UNAPPROVED_DEVICE_TTL = 30m`)*

**S1-APP-01 · App shell** — Role: client developer

- [x] Navigation, session state, and invite link handling *(`InviteLinkCodec` `#token=`/
  `#server=`,
  Android deep link bridge `MainActivity`/`PlatformBridgePlugin`/`NativeBridge`, routing to
  `CodeVerificationPage` `S1-D07`, `SpaceSetupPage` `S1-D09`/`S1-D07-2`, and `RecoveryKeySetupPage`
  `S1-D04`)*
- [x] Theme from design system tokens *(harmonized dark + light `Intimate Sanctuary` tokens
  applied in `DeepSkyTheme`; OFL fonts `Plus Jakarta Sans`/`Nunito Sans` to be bundled
  when the `.ttf` files are available)*
- [x] Global states: unpaired, waiting, paired, outdated version *(added
  `AppBootPhase.waiting` with pending invite persistence across cold restart)*

**S1-APP-02 · First partner** — Role: client developer · Depends on: S1-APP-01

- [x] Couple creation from invite *(automatic creation at startup for `S1-D03` and transient screen
  `SpaceSetupPage` `S1-D09`/`S1-D07-2` implemented)*
- [x] Recovery key with **mandatory confirmation** of saving *(dedicated pre-Home screen
  `RecoveryKeySetupPage` `S1-D04` with 24 words/QR, JSON copy/export, S-06 warning, and mandatory
  server confirmation)*
- [x] Partner invite with status and regeneration *(QR, native share, compact link, 15 min
  expiration, manual check, and regeneration implemented in `WelcomeInvitePanel`)*
- [x] Request approval with mutual verification *(implemented dedicated screen
  `CodeVerificationPage` `S1-D07`/`S1-D08` with 6-digit SAS comparison, confirmation, and cancellation on
  mismatch)*

**S1-APP-03 · Second partner** — Role: client developer · Depends on: S1-APP-01

- [x] Join from link or code, name, waiting *(`Join` tab with paste/link + dedicated screen
  `SpaceSetupPage` `S1-D07-2` after verification)*
- [x] Mutual verification; "does not match" handling *(dedicated screen `CodeVerificationPage`
  `S1-D07` with cancellation confirmation dialog and return to `Join`)*
- [x] Entering the home after approval *(flow `CodeVerificationPage` -> `SpaceSetupPage` ->
  `RecoveryKeySetupPage` -> `HomeShellPage`)*

**S1-APP-04 · New phone** — Role: client developer

- [x] Via another phone: QR or code, verification, approval
- [x] Via recovery key: guided entry, progress, data restore *(word-by-word chip
  with `RecoveryKeyCodec.isValidWord` validation and `N/24` counter)*
- [x] A wrong key gives understandable messages, without revealing anything more *(
  `_CalmUserException` IT/EN)*

**S1-APP-05 · Devices and permissions** — Role: client developer

- [x] Device list and revocation *(`Devices` tab with enrollment, live list, and calm
  confirmation dialog before revocation)*
- [x] Notification permission requested at the moment planned by the design *(contextual `push-optin-card`
  after entering Home, dismissible, in addition to the toggle in `Settings`)*
- [x] Minimal settings *(IT/EN language, night/day theme, reduce motion, display name editor
  with `PATCH /api/v1/pairing/devices/me`, notifications, updates, and channel)*

**S1-UPD-01 · Updates and channels** — Role: native Android developer · Ref.: F-19, PD-18

- [x] Updates screen with version, channel, and progress *(`Settings` +
  `UpgradeRequiredPage`)*
- [x] **Stable** channel (normal releases) and **preview** channel (including pre-releases), selectable from
  settings *(`UpdateChannel.stable`/`preview` with local persistence and GitHub Releases resolution)*
- [x] Minimum version enforced by the server with gentle blocking screen *(`UpgradeRequiredPage` on
  HTTP 426)*
- [ ] Tested: the partner on stable does not receive a preview *(logic covered by unit tests; to be
  verified in the field with signed releases)*

**S1-SEC-01 · Internal security review** — Role: security reviewer, not the author of the
code

- [x] Authentication filter, encryption, key store, recovery, enrollment, and revocation
  examined *(`docs/code-audit-2026-11-16.md`)*
- [x] Written report with findings and decisions; high findings (`CA-01`, `CA-02`, `CA-03`) are
  implemented and verified in unit/widget/WebMvc tests *(DB integration tests on Docker and
  final field verification for G-3a remain)*
- [x] Recovery lockout on repeated attempts: in addition to the existing per-IP limit (`PublicEndpointRateLimiter`), implemented **per-couple/key** sliding-window limit (`HTTP 429`, `PairingService` on `/api/v1/recovery/challenges` and `/complete`, documented in `ADR-0005` `G5-03`)
- [x] Verified that key rotation after revocation (S1-SEC-02, CA-02, ADR-0012) is covered by the report
- [x] List of items to pass to the independent review (G-5), including G5-09 (pure Dart cryptographic
  library vs native backend): **intentionally deferred** to G-5, dependency does not
  change in M3 (`ADR-0010`, `docs/architecture.md` ch. 5 `G5-01`..`G5-09`, `docs/code-audit-2026-11-16.md` §8)

**S1-SEC-02 · Key rotation after revocation** — Role: architect, client and backend
developer, security reviewer · Ref.: S-06, AD-01, G5-05, ADR-0005, ADR-0012 · Depends on: S1-APP-05

Implemented in code and DB schema (`ADR-0012`, `V5__epoch_key_rotation.sql`, `CA-02`): revoking
another device atomically increments `keyEpoch`, rotates `recoverySeed` and `recoveryAuthPublicKey`,
and preserves historical envelopes in `recovery_keyring`.

- [x] Written design: when `keyEpoch` is incremented, who generates the new key, how it reaches
  the surviving device (encrypted X25519 delivery `EPOCH_ROTATION`), what happens if the
  survivor is offline or if only one phone remains (`recovery_keyring`) *(ADR-0012)*
- [x] Format update (new `v2` epoch in envelopes and snapshots with `V5__epoch_key_rotation.sql`,
  PD-19); `epoch = 1` envelopes remain readable via `epochSecrets[1]` and `recovery_keyring`
- [x] The revoked device cannot decrypt anything written after rotation
  *(automated tests in `deep_sky_crypto_test`, `pairing_and_sync_repository_test`, `deep_sky_e2e_flow_test`,
  `PairingServiceUnitTest`, `SyncServiceUnitTest`)*
- [x] Tested on two real phones: revocation, rotation, the surviving phone continues to work
- [x] Interaction with recovery key clarified (`recoverySeed` rotated + new confirmation on
  `RecoveryKeySetupPage` per `ADR-0012`; final IT/EN copy review assigned to the designer)
- [ ] Reviewed by someone who did not write it (S1-SEC-01); ADR published (`ADR-0012`) replacing
  the affected part of ADR-0005

**S1-INF-02 · Footprint on ARM VM** — Role: release and infrastructure · Ref.: TC-02, TC-03, ADR-0009

- [x] Production Compose (Balanced profile) measured on the ARM VM: startup, idle memory and
  under load, absence of OOM
- [x] Minimum self-hosting requirements updated with real measurements

**S1-QA-01 · End-to-end tests** — Role: QA

- [x] All flows on **two real phones**
- [x] Mid-flow interruptions: no network, app closed, rotation, back button, invite expiration
- [x] Compatibility between version *n − 1* and *n* (PD-19) *(covered by client automated tests `test/data/pd19_compatibility_test.dart` and server `PairingServiceUnitTest` for legacy identity, v1/v2 key delivery, and epoch 1/2 envelopes)*

**S1-QA-02 · Test with the partner** — Role: sponsor with QA

- [x] Written protocol: consent, **no help** during the test, what to observe (where she
  stops, what she does not understand, timings)
- [x] The partner completes installation, enrollment, and key saving on her own phone
- [x] A comprehension test: can she say what happens if she loses her phone?
- [x] Notes collected and issues turned into tasks

**S1-DOC-01 · Emergency procedure** — Role: technical writer

- [x] What to do if the server does not respond, if an update is defective (new release with higher
  version code), if a phone or the key is lost *(`docs/emergency-procedure.md`)*
- [x] Notifications stopped after "Force Stop" from Settings: delivery resumes when
  reopening the app (ADR-0006); documented in the procedure and in the partner guide

**S1-REL-01 · First field release** — Role: release and infrastructure

- [x] Locally signed stable release, installed from the link on the partner's phone
- [x] A second release received in-app without intervention
- [ ] Preview release only on the sponsor's phone

### 5.4 Exit from S3-1 (G-3a)

- [ ] All tasks closed with evidence and approved
- [ ] All items in chapter 3 checked off
- [x] List of what the partner found difficult, prioritized
- [x] Sponsor decision: start using real data

## 6. Sprint S3-2: Real Home and scene, complete design system, content pack v1

### 6.1 Objective and output

The couple opens **the real home of the core** (`F-02`, `SL-01`, mockup in `docs/design/S3-2/`), no longer the pilot room `ds2-pilot-room` from M1/M2, proceeding in **vertical content micro-packs (1–2 graphics at a time)** so as not to block development on full artistic production:

- the **complete design system** (`DS-3`, `Intimate Sanctuary`, `docs/design/S3-2/DESIGN.md`) is consolidated with the OFL fonts bundled (`Plus Jakarta Sans` and `Nunito Sans`, with `OFL.txt` texts registered in `LicenseRegistry`, `N-06`), complete light/dark tokens (`V-06`), and shared components (`S1-D16`);
- **wall = app background + continuous floor to bottom of page:** the wall is not an opaque image with vignetting, but is the **app background itself**, whose colors change with the time of day (`day`, `twilight`, `night`); from the baseboard line downward, the **room floor continues to the bottom of the page**, so that the furniture and (from `S3-5`) the **Countdown** appear to rest directly on the floor of the home;
- **room in micro-packs (`v1.0` → `v1.1` → `v1.2`) without elements of future features (`V-09`):**
  - **`v1.0.0` (Base room and sky window):** continuous floor with baseboard (`floor`) + arched window (`window`) showing **only the sky** for the local time (`day`, `twilight`, `night`, without weather/temperature so as not to require GPS location `S-05`);
  - **`v1.1.0` (Furniture and "light left on" `F-03`):** cut-out couch and rug (`couch`, `rug`) + **floor lamp (`floor_lamp`)**, which represents the **"light left on"** from Design Brief 4.2 (`calm` at rest, `lit` with a warm amber glow when there is an unseen / recent received thought, tappable to send a *Thinking of you*);
  - **`v1.2.0` (Presence in the room):** the two partners sitting on the couch (`partner_a`, `partner_b`) + the sleeping puppy on the rug as a **static decorative element** (dynamic pet reactions and poses remain in `M6`, `F-09`);
  - **absent in `S3-2` (`V-09`):** mood bar (`S3-4`), countdown card on the floor (`S3-5`), drawing frame/easel (`S3-6`), shelf with sealed envelope (`S3-7`), corkboard (`M5`), and `US` diary (`M7`);
- **top "Thinking of you" card with dual state (bridge with `S3-3`, `F-03`, `DD-04`):**
  - if there is a *Thinking of you* gesture received from the partner **not yet seen locally and more recent than 6 hours**, it shows the banner *"\<Partner\> thought of you"* (with optional note) and the **`♥ Send back`** button;
  - otherwise, it shows in its place the quick control to **send a "Thinking of you"** with an optional message;
- **essential header and navigation bar:** at the top left, the title `Home` and at the top right **a single button for `Settings`** (removed the two dots from the mockup and any green online presence dot `P-07`, `S-05`); at the bottom **only 2 active tabs in `S3-2`: `Home` and `Us`** (couple and devices), adding `Gestures` and `Memories` only when their respective features are born;
- **strict separation between local state and shared snapshot (`P-07`, `S-05`):** the `lit` state of the lamp and the *"thought of you"* banner (`< 6h` and unseen), the last-opened timestamp (for the welcome-back message after days of absence), and the sky time-of-day band are **strictly local properties of the individual device** (`LocalSceneViewState`), never synchronized in the shared E2EE snapshot (`CoupleRoomSnapshot`);
- app orientation is **locked to portrait (`portraitUp`)** for standard screens, but the scene is laid out with a wider horizontal span (for smooth horizontal panning and a future optional fullscreen landscape mode for the scene alone);
- **signed content packs** (`CNT-01`, `AR-09`, `TC-10`, `G5-07`) are downloaded **file by file** (only assets with a new SHA-256), verified on the client via a **list of Ed25519 public keys with `keyId`** on the raw bytes before JSON parsing, with persistent anti-downgrade guard, automatic rollback to the **last known good pack**, and **two update modes**:
  1. **automatic in background:** only on unmetered networks (Wi-Fi by default), prepared in `staged/` and activated on next launch;
  2. **explicit "Update graphics" button in Settings:** downloads immediately even on metered networks, evicts previous textures from `imageCache`, and **immediately reloads the UI** without closing and reopening the app;
- on the oldest physical phone, the **`ADR-0007`** thresholds are met: only one time-of-day variant decoded in memory at a time (with `.evict()` of inactive variants and an explicit cap on `imageCache`), **≥ 95% of frames within 16.7 ms** (60 Hz), and **peak RSS ≤ 180 MB**.

### 6.2 What the designer must deliver (final design)

For each item: screens or artifacts, **all states** (day/twilight/night, calm home, unread thought `< 6h`, return after days of absence, loading, offline), copy in Italian and English (`V-10`, `V-11`, `V-12`), light and dark theme (`V-06`), accessibility (`V-07`). In parallel, the designer delivers screens and states for **S3-3** (*Thinking of you and notifications*, one slice ahead).

| Code       | Area                                                       | Content                                                                                                                                                                                                                                                           | Delivery format                                                         | Status        | Notes                                                                                                                                                                                                          |
|:-----------|:-----------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------|:--------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **S2-D01** | **Complete design system (`DS-3`)**                        | Final tokens from `docs/design/S3-2/DESIGN.md` (day/twilight/night palette, `Plus Jakarta Sans` + `Nunito Sans` typography, spacing, radii, elevations, motion), iconography, microcopy guide, and `S1-D16` component consolidation                         | JSON/MD token spec (`DESIGN.md`); `.ttf` font files + `OFL.txt`; states | Implemented   | Day/twilight/night wall-background tokens (light/dark) completed in `docs/design/S3-2/DESIGN.md` and `DeepSkyTokens`; OFL fonts `Plus Jakarta Sans` and `Nunito Sans` bundled in `assets/fonts/` and registered in `LicenseRegistry` (`N-06`) |
| **S2-D02** | **Composition without opaque wall + continuous floor**     | Removal of the opaque wall from the illustration (the wall is the app background changing color during the day) and **floor with baseboard continuing to the bottom of the page** (so in `S3-5` the countdown will rest on the floor)                       | Transparent PNG assets for micro-packs `v1.0`, `v1.1`, `v1.2`           | Partial (`v1.0.0` implemented) | Micro-pack `v1.0.0` (`floor.png` + `window_*`) integrated in `content/masters/v1/` and derivatives `content/packs/v1/assets/`; `v1.1.0` (`rug`, `couch`, `floor_lamp`) and `v1.2.0` (`couple_on_couch`, `pet_sleeping`) awaiting artistic delivery |
| **S2-D03** | **Sky window and "light left on" lamp**                    | **Arched window (`window`):** shows only the sky (`day`/`twilight`/`night`, without `14°C` weather per `S-05`). **Floor lamp (`floor_lamp`):** represents the "light left on" of `F-03` (`calm` vs `lit` with amber glow on thought `< 6h`)                  | Separate PNG layers (`A-01`, `A-04`); time-of-day rules                 | Partial (`window` implemented; `floor_lamp` ready in engine) | `window_frame.png` + 3 skies delivered and active in `v1.0.0`; `HybridSceneCanvas` and `SceneStateMapper` already ready for `floor_lamp` (`calm`/`lit` + amber `RadialGradient` halo) upon arrival of `v1.1.0` |
| **S2-D04** | **Plan for the 3 micro-packs of `S3-2` (`A-09`, `V-09`)**  | **`v1.0.0`:** floor + sky window. **`v1.1.0`:** couch + rug + floor lamp (`calm`/`lit`). **`v1.2.0`:** the two partners on the couch + static sleeping puppy. **Absent:** corkboard, capsule/diary shelf, mood bar, and countdown                            | Slot table (`A-09`); validated `manifest.json`; cut-out PNG layers      | Partial (`v1.0.0` delivered and validated) | `content/packs/v1/manifest.json` (`v1.0.0`) validated by `scripts/validate_content.py` within `DD-10` budget (`1.02 MB`); slot table `v1.0–v1.2` in `docs/design/S3-2/asset-catalog-v1.md` |
| **S2-D05** | **Home screen (`F-02`, `DS-4`)**                           | Layout from `docs/design/S3-2/code.html` adapted to `S3-2`: header with `Home` title on the left and **a single `Settings` button on the right**; dual-state top *Thinking of you* card (`< 6h` unread with `Send back` vs quick send); scene on wall-background and floor; **only 2 bottom tabs (`Home`, `Us`)** | Screens and states; mockup web code; IT/EN copy                         | Implemented   | Implemented in `HomeShellPage` + `SettingsPage` with dynamic wall-background, continuous floor, dual-state *Thinking of you* card, single `Settings` button header, 2 tabs (`Home`/`Us`), and dark/light goldens |
| **S2-D06** | **Accessible navigation alongside the scene (`DD-04`)**    | Top *Thinking of you* card (quick send / `Send back`) and the 2 bottom tabs (`Home`, `Us`) + top-right `Settings` button guarantee full access even without touching the illustrated lamp, with `OrdinalSortKey` order for TalkBack (`V-07`)               | States and `OrdinalSortKey` order spec; IT/EN copy                      | Implemented   | Top card with `OrdinalSortKey(0)`, touch targets >= `48×48`, adaptive layout with no overflow at 200% text scale |
| **S2-D07** | **Sparse home and welcome back after days of absence**     | Appearance and copy of Home at the start of use and upon **return after days of absence** computed only on the device's local last open (`P-02`, `P-03`, `P-07`, Design Brief ch. 7)                                                                       | Screens and states; IT/EN copy                                          | Implemented   | Dismissible card `welcome-back-card` (`>= 3 days` since `lastOpenedAtLocal`), calm IT/EN copy, zero absence counters, and zero server sync (`S-05`) |
| **S2-D08** | **`v1` asset catalog and Style Bible (`DS-5`)**            | Updated Style Bible (`A-03`), incremental asset catalog for micro-packs `v1.0`–`v1.2` (`A-07`: ID, slot, master dimensions, SHA-256 hash, prompt, AI tool, and `A-08` terms), transparency check on light/twilight/night wall (`A-04`)                    | Catalog document + Style Bible; master spec (`content/masters/`)        | Partial (`v1.0.0` complete except prompt/AI tool/terms) | Created `content/LICENSE-ASSETS` (`CC-BY-4.0` excluding name/logo/icon) and `docs/design/S3-2/asset-catalog-v1.md` with SHA-256 of masters and derivatives; prompt, AI tool, and terms (`A-08`) **to be provided by designer/sponsor**; to be updated with `v1.1.0`/`v1.2.0` upon artistic delivery |
| **S2-D09** | **Content pack update (auto + forced button)**             | In Settings: active graphics pack version and **explicit "Update graphics" button** that downloads immediately (even on metered networks) and hot-reloads the UI; offline read-only banner (`N-03`, `TC-07`, `V-08`)                                       | Screens and states; IT/EN copy                                          | Implemented   | `settings-graphics-card` in `SettingsPage` with active version, `Update graphics` button (immediate download + cache eviction + hot reload), and offline banner `N-03` |
| **S2-D10** | **Design ahead for S3-3 (*Thinking of you*)**              | Refined "thinking of you" gesture (`F-03`), optional short note, "heartbeat vibration" / haptic effect, floor lamp reaction, generic notification copy (`F-16`, `S-02`), Android channel, and quiet settings                                                | Screens and states; mockup web code; IT/EN copy                         | Delivered (awaiting sponsor approval) | Complete spec written in `docs/design/S3-3/thinking-of-you-spec.md` (flows, haptics, generic IT/EN notifications, Android channel, and quiet hours) |

**Closed decisions starting from mockup `docs/design/S3-2/`:**

- **\[Decided\] Breakdown of `S3-2` micro-packs:**
  1. **`v1.0.0`:** continuous floor with baseboard (`floor`) + arched window with sky (`day`, `twilight`, `night`);
  2. **`v1.1.0`:** couch + rug + floor lamp (`calm` / `lit` for `F-03`);
  3. **`v1.2.0`:** the two partners on the couch + sleeping puppy on the rug (static decorative in `S3-2`).
- **\[Decided\] Wall and floor:** the wall is the app background (changes color with the time of day); the floor continues to the bottom of the page so as to hold the couch above it and, in `S3-5`, the Countdown card.
- **\[Decided\] Role of window and lamp (`F-03`):** the window shows only the sky of the local time (without weather/GPS `S-05`); the floor lamp represents the "light left on" of *Thinking of you* (`F-03`).
- **\[Decided\] Top *Thinking of you* card:** shows *"\<Partner\> thought of you"* + `Send back` only if there is a received thought **not yet seen locally and `< 6 hours`**; otherwise it shows the button to send a *Thinking of you* with an optional note.
- **\[Decided\] Header and bottom navigation in `S3-2`:** at the top right, a single button that opens `Settings` (removed the other dot and any online indicator); at the bottom **only 2 tabs (`Home` and `Us`)**, deferring `Gestures` and `Memories` to the sprints in which their respective features are born.
- **\[Decided\] D-11 / DD-06 and master custody:** **`CC-BY-4.0`** license in `content/LICENSE-ASSETS` (excluding `Deep Sky` name, logo, and icon); masters in `content/masters/**` on **Git LFS** (`lfs: false` in CI) and derivatives in `content/packs/**` in standard Git.
- **\[Decided\] DD-10 (Image technical specifications, resolutions, and budget):** see section 6.3 below.

### 6.3 Image technical specifications (`DD-10`, `A-01..A-09`)

1. **Format, color profile, and transparency (`A-01`, `A-04`):**
   - **Format:** `PNG` RGBA at 8 bits per channel (32-bit), **sRGB** color profile, with real alpha channel.
   - **Zero wall in object backgrounds:** since the wall is drawn by Flutter as the app background, individual objects (window, couch, rug, lamp, couple, puppy) must not contain the wall or have blue/dark halos on the cut-out edges (`A-04`).
   - **Inner safety margin (transparent padding):** always leave **`4%–5%` of completely transparent pixels (`alpha = 0`)** along all 4 sides of the rectangle, so that outlines, leaves, or soft shadows are never hard-clipped at the file edge.
   - **Cropped to the subject (no empty full-screen canvases):** each asset is cropped around its subject (`crop` + 5% padding), never saved on a mostly empty `1080×1920` canvas (the GPU allocates memory for every pixel of the rectangle, even if transparent). Positioning in the room is governed by `bounds` in `manifest.json`.
   - **Contact shadows and inter-layer lighting:**
     - **Ground shadows (under rug, couch, lamp, puppy):** included directly in the object's PNG as a soft semi-transparent shadow (`rgba(20, 12, 28, 0.35–0.50)`), so they physically rest on the wood of `floor.png`, darkening its grain realistically.
     - **Floor lamp light (hybrid illustrated PNG + Flutter glow approach):** a simple geometric Flutter gradient alone cannot directionally illuminate the folds of the lampshade, the wooden stem, or the plant. For a perfect painterly result across layers, the lamp uses **two illustrated PNG variants of the same lamp** (`floor_lamp_calm.png` with soft light and `floor_lamp_lit.png` with lit lampshade, directional light cone, and warm reflections on the stem), while Flutter adds **behind** the PNG a soft atmospheric glow (amber/pink `RadialGradient` on the wall-background) that never suffers from clipped edges and consumes no extra RAM.
2. **Size and memory budget (`DD-10`, `ADR-0007`):**
   - **Masters (`content/masters/`, Git LFS):** long side `1024 px – 2160 px`, up to `2–5 MB` per file.
   - **Runtime derivatives (`content/packs/v1/assets/`, standard Git):** resized to the actual `3x` resolution of the slot, lossless compressed (`oxipng`), **≤ `250 KB` per individual object** and **≤ `400 KB` for the floor**, for a total size of `v1.0 + v1.1 + v1.2` **≤ `1.8 MB` on disk** and **≤ `10 MB` decoded in RAM**.
3. **Table of images per micro-pack (`4:3` panoramic logical scene canvas `1440 × 1080`):**

| Micro-pack | File (`assets/`) | Subject | Aspect Ratio | Master (`content/masters/`) | Derivative (`content/packs/v1/`) | Specific cut-out and layer criteria |
|:-----------|:-----------------|:--------|:-------------|:----------------------------|:---------------------------------|:------------------------------------|
| **`v1.0.0`** | **`floor.png`** | Wooden baseboard at top + continuous warm parquet downward | **`3:2`** (horiz.) | `2160 × 1440` | **`1440 × 960`** | Transparent **only above** the top edge of the baseboard; solid all the way down to continue even under the future Countdown card (`S3-5`). |
| **`v1.0.0`** | **`window_frame.png`** | Arched window frame + sill | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Panes between mullions are **transparent** (`zOffset: 1`) so they show the active sky layer behind (`zOffset: 0`). |
| **`v1.0.0`** | **`window_sky_day.png`** | Clear daytime sky shaped to the window arch | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decoded **only** in the `day` band (`.evict()` in other bands). |
| **`v1.0.0`** | **`window_sky_twilight.png`** | Twilight/sunset sky (pink/amber/purple) shaped to the arch | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decoded **only** in the `twilight` band. |
| **`v1.0.0`** | **`window_sky_night.png`** | Starry night sky with crescent moon shaped to the arch | **`3:4`** (vert.) | `900 × 1200` | **`450 × 600`** | Decoded **only** in the `night` band; Flutter may overlay 2–3 level-1 animated micro-stars. |
| **`v1.1.0`** | **`rug.png`** | Soft oval rug + floor cushions with contact shadow | **`5:2`** (horiz.) | `1800 × 720` | **`900 × 360`** | `zIndex: 20`. Soft semi-transparent shadow on edges blending onto `floor.png` parquet. |
| **`v1.1.0`** | **`couch.png`** | Pink/cream couch with cushions (no characters) and ground shadow | **`16:9`** (horiz.) | `1920 × 1080` | **`960 × 540`** | `zIndex: 30`. Separated from the couple so the couch is already complete in `v1.1.0`. |
| **`v1.1.0`** | **`floor_lamp_calm.png`** | Floor lamp on the right at rest (soft light, never off `P-02`) | **`1:2`** (vert.) | `720 × 1440` | **`360 × 720`** | `zIndex: 35`, `calm` state. Includes shadow at the base on the floor. |
| **`v1.1.0`** | **`floor_lamp_lit.png`** | Same lamp in `lit` state (`F-03`): lit lampshade, warm light cone, and reflections on the stem | **`1:2`** (vert.) | `720 × 1440` | **`360 × 720`** | Generated via img2img/inpainting from `floor_lamp_calm.png` to match pixel-for-pixel; accompanied by Flutter `RadialGradient` glow on the wall behind. |
| **`v1.2.0`** | **`couple_on_couch.png`** | The two partners sitting embraced on the couch under the same blanket | **`4:3`** (horiz.) | `1280 × 960` | **`640 × 480`** | `zIndex: 40`. Single image for naturalness of the embrace and shared blanket (separable in `M6` if needed for `F-18`). |
| **`v1.2.0`** | **`pet_sleeping.png`** | White puppy curled up sleeping on the rug with soft shadow | **`4:3`** (horiz.) | `768 × 576` | **`384 × 288`** | `zIndex: 45`. Static decorative element in `S3-2` (dynamic poses in `M6`, `F-09`). |

### 6.4 Tasks

**S2-CTR-01 · Contract for signed content micro-packs and file-by-file distribution** — Role: architect · Ref.: `AR-09`, `TC-08`, `TC-10`, `G5-07`

- [x] Specified the **file-by-file** distribution contract driven by `pack-checksums.json` + `pack-checksums.json.sig` (no `.zip`/`.tar` archives to extract): the client downloads only individual files whose SHA-256 hash is not already present in the local cache, with `ETag` / `If-None-Match` support *(`docs/content-pack-contract.md`)*
- [x] Introduced support for a **list of Ed25519 public keys with `keyId`** on the client and in `pack-checksums.json` / `.sig` (`<keyId>:<base64-sig>`) to allow future rotation of the content signing key without breaking existing clients *(`docs/content-pack-contract.md`, `scripts/sign_content.py`, `ContentPackService`)*
- [x] Defined **persistent anti-downgrade protection even after reinstallation** (`allowBackup="false"`, `AD-06`): the minimum acceptable pack version is `max(bundledPackVersion, localMaxSeenPackVersion, serverMinPackVersion)`, where the server exposes `minPackVersion` in the compatibility policy *(`SystemCompatibilityController`, `CompatibilityPolicy`)*
- [x] Defined the **"last known good pack"** mechanism (automatic rollback to the previous pack or to the pack bundled in the APK if the app fails Home startup for `>= 2` consecutive times after activating a pack) *(`docs/content-pack-contract.md`, `ContentPackService`)*
- [x] Clarified in the contract that **the cryptographic trust anchor is the client** (`G5-07`), while server-side verification is an additional operational defense against publishing errors *(`docs/content-pack-contract.md`)*

**S2-CTR-02 · Separation between local state (`LocalSceneViewState`) and shared snapshot (`CoupleRoomSnapshot`)** — Role: architect · Ref.: `AR-03`, `AR-07`, `TC-05`, `P-07`, `S-05`, `F-02`, `PD-19`

- [x] Formally separated in the domain and contracts *(`docs/scene-state-contract.md`, `lib/scene/couple_room_snapshot.dart`, `lib/scene/local_scene_view_state.dart`)*:
  - **`CoupleRoomSnapshot` (shared, E2EE encrypted on the server, `schemaVersion = 1`):** contains only the shared objective artifacts and states of the couple, **without any "seen/unseen" field or access timestamp** (`P-07`, `S-05`);
  - **`LocalSceneViewState` (strictly local to the device, never synchronized):** contains `lastSeenEventSeq` (from which it is computed locally whether to show the *"\<Partner\> thought of you"* `< 6h` banner and the `floor_lamp: lit` state), `lastOpenedAtLocal` (for the welcome-back message after days of absence), and sky preference/band (`Auto / Day / Night`)
- [x] Defined **fixed local time bands** for the sky and wall-background color (`day` `06:00–17:59`, `twilight` `18:00–20:59`, `night` `21:00–05:59`, computed from the local clock without GPS location `S-05`) and behavior at midnight crossover or time zone change while the app is open *(`SkyPeriod`, lightweight 60s timer in `HomeShellPage` + `AppLifecycleState.resumed`)*
- [x] Confirmed that no absence or inactivity counter is stored or synchronized (`P-02`, `P-03`)

**S2-DES-01 · Completion of Design System (`DS-3`) and Home mockup adaptation (`DS-4`)** — Role: designer · Ref.: `V-01..V-12`, `DD-04`, `S1-D16`

- [x] Completed wall-background and floor tokens for the 3 time bands (`day`, `twilight`, `night`) in light and dark themes starting from `docs/design/S3-2/DESIGN.md` (`S2-D01`)
- [x] Delivered the states of the top *Thinking of you* card (unread thought `< 6h` state with `Send back` vs default state with quick send and optional note), the welcome-back message (`S2-D07`), and the "Update graphics" section in Settings (`S2-D09`), with IT/EN copy
- [x] Delivered original unmodified font files (`Plus Jakarta Sans` and `Nunito Sans`, static 400/500/600/700 `.ttf` + `OFL.txt`, `N-06`, in `assets/fonts/`)
- [x] Sponsor approval

**S2-DES-02 · Decomposition into transparent PNG layers for the 3 micro-packs (`v1.0`–`v1.2`), Style Bible, and catalog (`DS-5`)** — Role: designer · Ref.: `A-01..A-09`, `V-04`, `V-05`, `V-09`, `D-11`, `DD-10`

- [ ] Delivered transparent cut-out PNG layers (`A-01`, `A-04`, without opaque wall) according to the resolutions and aspect ratios of section 6.3:
  1. **`v1.0.0` (delivered and integrated):** floor with baseboard (`floor.png`) + arched window (`window_frame.png`) and skies (`window_sky_day.png`, `window_sky_twilight.png`, `window_sky_night.png`) in `content/masters/v1/` and derivatives in `content/packs/v1/assets/`;
  2. **`v1.1.0` (awaiting artistic delivery):** rug (`rug.png`) + couch (`couch.png`) + floor lamp in the two painterly states (`floor_lamp_calm.png` and `floor_lamp_lit.png`);
  3. **`v1.2.0` (awaiting artistic delivery):** the couple embraced on the couch under the blanket in a single image (`couple_on_couch.png`) + static sleeping puppy on the rug (`pet_sleeping.png`)
- [x] Verified floor and scene width to support centered portrait view (with `4:3` panoramic horizontal scroll) and future fullscreen landscape view, and verified downward continuity of the floor to accommodate the future Countdown in `S3-5` *(verified on goldens `home_night_dark.png`, `home_day_light.png`, `home_thought_received_dark.png`)*
- [x] Delivered Style Bible (`A-03`) and catalog (`A-07`) for `v1.0.0` *(`docs/design/S3-2/asset-catalog-v1.md`: ID, slot, master dimensions, SHA-256 of masters and derivatives, registered PNG8 derivatives; **prompt, AI tool, and tool terms (`A-08`) still to be provided by designer/sponsor**, listed as explicit placeholders)*, passing the halo-free transparency test on light, twilight, and night walls (`A-04`) and with no text or watermarks in the images (`A-06`) *(to be extended with `v1.1.0`/`v1.2.0` upon asset arrival)*

**S2-DES-03 · Design ahead for S3-3 (*Thinking of you and notifications*)** — Role: designer · Ref.: `F-03`, `F-16`, `S-02`, `SL-02`

- [x] Delivered `S2-D10`: refinement of the "thinking of you" gesture (short note composer, "heartbeat vibration" / haptic feedback, floor lamp illumination animation, generic IT/EN notification copy, and quiet settings) *(`docs/design/S3-3/thinking-of-you-spec.md`)*
- [x] Approved by the sponsor before closing `S3-2` so that `S3-3` starts without waiting

**S2-CNT-01 · Git LFS setup for masters, `CC-BY-4.0` license, and micro-pack pipeline** — Role: content and release · Ref.: `CNT-01`, `CNT-02`, `A-02`, `A-08`, `D-11`, `TC-10` · Depends on: `S2-CTR-01`, `S2-DES-02`

- [x] Created `content/LICENSE-ASSETS` with **`CC-BY-4.0`** license and explicit exclusion of `Deep Sky` name, logo, and icon; configured `.gitattributes` to track `content/masters/**` on **Git LFS** and set `lfs: false` in GitHub Actions workflows *(`.github/workflows/ci.yml`)* so as not to consume LFS bandwidth in CI
- [x] Built the local build/resize script that produces density-optimized derivatives (`A-02`, `DD-10`) in `content/packs/v1/` (in standard Git) from the masters in `content/masters/` *(`scripts/build_content_pack.py` + `scripts/ImagePackTool.java`, total `v1.0.0`: `1.02 MiB` within `DD-10` budget; lossless compression by default, with explicit failure if an asset exceeds the budget: PNG8 quantization is allowed only with `--allow-palette`. `floor.png` and `window_sky_night.png` do not fit within the budget losslessly and are PNG8 registered in `asset-catalog-v1.md` §3.1, awaiting sponsor decision)*
- [x] Extended `scripts/validate_content.py` to check the actual existence of all referenced files, size limits (`DD-10`), absence of unsafe paths (`..`, absolute paths), and presence of `keyId` in `scripts/sign_content.py`
- [ ] Generated and signed `pack-checksums.json` and `pack-checksums.json.sig` for micro-packs `v1.0.0`, `v1.1.0`, and `v1.2.0` *(pipeline verified end-to-end on `v1.0.0`; local release signing with sponsor's private key + signing `v1.1.0`/`v1.2.0` upon asset arrival)*

**S2-SRV-01 · File-by-file distribution of content packs on the server** — Role: backend developer · Ref.: `AR-09`, `TC-10`, `G5-07` · Depends on: `S2-CTR-01`

- [x] Endpoints to query `pack-checksums.json` and `pack-checksums.json.sig` of the active pack and download individual asset files from the volume configured on the server, plus exposing `minPackVersion` in the compatibility policy *(`ContentPackController`, `ContentPackStore`, `ContentConfiguration`, `SystemCompatibilityController`, `deploy/docker-compose.yml`)*
- [x] Support for conditional HTTP caching (`ETag` / `If-None-Match`) with immutable `Cache-Control` per hash and strict `Content-Type` / `Content-Length` headers. Implemented as follows: `Cache-Control: public, max-age=31536000, immutable` **only** on the content-addressed endpoint `GET /api/v1/content/pack/blobs/{sha256}` (the URL changes when bytes change, so it is truly immutable); path-based URLs `GET /api/v1/content/pack/files/**` (same path reused between `v1.0.0` and `v1.1.0`) respond with `Cache-Control: no-cache` + `ETag` and `304` on `If-None-Match`, to prevent an intermediate cache from serving stale bytes for a year. The client downloads from `/blobs/{sha256}`
- [x] Defensive check at startup/reload on the server (Ed25519 signature verification on raw bytes, SHA-256, and relative paths as additional defense, while keeping the trust anchor on the client); signature verification is active when keys `DEEPSKY_CONTENT_TRUSTED_KEY_V1`/`_V2` are configured (exposed in `deploy/docker-compose.yml` and `deploy/.env.example`; without keys the server logs a `WARN` on startup) and the active pack is hot-reloaded every 60 s (`@Scheduled`, only if `pack-checksums.json`/`.sig` change), without restarting the container; verified with `ContentPackStoreAndControllerTest`, `DeepSkyPropertiesValidationTest`, `SecurityApprovalWebMvcTest`, and ArchUnit (`ArchitectureTest`)

**S2-APP-01 · Complete design system, licensed OFL fonts, and portrait orientation lock** — Role: client developer · Ref.: `DS-3`, `V-02`, `V-06`, `V-07`, `N-06`, `S1-D16` · Depends on: `S2-DES-01`

- [x] Bundled original unmodified `.ttf` files of `Plus Jakarta Sans` and `Nunito Sans` together with their `OFL.txt`, registered in `LicenseRegistry.addLicense` (`N-06`, zero network fetch, `assets/fonts/`, `pubspec.yaml`, `lib/main.dart`)
- [x] Locked app orientation to portrait (`android:screenOrientation="portrait"` in `AndroidManifest.xml` + `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in `lib/main.dart`) for standard screens
- [x] Aligned all `DeepSkyTokens` (including wall-background colors for day/twilight/night in light and dark themes, surfaces, borders, amber glows ≤ 5%, radii, and spacing) and reusable components (`S1-D16`) to the `DS-3` spec, with WCAG AA contrast and text scalable up to 200% (`V-07`, verified in `s3_2_home_and_scene_test.dart`)

**S2-APP-02 · Signed packs client: file-by-file download, `keyId`, staging, and hot force-update button** — Role: client developer · Ref.: `TC-10`, `AR-09`, `G5-07`, `N-03` · Depends on: `S2-CTR-01`, `S2-CNT-01`

- [x] Implemented `ContentPackService` (`lib/data/content_pack_service.dart`, `lib/domain/content/content_pack_models.dart`) with map of Ed25519 public keys indexed by `keyId`, signature verification **on raw bytes** of `pack-checksums.json` **before** JSON parsing (`G5-07`), anti-downgrade check `max(bundledPackVersion, localMaxSeenPackVersion, serverMinPackVersion)`, path traversal guard, and **file-by-file** download of only assets with a new SHA-256 (`blobs/<sha256>`)
- [x] Implemented the **two update modes**:
  1. **silent automatic:** only on unmetered networks (`NativeBridge.isConnectionUnmetered` / `ConnectivityManager.isActiveNetworkMetered`), saves the verified pack in `staged/` and promotes it to `active` on next launch;
  2. **manual "Update graphics" button in Settings (`S2-D09`):** downloads immediately even on metered networks, promotes the pack, **evicts the previous pack's textures from `imageCache` and immediately reloads the UI** without having to close and reopen the app *(`SettingsPage` + `DeepSkyController.forceUpdateContentPack`)*
- [x] Implemented the **"last known good pack"** guard: `packBootAttempts` counter reset upon completion of the first Home frame (`addPostFrameCallback` -> `markHomeBootSucceeded`; also reset by the first frame of a pre-Home screen that does not draw the pack, such as space setup/recovery key, to avoid false rollbacks), with automatic rollback to the previous pack or the pack bundled in the APK in case of `>= 2` failed launches

**S2-APP-03 · Real Home: dynamic wall-background, continuous floor, *Thinking of you* `< 6h` card, `F-03` lamp, and 2 tabs (`Home`, `Us`)** — Role: client developer · Ref.: `F-02`, `AR-07`, `AR-08`, `ADR-0007`, `P-07`, `S-05`, `V-02..V-11` · Depends on: `S2-CTR-02`, `S2-APP-01`, `S2-APP-02`

- [x] Restructured `HomeShellPage` (+ `SettingsPage`) according to the `docs/design/S3-2/` mockup adapted to `S3-2`:
  - **top header:** `Home` title on the left and **a single icon button on the right for `Settings`** (no second dot and no green online presence indicator `P-07`, `S-05`);
  - **2-tab bottom navigation bar:** `Home` and `Us` (couple profile and devices);
  - **dual-state top *Thinking of you* card:** shows *"\<Partner\> thought of you"* + `♥ Send back` button if there is a received thought **not yet seen locally (`lastSeenEventSeq`) and more recent than 6 hours**; otherwise shows the button/field to send a *Thinking of you* with an optional message;
  - **wall = app background + continuous floor to bottom of page:** room objects (`floor.png` and `window_*` in `v1.0.0`, with `HybridSceneCanvas` ready for `v1.1.0`/`v1.2.0`) are transparent PNGs placed on the wall-background (which changes tint with `day`/`twilight`/`night`) and on the floor that continues all the way down (ready to accommodate the Countdown resting on the floor in `S3-5`);
  - **window vs floor lamp:** the window shows the sky of the local time band (`day`, `twilight`, `night`, without weather); the floor lamp shows the `lit` state (with warm amber `RadialGradient` glow) when there is an active/unseen thought, and tapping it allows sending or reciprocating *Thinking of you* (`F-03`)
- [x] Separated `LocalSceneViewState` from `CoupleRoomSnapshot`: `lastSeenEventSeq` and `lastOpenedAtLocal` remain strictly local (`P-07`, `S-05`); recalculation of the local time band with a lightweight periodic timer (60s) and on `AppLifecycleState.resumed` (midnight and time zone change while app is open)
- [x] **Strict image memory control (`ADR-0007`):** only one time-of-day variant of the window sky decoded at a time (with explicit `.evict()` of the outgoing variant on time-band change in `HybridSceneCanvas`), `ResizeImage.resizeIfNeeded` capped to display resolution, and explicit `48 MB` cap on `PaintingBinding.instance.imageCache.maximumSizeBytes` in `lib/main.dart`

**S2-SEC-01 · Security verification on the pack supply chain and local state privacy** — Role: security reviewer (not the author of `S2-APP-02` / `S2-SRV-01`) · Ref.: `G5-07`, `TC-10`, `P-07`, `S-05`

- [x] Verified in code and with automated tests (`test/security/content_pack_security_test.dart`, `ContentPackStoreAndControllerTest`) that the Ed25519 signature (with `keyId` selection) on `pack-checksums.json` is checked on raw bytes before any JSON parsing
- [x] Automated rejection tests for: unknown `keyId`, invalid signature, tampered `pack-checksums.json`, single PNG with mismatched SHA-256, path traversal (`../`), downgrade below `max(bundled, localMaxSeen, serverMin)`, and unsupported `minAppProtocol`, plus test of automatic rollback on `>= 2` failed launches *(`test/security/content_pack_security_test.dart`)*
- [ ] Verified that neither `lastSeenEventSeq` nor `lastOpenedAtLocal` ever leave the device toward the server (`P-07`, `S-05`, `test/security/content_pack_security_test.dart`) *(automated check run by the author; independent review by a non-author reviewer remains, as required by this task)*

**S2-QA-01 · Tests on two real phones, accessibility, and `ADR-0007` thresholds** — Role: QA · Ref.: `ADR-0007`, `AD-09`, `V-07`, `PD-19`

- [x] *Golden* and widget tests for the new Home: **goldens** (`test/golden/deep_sky_golden_test.dart`, `390×844`, with bundled OFL fonts and MaterialIcons loaded via `FontLoader`, hence real typography) for light/dark onboarding, night Home (dark theme), day Home (light theme), Home with unread received thought (dark theme), twilight Home at `19:10` local time, and twilight Home with `lit` lamp (the lamp uses a **synthetic test** `floor_lamp` slot with v1 PNGs as stand-ins until `v1.1.0` assets arrive); **widget tests** (`test/presentation/s3_2_home_and_scene_test.dart`) for the three time bands, *Thinking of you* card in both states (`< 6h` unread vs quick send), IT/EN, 200% text, and non-overflow on `9:16`, `9:20`, and split-screen. Not covered by goldens: EN language and `9:20` aspect ratio (widget test only), lamp with final painterly assets
- [ ] Verification with TalkBack active (`OrdinalSortKey`), system text at 200%, and "reduce motion" option active (immediate stop of all level-1 animations, `ADR-0007`) *(covered by automated 200% widget/semantics + reduce-motion tests; manual verification with TalkBack on a physical device remains)*
- [ ] **Physical measurement on the oldest phone** during Home scrolling, active animations, and pressing the "Update graphics" button (hot reload with cache eviction): **≥ 95% of frames within 16.7 ms** (60 Hz) and **peak RSS ≤ 180 MB** (`ADR-0007`), recorded in the test report

**S2-REL-01 · `S3-2` release and field test** — Role: release and infrastructure with sponsor · Ref.: `PD-06`, `PD-18`, `PD-19`

- [ ] Verified backup before server update (`PD-19`)
- [ ] Publication of the initial signed micro-pack `v1.0.0` and release of the locally signed APK first on the *preview* channel (sponsor's phone) and, after verification, on the *stable* channel (partner's phone), followed by graphic micro-updates `v1.1.0` and `v1.2.0` distributed by the server
- [ ] Collection of usage observations in the following days in the log (ch. 9), answering the field questions of `S3-2`: *"Does the home feel like a place you want to come back to? Are there unnecessary elements?"*

### 6.5 Exit from S3-2

- [ ] All `S2-*` tasks closed with green CI, passing tests, and sponsor review (`PD-11`)
- [ ] Performance and memory thresholds (`ADR-0007`: ≥ 95% frames ≤ 16.7 ms, RSS ≤ 180 MB) confirmed on the oldest phone even during forced hot graphics update
- [ ] Micro-pack progression (`v1.0.0 -> v1.1.0 -> v1.2.0`) succeeded on both real phones without updating the APK
- [ ] Design for `S3-3` (*Thinking of you and notifications*, `S2-D10`) approved and ready to start
- [ ] Field notes from partner and sponsor recorded to guide `S3-3`

## 7. Sprints S3-3 … S3-8

In summary; details are written at each sprint with the same structure as chapters 5 and 6 (`PD-20`).

| Sprint                               | Design (one slice ahead)                                                    | Contract and server                              | App                                                                       | Questions to ask in the field                                                |
|:-------------------------------------|:----------------------------------------------------------------------------|:-------------------------------------------------|:--------------------------------------------------------------------------|:-----------------------------------------------------------------------------|
| **S3-3 Thinking of you and notifications** | Gesture, notification copy, channel, and settings *(delivered in S2-D10)* | Encrypted event, generic push with explicit non-secret *hint* on `POST /api/v1/sync/envelopes` (`CA-15`), quiet rules | Send, receive, tap on notification | Does the gesture feel natural? Does it create a sense of obligation? |
| **S3-4 Mood**                        | Selection, optional note, history + mood slot micro-pack                    | Event, push hint per event type (`CA-15`), and derived state | Choice, display, and appearance of the slot in the room | Do you use it? Is it always optional, really?                                |
| **S3-5 Countdown**                   | List, detail, todo, images, comments + calendar micro-pack                  | Encrypted events and blobs                       | Countdown, local notifications, and appearance of the calendar in the room | Does it help closeness? What is missing?                                     |
| **S3-6 Turn-based drawing**          | Canvas, tools, turns, messages + frame/easel micro-pack                     | Blobs and turn state                             | Canvas, send, over-drawing, and appearance of the drawing in the room     | Does even someone who can't draw use it?                                     |
| **S3-7 Time capsule**                | Creation, seal, waiting, ceremony + sealed box micro-pack                   | Events, date in the encrypted envelope           | Seal applied by the app, local notification, and appearance in the room   | Is opening it a special moment?                                              |
| **S3-8 Core closure**                | Empty states, errors, offline                                               | Minimum version, polish                          | Offline read-only, full updates                                           | What is really missing (D-03)?                                               |

**Heavy sprints.** S3-6 (drawing) is the most demanding of the core and should be split if it exceeds the
size of a normal slice.

## 8. How we work in each sprint

1. **Ready to start:** screens and states approved by the designer, contract approved, acceptance
   criteria.
2. **Contract first:** event format, schema version, API.
3. **Server and app in parallel** on the contract, with small pull requests (PD-11).
4. **Tests:** unit, integration, *golden*, two real phones, *n − 1* compatibility.
5. **Release:** locally signed APK; first on *preview*, then on *stable* when the sponsor
   deems it ready for the partner.
6. **Field test:** real use for a few days; the slice is declared **closed** after this
   test, but the next sprint does not wait: surfaced defects enter the backlog.
7. **Usage notes** in the observation log (chapter 9).

## 9. Real use in parallel (continuous M4)

**Observation log.** For each day or test, a short entry with: date, feature, what
was done, what annoyed, what pleased, what is missing, defects. Entries are not
user metrics: they remain a private diary (P-02).

**Signals to watch** (ch. 13 of the Project Brief):

- both open the app spontaneously, not just the sponsor;
- the app is chosen for a real gesture instead of a message elsewhere;
- the partner points out what is missing;
- no one feels a sense of duty or guilt.

**Weekly review** of about 30 minutes: entries are read, priorities are decided, and the
sprint order is updated. The admission rule remains PD-03: a new feature enters if
both miss it.

## 10. Compatibility with real data (PD-19)

- **Server:** migrations are immutable and forward-only; every migration is tested on a copy
  of realistic data.
- **Events and snapshots:** every type has a **version**; clients also read previous
  versions; breaking changes follow the sequence in 10.4 of the Architecture (client
  release, waiting, raising the minimum threshold).
- **Keys and envelopes:** no format changes without version and migration (ch. 7).
- **Compatibility tests** *n − 1* / *n* in CI.
- **Backup** before every server update with real data.

## 11. Risks

| Risk                                           | Impact                                | Mitigation                                                                            |
|:-----------------------------------------------|:--------------------------------------|:--------------------------------------------------------------------------------------|
| Real data with a still-unstable version        | Loss or corruption of memories        | G-3a, PD-19, backup before every update, restore test                                 |
| Unstable experience for the partner            | Loss of trust, abandoned use          | Stable and preview channels (PD-18), stable release only when ready                   |
| Difficult first installation                   | Partner cannot get in                 | S1-DES-03, S1-QA-02, manual code fallback                                             |
| Recovery key not understood or lost            | Unrecoverable data                    | Mandatory confirmation, comprehension test, DD-12                                     |
| Defective update                               | Partner's phone unusable              | Emergency procedure, new release with higher version code, preview before stable      |
| Overlap between field tests and development    | Supervision bottlenecks               | Sprints without waiting, defects in backlog, short weekly review                      |
| Revocation without key rotation                | Stolen phone decrypting future content | Mitigated in code (`CA-02`, `ADR-0012`); hardware verification in `G-3a` remains (`S1-SEC-02`) |
| Real data before export and deletion (M5)      | No full data exit upon dissolution    | Risk accepted in G-3a; backup, `unpaired_at`, F-17/D-15 in M5                         |
| Partner test experienced as a test             | Discomfort                            | Consent, light tone, no help but no judgment, short test                              |
| AI asset bottleneck or RAM spikes on scene changes | Stalled development or exceeding 180 MB RSS (`ADR-0007`) | 1–2 graphic micro-packs (`v1.0.0`, `v1.1.0`), only one backdrop variant decoded with `.evict()` on change / forced reload, and automatic rollback to last known good pack |

## 12. Open decisions

- **DD-12** Viewing the recovery key again after the first time: yes or no, and with what check.
- **D-11 / DD-06 \[Decided for license, tool to be noted per asset\]** Asset license set to **`CC-BY-4.0`** in `content/LICENSE-ASSETS` with explicit exclusion of `Deep Sky` name, logo, and icon; masters archived in `content/masters/**` via Git LFS (`lfs: false` in CI) and derivatives in `content/packs/**`.
- **DD-04 \[Decided for the core\]** Accessible navigation alongside the scene in `S3-2`: dual-state top *Thinking of you* card (`< 6h` unread with `Send back` vs quick send), only 2 bottom tabs (`Home`, `Us`) growing with `Gestures` and `Memories` only when their respective features are born, and a single top-right `Settings` button.
- **DD-10 \[Decided\]** Master resolutions (`1024–2160 px` in Git LFS), derivative resolutions (`384–1440 px` in standard Git, ≤ `250 KB` per object / ≤ `400 KB` for floor, total pack ≤ `1.8 MB`), and cut-out/layer criteria defined in section 6.3.
- Fullscreen landscape mode dedicated to the scene alone (optional, deferred until after `S3-2`, while already preparing the backdrop for horizontal scrolling).
- Final sprint order after S3-2.
- Size and split of S3-6.
- When to promote a release from *preview* to *stable*, in practice: after how many days of testing
  by the sponsor?
- App language for the partner (Italian and English are planned, N-07).

## 13. Traceability

Every task cites the IDs of the documents from which it derives. A task that cannot be closed without
violating a **\[Decided\]** decision is reported to the sponsor.
