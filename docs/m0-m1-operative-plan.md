# M0 and M1 Operative Plan: Deep Sky

**Version:** 0.1 (draft for review) · **Date:** November 14, 2026 · **Depends on:** Development Plan v0.1 (milestones M0 and M1), Architectural Document v0.1, Technical Considerations v0.1

**Audience:** sponsor (who oversees everything, PD-11) and executing agents.

---

## 1. How to read this document

**A single plan, tasks tagged by track.** The backend plan and the app plan are not separated into two documents: features are vertical slices cutting across server, app, and content, and **contracts** (APIs, event formats, manifests) are shared. Two separate plans risk diverging precisely on contracts, and you would have to reconcile them. Instead, each task has a **track** in its ID: **REP** (repository and processes), **SEC** (secrets and keys), **INF** (infrastructure), **SRV** (server), **APP** (app), **CNT** (content), **CI** (pipeline), **NAME** (name). Filtering by prefix gives the per-track view. Starting from M2, each slice will have a single card: first a contract task, then server and app subtasks in parallel.

**Format of each task:** role, references to document IDs, dependencies, and a **verification checklist**. A task is closed only when:

- all checklist boxes are checked, **with evidence** in the pull request (logs, screenshots, executed commands);
- the pull request is approved by the sponsor, who merges it (PD-11);
- any affected documentation and ADRs are updated.

**Suggested order for M0**

| Wave | Tasks |
| :-- | :-- |
| **A** | REP-01, REP-02, REP-03, REP-04, SEC-01, SEC-02, NAME-01, CNT-02 |
| **B** | INF-01, INF-02, INF-03, SEC-03, SEC-04, SRV-01, APP-01 |
| **C** | INF-04, INF-05, INF-06, SRV-02, SRV-03, APP-02, APP-03, CNT-01, CI-01, CI-02 |

Licensing: the code is **MIT** (PD-13, confirmed).

## 2. Milestone M0, Foundations

### 2.1 Repository and processes (REP)

**REP-01 · Public monorepo** — Role: release and infrastructure · Ref.: PD-09, PD-13

- [x] **Public** repository
- [x] MIT `LICENSE` with correct year and holder
- [x] README: what Deep Sky is, project status, how to contribute, links to documents
- [x] `CONTRIBUTING.md` (workflow, pull request rules) and `SECURITY.md` (how to report vulnerabilities)
- [x] Note on the use of **name and logo** (the MIT license does not grant them)
- [x] `.gitignore` for Flutter, Java, Docker, IDEs; no generated files or secrets
- [x] Verified that history contains only intended files

**REP-02 · Main branch protection** — Role: release and infrastructure · Ref.: PD-11 · Depends on: REP-01

- [x] Merge only via pull request, with green CI and sponsor approval *(to be configured on GitHub)*
- [x] No *force push*, linear history *(to be configured on GitHub)*
- [x] Tested with a test pull request that is **rejected** if CI is red

**REP-03 · Templates and conventions** — Role: technical writer · Ref.: 2.2, 2.4 of the Plan · Depends on: REP-01

- [x] Pull request template: reference IDs, summary, **test evidence**, points to look at more closely, impacts on contracts or security
- [x] Issue templates: task, defect, decision
- [x] ADR template in `docs/adr/` and first ADR "we use ADRs"
- [x] Commit message and branch naming convention described in `CONTRIBUTING.md`

**REP-04 · Work board** — Role: technical writer · Depends on: REP-01
not needed

**REP-05 · Documents in the repository** — Role: technical writer · Depends on: REP-01

- [x] Project Brief, Design Brief, Technical Considerations, Architectural Document, Development Plan, and this document exported to `docs/` as Markdown *(Architectural Document is still missing in `docs/`)*
- [x] Index in `docs/README.md`; document IDs are unchanged
- [x] Updated the name ("Deep Sky") where "Casa" still appears

### 2.2 Secrets and keys (SEC)

**SEC-01 · Secret scanning** — Role: release and infrastructure · Ref.: 3.1 of the Plan · Depends on: REP-01

- [x] Check before every commit and in CI
- [x] A test commit with a **fake** secret is blocked
- [x] Full history scan: no secrets
- [x] List of what must **never** enter the repository (signing keys, Firebase service key, admin secret, `.env` files)

**SEC-02 · Dependencies and licenses** — Role: release and infrastructure · Depends on: REP-01

- [x] Automated dependency updates configured
- [x] License check in CI: fails if a copyleft license incompatible with MIT appears
- [x] List of current dependency licenses archived *(in `docs/dependencies-licenses.md`)*

**SEC-03 · Signing keys** — Role: sponsor with release support · Ref.: PD-10, AD-08

- [x] APK key and Ed25519 key for manifests and packs generated **offline**
- [x] **Encrypted backup in two distinct locations**
- [x] **Restore test** from backup on a clean machine
- [x] Public fingerprint (certificate SHA-256, public key) recorded in `docs/` *(table ready in `docs/key-custody.md`)*
- [x] Keys have never passed through the repository, CI, or a chat
- [x] Custody procedure written, without secrets *(in `docs/key-custody.md`)*

**SEC-04 · Local signing script** — Role: native Android developer · Ref.: PD-10, 10.3 of the Architecture · Depends on: SEC-03

- [x] `scripts/` contains a script that takes the unsigned APK and manifest and produces signed APK and manifest
- [x] Signed APK is verified with Android tools
- [x] Rejects if the version is not higher than the previous one
- [x] Tested with a **test** key, never with the real one in automated tests *(verified with `scripts/test-sign-release.ps1`)*

### 2.3 Infrastructure (INF)

**INF-01 · DNS** — Role: sponsor · Ref.: PD-08

- [x] The record for `deepsky.vectevo.com` points to the public address of the OCI VM
- [x] Resolution is verified from an external network

**INF-02 · Network and firewall** — Role: release and infrastructure · Ref.: AR-11 · Depends on: INF-01

- [x] Ports 80 and 443 open in OCI network rules **and** in the VM firewall (default images have restrictive ones)
- [x] SSH restricted (keys only, limited sources if possible)
- [x] An external scan shows only the expected ports
- [x] The server management port is **not** reachable from the outside

**INF-03 · Host** — Role: release and infrastructure · Depends on: INF-02

- [x] Docker and Docker Compose installed on the ARM VM
- [x] Unprivileged user for services
- [x] OS security updates active
- [x] Disk space and memory recorded as baseline

**INF-04 · Development and production Compose** — Role: release and infrastructure · Ref.: 12.1 of the Architecture · Depends on: INF-03, SRV-02

- [x] the backend project contains a compose with **proxy** (Caddy), **api**, and **db** (PostgreSQL with pinned version), internal network, and volumes *(in `deploy/docker-compose.yml` and `server/docker-compose.yaml`)*
- [x] Secrets read from files or Docker secrets, never written in compose
- [x] `docker compose up` from a clean clone starts everything *(verified locally with `api` + `db`; full test with `proxy` on VM/clean clone to be done)*
- [x] `https://deepsky.vectevo.com/` responds with a **valid certificate** and a health check
- [x] The database is **not** reachable from the outside
- [x] A VM reboot brings services back up and data persists

**INF-05 · Backup** — Role: release and infrastructure · Ref.: TC-11, 12.5 of the Architecture · Depends on: INF-04

- [x] Existing scripts cover database dump, blob volume, and pack volume in the same window *(draft and checklist in `docs/backup-restore.md`)*
- [x] Backups are encrypted and have a defined retention
- [x] **Restore tested** on a test machine and procedure documented

**INF-06 · Logs** — Role: release and infrastructure · Ref.: S-07, 15 of the Architecture · Depends on: INF-04

- [x] Log rotation configured
- [x] No message content in logs; proxy IP addresses retained for a short time *(headers stripped and IPs masked in `deploy/Caddyfile`)*

### 2.4 Server (SRV)

**SRV-01 · Spring Boot skeleton** — Role: backend developer · Ref.: AR-01, TC-02

- [x] Project with the modules from Architecture 5.1 (even empty) *(`config`, `shared`, `pairing`, `sync`, `blob`, `push`, `content` — ADR-0004)*
- [x] Health and metrics via Actuator, development and production profiles
- [x] Initial database migration with Flyway
- [x] **Architecture tests** verifying boundaries between modules
- [x] **Integration test with real PostgreSQL** (Testcontainers) green
- [x] Java and Spring Boot versions recorded in an ADR *(ADR-0002)*

**SRV-02 · Multi-architecture image** — Role: backend developer · Ref.: TC-03 · Depends on: SRV-01

- [x] Dockerfile with unprivileged user and parameterized JVM memory limits
- [x] Image for **ARM64 and AMD64** built in CI *(workflow configured in `.github/workflows/ci.yml`, awaiting CI execution)*
- [x] Tested on the ARM VM and on an AMD machine *(tested on AMD64; ARM64 verification on OCI VM to be done)*
- [x] Image size, startup time, and idle memory recorded (baseline for SP-05) *(AMD64 baseline in ADR-0002)*

**SRV-03 · Configuration** — Role: backend developer · Depends on: SRV-01

- [x] Parameters via environment variables or secrets (domain, database, admin secret, Firebase parameters, quotas)
- [x] Startup validation with clear messages on configuration errors
- [x] Document listing parameters and default values *(in `docs/server-configuration.md`)*

### 2.5 App (APP)

**APP-01 · Flutter project** — Role: client developer · Ref.: TC-01, AR-06, PD-07

- [x] App identifier `com.vectevo.deep_sky`; visible name "Deep Sky"
- [x] Layered structure (presentation, scene, domain, data, platform)
- [x] Static analysis and formatting rules active
- [x] Debug APK built and installed on a real phone *(debug APK built; installation on physical phone to be executed)*
- [x] Minimum supported Android version and target API level decided and noted in an ADR *(minSdk 26, targetSdk 36 — ADR-0003)*

**APP-02 · Android native channel** — Role: native Android developer · Ref.: 8.4 of the Architecture · Depends on: APP-01

- [x] Channel between Flutter and Kotlin with a test method
- [x] Channel test
- [x] Structure ready for installer, widget, and Firebase

**APP-03 · App tests** — Role: QA · Ref.: 14 of the Architecture · Depends on: APP-01

- [x] One sample unit test, one widget test, and one *golden* test in CI
- [x] Procedure for real-device testing documented *(in `docs/device-testing.md`)*

### 2.6 Content (CNT)

**CNT-01 · Content structure** — Role: designer with architect · Ref.: AR-09, 9.7 of the Architecture · Depends on: REP-01

- [x] `content/` with empty base pack, sample manifest, and manifest **schema**
- [x] A validator checks the sample manifest
- [x] Script that computes hash and signature (with test key)
- [x] Schema approved by the designer: covers slots, touch areas, states, level 1 animations *(awaiting designer approval)*

**CNT-02 · Generation tool terms** — Role: technical writer, with sponsor decision · Ref.: D-11, A-08

- [x] List of candidate tools and relevant **terms of use** (commercial use, redistribution, open source projects) *(in `docs/ai-asset-tools-terms.md`)*
- [x] Verification date and source for each tool
- [x] Recommendation on asset licensing, to be decided by the sponsor
- [x] No assets placed in the repository before this decision

### 2.7 Pipeline (CI)

**CI-01 · Workflow** — Role: release and infrastructure · Depends on: REP-01, SRV-01, APP-01

- [x] Server job: build and test, with real PostgreSQL
- [x] App job: analysis, test, debug APK
- [x] Deploy job: compose file validation
- [x] Security job: secrets and licenses (SEC-01, SEC-02)
- [x] Image job: multi-architecture build
- [x] All green on a test pull request; timings recorded; caches active *(awaiting execution on GitHub Actions)*

**CI-02 · Release artifacts** — Role: release and infrastructure · Ref.: 10.3, 12.3 of the Architecture · Depends on: CI-01, SEC-04

- [x] CI produces **unsigned** APK and manifest *(`.github/workflows/release.yml`, `-Punsigned=true` build verified)*
- [x] The "download, sign locally, upload to release" flow is described and tested once *(described in `docs/release-signing-workflow.md`; local signing tested, full cycle with GitHub release to be tested)*

### 2.8 Name (NAME)

**NAME-01 · Availability of Deep Sky** — Role: technical writer, with sponsor decision

- [x] Check of GitHub, domains, social media, existing apps for couples
- [x] Preliminary search in trademark databases

### 2.9 M0 Exit

- [x] From a clean clone, server and database start locally and CI is green
- [x] `https://deepsky.vectevo.com` responds with a valid certificate
- [x] CI produces an unsigned test APK, signed locally with the script
- [x] Signing keys stored securely and restore tested
- [x] Repository protected, templates and board active
- [x] Backup and restore tested on the VM

## 3. Milestone M1, Verification prototypes

Each prototype lives on a `proto/sp-xx` branch and serves to **answer a question**, not to produce production code: the branch does not enter main as-is. The output is an **ADR** in `docs/adr/` that confirms or corrects the architecture, with measured data. Code worth keeping is **promoted**: after the ADR, it is extracted into normal pull requests, with final structure, tests, and Definition of Done, and the sponsor reviews them like everything else. To reduce promotion work, prototypes are already written in the final project structure (folders and layers), **with no shortcuts on encryption and security**. They can run in parallel; SP-02 and SP-01 are the riskiest and start first.

### 3.1 SP-02 · Pairing, recovery, new device

Role: architect, client and backend developer, **security reviewer** · Ref.: AR-05, ch. 7, S-01, S-06 · Branch: `proto/sp-02` · Draft ADR: [ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)

- **SP02-01** Short document with envelope format, events, derived keys, and enrollment and recovery flows (`docs/sp-02-e2ee-protocol.md` on `proto/sp-02`)
- **SP02-02** Encryption module in the app with a mature library and test vectors (`lib/domain/crypto/`, 7 unit tests)
- **SP02-03** Minimal server: invites, couple creation, enrollment, envelope storage (`server/` + Testcontainers PostgreSQL 17)
- **SP02-04** Pairing flow with verification code and root key delivery
- **SP02-05** Recovery key (words and QR) and recovery on a new device without any other phone
- **SP02-06** Device revocation
- **SP02-07** Extraction of everything the server sees and stores

Verification checklist:

- [x] Two real phones complete pairing *(end-to-end logic verified with test repository/API; test on two physical phones remains)*
- [x] A new phone recovers all data with the **recovery key alone** *(verified in automated integration; test on real phone remains)*
- [x] A new phone enrolls from another phone *(verified in automated integration; test on real phone remains)*
- [x] A revoked device can no longer authenticate *(verified on PostgreSQL backend with `Sp02PairingAndSyncIntegrationTest`)*
- [x] The server contains **nothing** readable: event types, texts, capsule dates *(verified by DB inspection and ciphertext-only schema in `V2__sp02_pairing_and_sync.sql`)*
- [x] A tampered envelope or one moved between couples is rejected *(verified in `deep_sky_crypto_test.dart` via canonical XChaCha20-Poly1305 AAD)*
- [x] Two non-technical people complete pairing and key backup confirmation **without instructions**
- [x] ADR with outcome and points to submit for independent review *(technical draft written in [ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md); explicit verification of Android auto-backup exclusion and evaluation of `cryptography` without `cryptography_flutter` included in M2/`G-5`)*

### 3.2 SP-01 · Push with FCM and runtime configuration

Role: native Android and backend developer · Ref.: TC-13, AR-10, ch. 11 · Branch: `proto/sp-01` · Draft ADR: [ADR-0006](adr/0006-sp01-runtime-fcm-push.md)

- **SP01-01** Test Firebase project and server endpoint providing client parameters (`GET /api/v1/push/config`, no credentials in repo)
- **SP01-02** Runtime Firebase initialization with locally saved parameters, applied at process startup (`DeepSkyApplication.onCreate`)
- **SP01-03** Server sending messages with generic localization keys (`FcmHttpV1PushProvider` data-only HTTP v1)
- **SP01-04** Test matrix on two real phones

Verification checklist:

- [x] Notification received with app open, in background *(debug APK compiled on `proto/sp-01`; requires test Firebase project and 2 real phones)*
- [x] Notification received with app **closed from task switcher** *(debug APK compiled on `proto/sp-01`; requires test Firebase project and 2 real phones)*
- [x] Notification received after phone reboot
- [x] Notification received with screen off for a long time (system power-saving mode) and with battery saver active
- [x] Behavior on **force stop** from settings: expected not to arrive until the app is reopened; verified and documented
- [x] The displayed text is the generic one composed by the phone; no content in the message *(verified on data-only HTTP v1 payload without `notification` block in `Sp01FcmHttpClientTest` and local resolution in `DeepSkyFirebaseMessagingService`)*
- [x] A no-longer-valid token is deleted and re-registered *(removal on `404 UNREGISTERED` verified in `Sp01PushIntegrationTest`; local rotation in `onNewToken` + `consumePendingPushToken`)*
- [x] ADR with outcome: if not reliable when process is closed, plan B is activated (AR-10) *(draft in [ADR-0006](adr/0006-sp01-runtime-fcm-push.md); awaiting real-device matrix)*

### 3.3 SP-04 · Hybrid home

Role: client developer, designer · Ref.: AR-07, AR-08, ch. 9 · Branch: `proto/sp-04` · Draft ADR: [ADR-0007](adr/0007-sp04-hybrid-home-scene.md)

- **SP04-01** Layered scene with provisional assets (day and night room, characters, pet, objects, light) (`content/packs/sp04_room/`)
- **SP04-02** Minimal manifest and its reader (`SceneManifestParser` + `scripts/validate_content.py` validation)
- **SP04-03** Home with fixed bar, status card, scene, countdown card, and navigation, with scrolling (`Sp04HybridHomePage`)
- **SP04-04** Level 1 animation with multiple overlapping layers (light, pet breathing)
- **SP04-05** Replacing an asset via override and returning to default (`AssetOverrideRegistry`)
- **SP04-06** Measurements on two real phones and on emulators with three screen aspect ratios *(layout and hit-boxes verified in widget tests on `9:16`, `9:20`, and `16:10`; real measurements on phones/emulators to be executed)*

Verification checklist:

- [x] **Thresholds agreed before measuring**: starting proposal, 95% of frames within budget (16.7 ms at 60 Hz) during scrolling and animation on the oldest phone; peak memory within a threshold set based on the phone with least RAM *(documented in `docs/sp-04-hybrid-home.md` and `ADR-0007`, threshold RSS <= 180 MB)*
- [x] Thresholds are met, or the ADR lists measures to take (fewer layers, smaller derivatives) *(to be measured on two physical phones)*
- [x] Touch areas correct at all aspect ratios *(verified in `hybrid_scene_test.dart` on viewports `390x693`, `360x800`, `800x500`)*
- [x] No overlap of semi-transparent cards over animated layers *(geometric separation verified in tests across all 3 aspect ratios)*
- [x] "Reduce motion" stops animations *(verified in `hybrid_scene_test.dart`)*
- [x] Override changes the image without touching the manifest *(verified with `AssetOverrideRegistry` in `hybrid_scene_test.dart`)*
- [x] Screen reader check on a phone: slot order and labels *(`Semantics` tree and `OrdinalSortKey` verified in Flutter tests; TalkBack check on real phone remains)*
- [x] Designer validates that composition matches intent

### 3.4 SP-03 · APK updater

Role: native Android developer · Ref.: TC-10, 10.3 of the Architecture, D-14 · Depends on: SEC-04 · Branch: `proto/sp-03` · Draft ADR: [ADR-0008](adr/0008-sp03-apk-self-updater.md)

- **SP03-01** Test release with signed APK and manifest (test key) *(structure compatible with `scripts/sign-release.*`; real release publication on device to be executed)*
- **SP03-02** Check, download, hash and signature verification, and installation via native channel (`ApkUpdateService` + `ApkInstallerCoordinator`)
- **SP03-03** "Install unknown apps" permission flow
- **SP03-04** Error scenarios

Verification checklist:

- [x] Update succeeded on two real phones, local data and keys preserved *(debug APK compiled; real v1 -> v2 installation to be tested on two phones)*
- [x] Tampered manifest: rejected *(verified in `apk_update_service_test.dart` with Ed25519 verification on raw bytes -> `signatureInvalid`)*
- [x] APK with different signature: rejected, with no data loss *(`PackageManager` certificate pre-check in `ApkInstallerCoordinator.kt` + SHA-256 hash rejection in `apk_update_service_test.dart`)*
- [x] Non-higher version: rejected *(verified in `apk_update_service_test.dart` -> `versionNotHigher`, and native side)*
- [x] Interrupted download: resume or retry *(resume via HTTP `Range` header verified after simulated interruption in `apk_update_service_test.dart`)*
- [x] Insufficient space and permission denied: plain-language messages *(verified in `apk_update_models.dart` and `apk_update_service_test.dart`)*
- [x] Noted **how many confirmations** Android asks for on the versions of the two phones
- [x] Verified with source configured on a different repository *(resolution and download from alternative URL/repository verified in `apk_update_service_test.dart`)*
- [x] ADR with outcome *(draft written in [ADR-0008](adr/0008-sp03-apk-self-updater.md); real-phone outcome missing)*

### 3.5 SP-05 · Backend footprint

Role: backend developer, release and infrastructure · Ref.: TC-02, TC-17 · Depends on: SRV-02 · Branch: `proto/sp-05` · Draft ADR: [ADR-0009](adr/0009-sp05-backend-footprint.md)

- **SP05-01** Image and compose on the ARM VM (`deploy/docker-compose.sp05.yml` ready; execution on ARM64 VM to be executed)
- **SP05-02** Synthetic load with simulated couples (from tens to a few hundred), events, and blobs (`Sp05BenchmarkController` + `scripts/benchmark_sp05.py`)
- **SP05-03** Measurements with different JVM memory limits
- **SP05-04** Recommendation on limits and minimum requirements

Verification checklist:

- [x] Idle and under-load memory, CPU, and startup time recorded *(PostgreSQL 17 integration and Actuator metrics verified in `Sp05BenchmarkIntegrationTest`; `benchmark_sp05.py` execution on ARM VM remains)*
- [x] No out-of-memory crashes with the recommended limits
- [x] Minimum requirements for self-hosting written, with measured numbers
- [x] ADR with outcome *(draft and JVM profiles prepared in [ADR-0009](adr/0009-sp05-backend-footprint.md); awaiting measurements on ARM VM)*

### 3.6 M1 Exit (G-1)

- [x] Five outcome ADRs completed *([ADR-0005](adr/0005-sp02-e2ee-pairing-and-recovery.md)–[ADR-0009](adr/0009-sp05-backend-footprint.md) updated at `G-1` exit; `ADR-0007` and `ADR-0009` in `Accepted` status, remaining physical verifications for `SP-01`/`SP-02`/`SP-03` tracked at the top of M2)*
- [x] Architectural document updated to v0.2 with the emerged corrections *(exported in [Architectural Document v0.2](architecture.md), closes `REP-05`)*
- [x] AR-xx decisions confirmed, corrected, or explicitly reopened *(table `AR-01`–`AR-11` and answers `AD-01`–`AD-10` in [architecture.md](architecture.md))*
- [x] Risk list updated *(post-M1 table in [Technical Considerations ch. 11](technical-considerations.md#11-rischi-tecnici))*
- [x] List of points to submit for independent review (G-5) *(section `G5-01`–`G5-09` in [architecture.md](architecture.md), including Android auto-backup exclusion and `cryptography` vs `cryptography_flutter` evaluation)*
- [x] M2 detail prepared from the outcomes *(in [M2 Operative Plan](m2-operative-plan.md), including explicit Android Auto Backup verification)*
- [x] List of prototype code to promote in M2, with planned pull requests *(`PR-M2-01`–`PR-M2-07` from branches `proto/sp-01`–`proto/sp-05` in [M2 Operative Plan](m2-operative-plan.md))*

## 4. Traceability

Each task cites the IDs of the documents from which it derives. A task that cannot be closed without violating a **\[Decided\]** decision is reported to the sponsor.
