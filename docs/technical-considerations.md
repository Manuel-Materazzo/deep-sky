# Technical Considerations: Deep Sky

**Version:** 0.1 (draft for review) · **Date:** November 12, 2026 · **Depends on:** Project Brief v0.2, Design Brief v0.2

**Audience:** architect agent, and subsequently the developer agents. This document collects the technical decisions made together with the promoter, their rationale, and still-open questions. It is the input to the architecture document, which must not reopen them without flagging it.

**Conventions.** **\[Decided\]** confirmed by the promoter. **\[Proposal\]** recommendation not yet validated, to be confirmed with a prototype. **\[Open\]** question to be resolved. The IDs in this document are **TC-xx** (decisions), **SP-xx** (verification prototypes), and **AD-xx** (questions for the architect). IDs P-xx, F-xx, S-xx, N-xx, D-xx refer to the Project Brief.

---

## 1. Starting Context

- Initial users: the promoter and his partner, **both on Android**. No Mac available, no Apple account for now.
- Initial server: an **Oracle Cloud (OCI) VM with an ARM Ampere CPU**, with existing backup scripts to extend to this application.
- Distribution: **no Play Store or App Store for now**. The app is installed as an APK.
- Release goal: no real deadline. Features are built together, little by little, starting primarily from the graphics.
- Anyone hosting their own instance (self-hosting) must be able to do without a project-managed service, within the limits stated in this document.

## 2. Decisions Made

| ID | Decision | Status |
| :-- | :-- | :-- |
| **TC-01** | Client app in **Flutter** | Decided |
| **TC-02** | Backend in **Java with Spring Boot** and **PostgreSQL** | Decided |
| **TC-03** | Everything in **Docker Compose**; **multi-architecture ARM64 and AMD64** backend images | Decided |
| **TC-04** | **Android only** for now; iOS deferred | Decided |
| **TC-05** | **End-to-end encryption from v1**; derived state is computed by one device, encrypted, and uploaded to the server | Decided |
| **TC-06** | Recovery: **key re-sending between the two phones** plus a **recovery key** to save | Decided |
| **TC-07** | **Read-only** when the app is offline | Decided |
| **TC-08** | **Data-driven** scene: manifest plus layered image slots | Decided |
| **TC-09** | Animation: **level 1** with multiple overlapping layers per slot; **level 3** (skeletal or part-based) as the final goal | Decided |
| **TC-10** | **Integrated updates from v1**, in two tiers: content packs and APKs from **GitHub releases** | Decided |
| **TC-11** | Backup: extension of existing scripts on the OCI VM | Decided |
| **TC-12** | **Vertical-slice** development (graphics, code, and assets together) with frequent releases | Decided |
| **TC-13** | Push with **FCM** and Firebase credentials provided at runtime by the server | Validated by SP-01 on real hardware (ADR-0006) |

## 3. Stack and Rationale

### 3.1 Client: Flutter (TC-01)

The interface is illustrated (scene, drawing canvas, animations) and a single rendering engine ensures the design system looks identical across all devices. What remains outside the framework:

- **home screen widgets** (F-13) require native Android code (Kotlin), to be integrated with the Flutter project;
- APK installation (TC-10) requires a native channel to system APIs;
- notifications and any runtime Firebase initialization (TC-13) have native parts.

### 3.2 Backend: Spring Boot and PostgreSQL (TC-02)

The choice is the promoter's and is based on expertise, a mature ecosystem (security, migrations, testing, service health), and Postgres, already covered by existing backup scripts. The evaluated alternative (Go with SQLite) offered a smaller footprint for self-hosters, but not technical superiority. Measures to adopt:

- **explicit JVM and Postgres memory limits** in compose, chosen according to VM resources;
- **measured actual consumption** (SP-05) to declare minimum self-hosting requirements rather than estimating them;
- versioned schema migrations and service health checks in compose;
- the backend is **thin**: it authenticates, stores encrypted blobs and state, routes, and triggers push. It does not see content (TC-05).

### 3.3 Docker and Architectures (TC-03)

Everything runs with Docker Compose. The backend must be built for **ARM64** (OCI VM) and **AMD64** (other self-hosters). The build pipeline produces multi-architecture images. The compose layout, networking, and Internet exposure are delegated to the architect (AD-04).

## 4. Push Notifications (TC-13)

### 4.1 What Kehai Does

The Kehai project, which we explored, **does not use Firebase**. Its repository shows this architecture:

- a self-hosted **ntfy** server with **UnifiedPush** for push;
- a Flutter client that, in addition to the ntfy app installed as a "distributor", keeps a **foreground service** with a persistent notification and a realtime WebSocket connection to the server;
- networking designed for **Tailscale**, with no exposed ports.

Pros: no Google dependency, no Firebase project to create. Costs: a **second app** to install and configure (for ntfy), persistent connections that OEM battery-saving systems can kill, and a **persistent notification** that conflicts with P-02 and V-08 (no pressure, no element demanding attention). For the non-technical partner (P-09) the configuration burden is high.

### 4.2 Proposal: FCM with Runtime Configuration

**\[Proposal\]** FCM remains the primary channel on Android: it is battery-efficient because it leverages the connection already maintained by Google, and it does not require a second app. The initial objection was that Firebase credentials are tied to the build. In reality, the SDK can be initialized **at runtime** with parameters (project ID, API key, app ID, sender ID) that the app receives from the self-hoster's **server** at pairing time. Consequences:

- **a single official APK for everyone**, without every self-hoster having to compile their own app;
- the self-hoster creates a Firebase project and enters the client parameters and service key for sending into the server configuration;
- no project-managed relay, as long as we stay on Android.

Point to verify (**SP-01**): Firebase initialization when the process is woken up by a push while the app is closed, which must be able to happen before the message arrives (parameters saved locally and applied at process startup).

### 4.3 Notification Content

Consistent with S-02, the push carries no content: it is a "wake-up" with a localization key, and the generic text is composed by the phone ("You have a thought waiting"). The content arrives afterward, synced and encrypted. Richer notifications are deferred and would require local decryption.

### 4.4 Alternatives and Future

UnifiedPush remains an option for phones without Google services, as a future optional feature. With iOS, a paid developer account and a project-managed relay would become necessary again.

## 5. The Scene (TC-08, TC-09)

No game engine is needed. The scene is a composition of layered images, described by a **manifest** delivered by the designer.

- **Slots:** each object has an ID, position in normalized coordinates, size, stacking order, **touch area** defined in the manifest (not derived from transparent pixels), states (e.g. light off and on), and accessibility labels.
- **Customization (F-18):** replaces only the file linked to a slot; the manifest does not change.
- **Screen aspect ratios:** fixed-aspect-ratio scene area with a backdrop that bleeds beyond the edges (bleed).
- **Memory:** images decoded at display resolution; multi-density derivatives produced by the pipeline (A-02 of the Design Brief).
- **Level 1 animation (TC-09):** transforms, opacity, and fades on layers, with multiple overlapping layers per slot (shadows, lights, particles, accessories). The manifest describes animation type, duration, curve, and repeat behavior per slot.
- **Final goal, level 3:** 2D skeletal or part-based animation. Tool and format are not chosen yet (DD-11); it is not ruled out that an agent could produce it in a suitable format. The scene architecture must not make the transition difficult: animations are data in the manifest, not hardcoded logic.
- **Pet reactions:** derived state (what the pet shows based on activities) is computed by **one device** and uploaded encrypted (TC-05), not deterministically recomputed on both phones, because the two apps may be on different versions.

## 6. Encryption and Sync (TC-05, TC-06)

### 6.1 Model

- The server stores **only encrypted data** and minimal metadata. It inevitably sees: the existence and technical identity of accounts or devices, timestamps, data sizes, push tokens.
- **Events** (gestures, drawings, moods, photos) form the shared log, the source of truth.
- The **snapshot** of derived state is a rebuildable cache, computed by the device generating the event, encrypted, and uploaded.
- The snapshot has a **schema version**. On concurrent writes, **optimistic concurrency** applies: if the server already has a newer version, the device recomputes and retries.

### 6.2 Pairing and Recovery

- Keys are born and stay on the devices; exchange happens at pairing (invite via link or QR, F-01).
- **New phone:** the other phone re-sends the keys to the new device (F-20).
- **Recovery key:** generated at pairing; the app requires **confirmation that it has been saved**.
- Guarantee stated to the user: data is recoverable **as long as the other phone or the saved key exists**. Server-side key escrow (encrypted with a passphrase) has been **rejected** for now.
- **Losing the APK signing key** prevents updating existing installations: it forces a reinstall and loss of local keys. Another reason why the recovery key is mandatory, and why the signing key must be carefully safeguarded and backed up (AD-08).

### 6.3 Choices Delegated to the Architect

Cryptographic primitives, key-exchange protocol, device authentication model, and key management are delegated to the architecture document (AD-01, AD-02). The document must cite mature, well-maintained libraries—not ad-hoc cryptography—and provide for an independent review before making the privacy promise (P-06).

## 7. Offline and Cache (TC-07)

Without a connection, the app is **read-only**: scene and memories can be browsed from a **local cache**; write actions are disabled with a gentle message (P-02, V-08). There is no sync queue and no offline conflicts to manage. Protection of the local cache (encryption at rest, use of the system keystore) is delegated to the architect (AD-06).

## 8. Integrated Updates (TC-10)

The app has two complementary mechanisms from v1.

### 8.1 Tier 1: Content Packs

Assets, scene manifest, and texts are downloaded from the server, **verified** (hash and signature), and applied **without installing anything**. This allows graphics to evolve little by little without new APK releases. They contain no executable code.

### 8.2 Tier 2: APKs from GitHub Releases

- The app checks the project's **GitHub releases** (configurable source, for anyone using a fork or their own channel). The release contains the APK and a **manifest** with version, SHA-256 hash, and signature.
- Before installation, the app verifies the manifest's hash and signature with an **embedded public key**, in addition to Android's check, which accepts the update only if signed with the same key as the installed app.
- The required permission is the per-app "**Install unknown apps**" permission (not developer settings), granted once; installation goes through Android's **PackageInstaller**, with system confirmation. How much confirmation can be reduced on subsequent updates depends on the Android version and must be verified (SP-03), without promising it to users.
- The server can enforce a **minimum client and protocol version**: if an app is too old, it shows an "update required" screen (F-19). This is primarily for compatibility of encrypted snapshots (6.1).
- A similar precedent exists in Kehai: release APK, install permission, user confirmation on the system screen, and signing with the project key for an in-place update that preserves data.
- To evaluate: GitHub request rate limits (conditional checks, not checking on every launch).

### 8.3 Android Developer Verification (D-14)

Google is introducing **developer identity verification** even for apps installed outside the Play Store. According to its announcements, enforcement began on September 30, 2026 in Brazil, Indonesia, Singapore, and Thailand and is planned globally starting in 2027; those who do not complete verification may face limits on installs and updates. There is a **limited-distribution account** (up to 20 devices, no ID document or fee) for hobbyists and an **advanced flow** to install apps from unverified developers. For us:

- two-person dogfooding fits within the limited-distribution account;
- a **publicly distributed official APK** will likely require full verification (beyond 20 devices) when the rule reaches Italy;
- **package name and signing key must remain stable** from the very first build;
- the status of the rules must be rechecked before any decision on public distribution.

## 9. Deployment and Operations

- Services in compose: backend, PostgreSQL, and optionally a reverse proxy with TLS (AD-04).
- Persistent data: database and encrypted blobs (images) on a volume, included in the **backup** extended from existing scripts. With end-to-end encryption, backups contain only encrypted data: without the partners' keys they are unreadable. The restore process must be tested, not just backup creation.
- Self-hoster configuration: Firebase parameters (TC-13), server secrets, update source (8.2).
- Build pipeline: multi-architecture images, signed APK, release publishing with signed manifest.
- A single official APK for everyone, thanks to runtime configuration (TC-13). Anyone who wants to compile their own version can do so, but it is not a requirement for self-hosting.

## 10. Verification Prototypes

Before locking down the architecture, it is best to verify uncertain points with small, throwaway prototypes.

| ID | Prototype | Question It Answers |
| :-- | :-- | :-- |
| **SP-01** | FCM notification with runtime initialization, app closed, on two real Android phones | Is the configuration received from the server enough to receive pushes even when the process is closed? |
| **SP-02** | Pairing with key exchange, recovery key, and new device | Is the recovery flow understandable and secure? What metadata does the server see? |
| **SP-03** | APK update from GitHub release with hash and signature verification | How much interaction does Android ask for? What happens with a different key or tampered manifest? |
| **SP-04** | Scene with two slots, one animated layer, and one asset replacement, on real phones | Performance, memory, different aspect ratios, touch areas |
| **SP-05** | Spring Boot plus PostgreSQL on the ARM VM, with memory limits | Actual consumption and declarable minimum requirements |

## 11. Technical Risks

Table updated at the exit of milestone **M1 (`G-1`)**; for complete architectural countermeasures and the **`G-5`** review list, see the [Architecture Document v0.2](architecture.md) and the [ADRs](adr/README.md).

| Risk | Impact | Mitigation | Post-M1 Status (`G-1`) |
| :-- | :-- | :-- | :-- |
| Unreliable runtime FCM initialization when process is closed | Pushes not delivered | SP-01; `PushProvider` interface (AR-10) for possible switch to UnifiedPush / dedicated build | **Mitigated:** delivery verified on real hardware with app open, in background, swiped from task switcher, after reboot, and in Doze (`ADR-0006`, AR-10 frozen); Plan B not activated |
| Errors in end-to-end encryption or recovery | Data loss or false privacy promise | Mature libraries (`cryptography`, `bip39_mnemonic`), SP-02, independent review (`G-5`) | **Mitigating:** protocol implemented and tested (`ADR-0005`); physical-phone / non-technical user checks and post-revocation rotation planned between M2 and `G-5` |
| Loss of APK signing key | Unable to update, reinstall and loss of local keys | Offline custody and encrypted backup (`PD-10`, `docs/key-custody.md`), mandatory recovery key, pre-session guard on `PackageInstaller` | **Mitigated:** offline flow documented (`M0`); pre-install certificate guard validated in `proto/sp-03` (`ADR-0008`); physical-device check of the signed upgrade flow remains |
| Android developer verification extended to Italy | Public official APK blocked or hindered | D-14, stable package name `com.vectevo.deep_sky` (`PD-07`) and key, rule monitoring | **Monitored:** dogfooding compatible with limited tier (`<= 20` devices); to be reassessed before public openings |
| Incompatibility between different app versions on the two phones | Unreadable encrypted state | `schemaVersion` on snapshots and envelopes, server-side minimum version enforcement (`F-19`), `versionCode` check in `SP-03` | **Mitigating:** minimum version and anti-downgrade designed in `SP-02`/`SP-03`; full end-to-end enforcement to be integrated in M2 (`SL` / `F-19`) |
| Memory and performance with many AI images | Slow or unstable app | Per-density derivatives, decoding at display size, isolated layers (`RepaintBoundary`), and reduce motion (`SP-04`) | **Closed in M1 (watch on final assets):** thresholds, accessibility, and designer validation passed in `proto/sp-04` (`ADR-0007`) |
| JVM consumption on small VMs | Expensive self-hosting for others | Explicit JVM/PostgreSQL limits in Compose, reproducible `SP-05` benchmark, declared minimum requirements | **Closed in M1:** memory profiles, OOM-free stability, and minimum requirements validated by the promoter (`ADR-0009`); benchmark profiles excluded from `prod` profile |

## 12. Questions for the Architect

The architecture document must answer at least these questions, listing alternatives with pros and cons.

| ID | Question |
| :-- | :-- |
| **AD-01** | Cryptographic primitives and protocol, and key-exchange model at pairing |
| **AD-02** | Device and session authentication, without public accounts |
| **AD-03** | Data model: event log, snapshots, blobs; transport (HTTP requests plus realtime channel) |
| **AD-04** | Network exposure (D-13): public HTTPS behind a reverse proxy or private network |
| **AD-05** | Does one server host **a single couple** or **multiple couples**? Impacts data isolation, quotas, and security |
| **AD-06** | Encrypted local cache and use of the system keystore |
| **AD-07** | Blob (image) storage and backup sizing |
| **AD-08** | Custody of the APK signing key and the update manifest signing key |
| **AD-09** | Testing strategy (unit, integration with real database, end-to-end on devices, security) |
| **AD-10** | Minimal observability without telemetry that violates S-07 |

## 13. Next Steps

1. Architecture document, starting from this document, the Project Brief, and the Design Brief.
2. Execution of prototypes SP-01 and SP-02, the riskiest ones, before locking down details.
3. Definition of interfaces between scene manifest, content packs, and design system, in agreement with the designer.
4. Vertical-slice development plan (TC-12).

## 14. Traceability

Every subsequent document cites the IDs from this document (TC-xx, SP-xx, AD-xx) and from the Project Brief and Design Brief from which it derives. In case of conflict with a **\[Decided\]** decision, the conflict must be flagged to the promoter rather than resolved autonomously.
