# Development Plan: Deep Sky

**Version:** 0.1 (draft for review) · **Date:** November 14, 2026 · **Depends on:** Project Brief v0.2, Design Brief v0.2, Technical Considerations v0.1, Architecture Document v0.1

**Audience:** sponsor, developer agents, test agent, designer agent.

**Name.** D-01 is resolved: the product is called **Deep Sky**. Earlier documents still use "Casa" as a working title and are being updated by the sponsor.

**Conventions.** **\[Decided\]**, **\[Proposal\]**, **\[Open\]** as in the other documents. The IDs in this document are **PD-xx** (plan decisions), **M-x** (milestones), **SL-xx** (vertical slices), **G-x** (gates). Other IDs (P, F, S, N, D, V, A, DD, TC, SP, AD, AR, AP) refer back to earlier documents.

---

## 1. Plan Principles

- **PD-01 \[Decided\]** No deadlines: planning is by **milestones with exit criteria**, not by dates.
- **PD-02 \[Decided\]** **Vertical slices:** every feature is built with visuals, code, assets, and tests together (TC-12).
- **PD-03 \[Decided\]** **Real-world use before adding:** a new feature enters only if both partners feel it is missing (Project Brief, Ch. 8).
- **PD-04 \[Proposal\]** **Rolling-wave planning:** high detail for M0 – M2, medium for M3, coarse for the rest. Refined after measuring actual velocity with M2.
- **PD-05 \[Proposal\]** **Security before real data:** no real intimate data in the app until pairing, recovery, and encryption have passed SP-02 and tampering tests.
- **PD-06 \[Proposal\]** **Every slice ends with a signed APK** published as a release, installable with the built-in updater: in-app updating is thus tested at every step.

## 2. Work Organization

### 2.1 Roles

| Role | Responsibility | Owns |
| :-- | :-- | :-- |
| **Sponsor** | Product owner: priorities, gate approvals, testing with partner | **\[Decided\]** decisions |
| **Designer** | Identity, design system, screens, assets, scene manifest | Design Brief, deliverables DS-1 … DS-6 |
| **Architect** | Technical coherence, contracts between components, decision records | Architecture document, API and format contracts |
| **Backend developer** | APIs, database, push, packs | `server/` folder |
| **Client developer** | Flutter app, scene, synchronization, client-side encryption | `app/` folder |
| **Native Android developer** | Widget, APK installer, runtime Firebase, keystore | Kotlin code in `app/android/` |
| **QA and testing** | Test strategy, automation, real-device testing | Test folder and acceptance criteria |
| **Security reviewer** | Review of encryption, protocols, update supply chain | Review reports |
| **Release and infrastructure** | CI, multi-arch images, signing, releases, backups | `deploy/`, pipelines |
| **Technical writer** | Self-hosting guide, release notes, user documentation | `docs/` |

One agent can cover multiple roles, but security review and QA are not performed by whoever wrote the code they verify.

### 2.2 Rules of Engagement

- Every task cites the document IDs from which it derives.
- A conflict with a **\[Decided\]** decision is **flagged** to the sponsor: agents do not resolve it on their own.
- Changes to decisions or contracts go through an **Architecture Decision Record** (ADR) approved by the sponsor.
- No real data in tests or in CI; **no secrets in the repository**.
- No release without sponsor approval.

### 2.3 Repository and Workflow

**\[Proposal\]** Monorepo with `app/`, `server/`, `content/` (manifests, packs, assets), `deploy/`, `docs/` (documents and `docs/adr/`). Development with short-lived branches and pull requests; CI must be green to merge; conventional commit messages; board and issues on GitHub.

### 2.4 Definition of Ready and Done

**A slice is ready to start** when it has: reference features and IDs, designer-approved screens, API contract and event format, acceptance criteria.

**A slice is done** when:

- code is integrated and CI is green;
- unit, integration, and where needed *golden* tests are present;
- it works on two real phones;
- copy in Italian and English, baseline accessibility verified (V-07);
- no violations of P-02, P-03, V-08;
- documentation updated and signed release installed via updater;
- notes of observations collected in use.

## 3. Decisions to Get Started

| ID | Issue | Decision |
| :-- | :-- | :-- |
| **PD-07 \[Decided\]** | Android package name | `com.vectevo.deep_sky`. Remains stable from now on: changing it after the first build would mean creating a different app (D-14) |
| **PD-08 \[Decided\]** | Domain for HTTPS (AR-11) | `deepsky.vectevo.com`, with DNS record pointing to the OCI VM |
| **PD-09 \[Decided\]** | Repository visibility | **Public from the start**, a single monorepo; APK releases live in the same repository. Closes D-05 on timing |
| **PD-10 \[Decided\]** | Signing key custody (AD-08) | Offline custody with encrypted backup in two locations; **local signing on every release**. CI produces unsigned artifacts |
| **PD-11 \[Decided\]** | Supervision | The sponsor supervises everything: **no merge without his approval**. Pull requests are small and verifiable (4.1) |
| **PD-12 \[Decided\]** | Pace and capacity | The sponsor decides pace and priorities; assumed capacity of about **one hour per day** (4.1) |
| **PD-13 \[Proposal\]** | Code license | **MIT**, awaiting confirmation (3.1). Asset license is separate and still open (D-11) |

### 3.1 Implications of Publishing Immediately

- **Secrets.** The repository is public from the first commit: a secret that enters history remains exposed, even if later removed. Starting in M0: secret scanning in CI and before every commit; signing keys, Firebase service key, and admin secret stay out of the repository.
- **Real data.** No real data, screenshots, or real names of people in examples, tests, or documentation.
- **MIT license.** Allows anyone to use, modify, and redistribute the code, even in closed versions or paid services, without obligation to share modifications. The most common alternative for a server is **AGPL-3.0**, which requires anyone offering the service over a network to publish their modifications. MIT is a legitimate choice and the simplest one; it must be confirmed knowing this (PD-13).
- **AI-generated assets.** The code license does not automatically cover images: their terms depend on the tool used, and the copyright status of AI-generated works is uncertain. Before adding them to the public repository, tool terms are verified (D-11) and a separate license is chosen for assets.
- **Name and trademark.** The code license does not grant the Deep Sky name or the logo: a brief note on name usage is needed. A preliminary search found no couple apps with this name, but that is not sufficient verification: the real check (domains, GitHub, trademarks) is in M0.
- **Dependencies.** With MIT, copyleft components are avoided in client and server; CI checks dependency licenses.
- **Security.** Public code does not replace G-5: independent review remains necessary before inviting any other couple.

## 4. Milestone Map

Size is **relative** (S, M, L, XL), not a duration: it serves to compare milestones against one another. Actual durations are estimated after M2.

| ID | Milestone | Phase in Project Brief | Size | Depends on |
| :-- | :-- | :-- | :-- | :-- |
| **M0** | Foundations | — | S | PD-07 … PD-10 |
| **M1** | Verification prototypes | 0 | M | M0 |
| **M2** | Walking skeleton | 1 | L | M1 (G-1), DS-2 |
| **M3** | Core | 1 | XL | M2 (G-2), DS-3 … DS-5 |
| **M4** | Real-world use and review | 1 | S of work, weeks of calendar time | M3 (G-3) |
| **M5** | Memory | 2 | L | M4 (G-4) |
| **M6** | World | 3 | L | M5 |
| **M7** | Game of the day | 4 | M | M6 |
| **M8** | Opening | 5 | L | G-5 |

### 4.1 Review Capacity and Indicative Estimates

Since the sponsor supervises everything (PD-11) and dedicates about one hour per day (PD-12), the bottleneck is **review**, not agent speed. Consequences:

- **small** pull requests, reviewable in 20–40 minutes, each with reference IDs, summary, test evidence, and indication of what to look at most closely;
- agents run tests, static analysis, and self-review **before** requesting sponsor review; his hour is for decisions, phone testing, and sensitive points (security, contracts);
- a weekly status summary, to decide priorities without reading everything;
- slices sized so that testing on the two phones takes little time.

**Indicative** and very uncertain estimates, assuming about 5–10 medium pull requests per week. They are not deadlines (PD-01) and must be recalibrated at G-1 with actual velocity.

| Milestone | Indicative duration |
| :-- | :-- |
| M0 | about 1 week |
| M1 | 2 – 3 weeks |
| M2 | 4 – 6 weeks |
| M3 | 8 – 12 weeks |
| M4 | 2 – 3 calendar weeks |
| M5 | 5 – 8 weeks |
| M6 | 5 – 8 weeks |
| M7 | 2 – 4 weeks |
| M8 | 4 – 8 weeks, excluding independent review time |

## 5. Parallel Workstreams

| Workstream | Content | Sequence constraint |
| :-- | :-- | :-- |
| **Design** | DS-1 … DS-6 from Design Brief | Stays **one slice ahead** of developers; M2 requires pilot DS-2, M3 requires DS-3 … DS-5 for each slice |
| **Server** | APIs, data, push, packs | API contracts approved before client |
| **Client** | App, scene, synchronization, encryption | Depends on contracts and scene manifest |
| **Native Android** | Widget, installer, Firebase, keystore | Emerges from prototypes SP-01, SP-03 |
| **Content** | AI asset production and signed packs | Follows Style Bible (A-03) |
| **Quality and release** | CI, device testing, signed releases, backups | Starts in M0 and grows with the project |

## 6. Milestone Details

### 6.1 M0, Foundations

**Activities:**

1. creation of the **public** monorepo with license (PD-13), README, contribution guidelines, security notice, and folder structure;
2. protections: secret scanning in CI and pre-commit, dependency license scanning, main branch rules (merge only with green CI and sponsor approval);
3. CI: formatting, static analysis, tests, server and app builds, with **unsigned** artifacts;
4. development Docker Compose (api, db, proxy) with ARM64 and AMD64 images;
5. OCI infrastructure: DNS record for `deepsky.vectevo.com` pointing to the VM; ports 80 and 443 open in both OCI network rules and VM firewall (default OCI images have restrictive ones); Caddy with automatic certificate;
6. signing keys: offline generation of the APK key and the manifest/pack key, encrypted backup in two locations, restore test; **local signing** script for releases;
7. versioning conventions and release manifest format;
8. pull request template (IDs, test evidence, review focus points) and Architecture Decision Record (ADR) template; work board;
9. availability check for the Deep Sky name (domains, GitHub, trademarks).

**Exit:** from a clean clone, server and database start locally, CI produces an unsigned test APK which is signed locally with the script, and https://deepsky.vectevo.com responds with a health check.

### 6.2 M1, Verification Prototypes

Small, throwaway prototypes, executable in parallel with the design system. Each prototype produces a **decision record** confirming or correcting the Architecture Document.

| ID | Question | Pass criterion | If it fails |
| :-- | :-- | :-- | :-- |
| **SP-02** | Pairing, recovery key, and new device | Flow completed on two phones; key-only recovery; server sees no content; understandable by non-technical partner | Review protocol with security reviewer |
| **SP-01** | FCM with runtime initialization, when app is closed | Push received with process killed on two real phones | PushProvider interface (AR-10): UnifiedPush or dedicated build |
| **SP-04** | Hybrid home: layered scene with one animated layer, one replaced asset, UI around it | Smooth frames and memory within limits on two phones; accurate taps across different aspect ratios | Reduce layers and animations, revise layout rules |
| **SP-03** | APK update from GitHub release with verification | Update succeeds; tampered manifest and different signature rejected | Revise flow and checks |
| **SP-05** | Spring Boot and PostgreSQL on ARM VM | Consumption measured and limits defined | JVM optimizations or stack revision |

**Exit (G-1):** Architecture Document updated to v0.2 with prototype outcomes.

### 6.3 M2, Walking Skeleton

The thinnest path traversing the **entire** architecture, with few features. Includes:

- server on OCI VM with HTTPS (Caddy), invites, couples, devices, signature-based authentication;
- **pairing, recovery key, and enrollment of a new device** (F-01, F-20): these are the precondition for using real data (PD-05);
- encrypted "thinking of you" event (F-03), synchronization, generic push;
- home with provisional layered scene, base content pack, pilot design system tokens;
- APK updater and minimum version check (F-19, basic version);
- read-only offline mode; backup and restore test on the VM.

**Exit (G-2):** two real phones exchange a gesture end-to-end via the OCI server; an update via GitHub release works twice in a row; a backup restore succeeds.

### 6.4 M3, Core

Vertical slices, in this starting order (the sponsor can reorder them):

| Slice | Features | Notes |
| :-- | :-- | :-- |
| **SL-01** | Real home and scene, complete design system, content pack v1 (F-02) | Unblocks the other slices |
| **SL-02** | Polished Thinking of you and notifications (F-03, F-16) | Design Brief style and copy |
| **SL-03** | Mood of the day (F-04) | Always optional |
| **SL-04** | Countdown (F-06) | Local notifications for due dates |
| **SL-05** | Turn-based drawing (F-05) | Most demanding slice of the core |
| **SL-06** | Time capsule (F-07) | Seal enforced by the app (6.3.1) |
| **SL-07** | Full updates (F-19) | Screens, errors, "update required" |
| **SL-08** | Offline, empty states, and errors | Affectionate tone, never alarming |

**Exit (G-3):** all slices finished per Definition of Done; no violations of P-02 and P-03 principles; tested on real devices; restore test repeated; guide for using the app as a couple.

### 6.5 M4, Real-World Use and Review

Use between the two of you for **2 – 3 weeks**, with core features only. An observation journal, the signals from Ch. 13 of the Project Brief (spontaneous opening by both, no sense of duty), bug fixes. Internal security review and preparation for the independent review.

**Exit (G-4):** reasoned list of what is missing, resolution of D-03, and priorities for M5.

### 6.6 M5 – M8, Summary

| Milestone | Main content | Exit |
| :-- | :-- | :-- |
| **M5 Memory** | Corkboard (F-08), photo of the day (F-10), timeline (F-11), days together (F-12), widget (F-13), short messages (F-15), export, permanent deletion, couple dissolution and consensual reactivation (F-17, S-03, S-04) | Memory archive genuinely used by both |
| **M6 World** | Pet and room (F-09), asset customization (F-18), decorations, level 1 animation with multiple layers; level 3 exploration (DD-11) | Pet and home reacting to activities |
| **M7 Game of the day** | Single module (F-14) | Recurring content without pressure |
| **M8 Opening** | Independent security review (G-5), Android developer verification (D-14), license and code opening (D-05), complete self-hosting guide, multi-couple testing | Public release for others |

M5 – M7 are planned in detail only after G-4.

## 7. Vertical Slice Template

Every SL-xx slice contains, in order:

1. **Definition:** features, IDs, acceptance criteria;
2. **Design:** screens, states, assets, and content pack (design one slice ahead);
3. **Contract:** API, event format, schema version;
4. **Server and client** in parallel on the contract;
5. **Testing:** unit, integration, *golden*, two devices;
6. **Release:** signed APK, manifest, optional content pack;
7. **Usage observations:** notes for the next slice.

## 8. Gates

| Gate | When | What is verified | Approver |
| :-- | :-- | :-- | :-- |
| **G-1** | End of M1 | Architectural risks closed, architecture confirmed or corrected | Sponsor |
| **G-2** | End of M2 | End-to-end skeleton, update, and restore tested | Sponsor |
| **G-3** | End of M3 | Ready for real-world use: principles respected, tests passed | Sponsor |
| **G-4** | End of M4 | What to add, from usage observations | Sponsor |
| **G-5** | Before M8, and before inviting **any other couple** | **Independent review** of encryption, protocols, update supply chain | Sponsor with reviewer |

## 9. Plan Risks

| Risk | Impact | Mitigation |
| :-- | :-- | :-- |
| Scope too broad | No part polished | PD-03, small core, features only if missing for both |
| Design and development out of sync | Developers waiting or work thrown away | Design one slice ahead, contracts approved first |
| Review as bottleneck | Work stalled waiting | Small pull requests, agent self-review, weekly summary (4.1) |
| Unknown agent and sponsor velocity | Unreliable estimates | Indicative estimates, calibration at G-1, rolling-wave planning |
| Prototypes disproving architecture | Rework | Run them in M1, before building; decision record for each outcome |
| Real data used too early | Loss or exposure of intimate data | PD-05, G-2 |
| Secrets in public repository | Irreparable exposure in history | Secret scanning in CI and pre-commit; no secrets in repository; keys offline only |
| Loss of signing keys | Updates impossible | PD-10, encrypted backup in two locations, restore test |
| AI asset license unclarified | Assets not redistributable in public repository | D-11 before publishing assets |
| Android developer verification in Italy | Public APK hindered | D-14, stable package name (PD-07) |

## 10. Next Steps

1. Confirm the **code license** (PD-13) and start checking generation tool terms for assets (D-11).
2. Start **M0**.
3. Start **M1** in parallel with designer's DS-1 and DS-2, starting from SP-02 and SP-01, the riskiest prototypes.
4. Prepare **M2** details based on G-1 outcomes.

## 11. Traceability

Every task and every slice cites the IDs from this plan (PD, M, SL, G) and from the documents it derives from. In case of conflict with a **\[Decided\]** decision, the conflict is flagged to the sponsor without resolving it autonomously.
