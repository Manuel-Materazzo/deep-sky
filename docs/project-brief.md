# Project Brief: Deep Sky

**Version:** 0.2 (draft for review) · **Date:** November 12, 2026 (D-08 updated November 16, 2026) · **Status:** awaiting sponsor approval

**Audience:** project sponsor and team of AI agents tasked with producing the subsequent documents (design system, architecture document, development plan, specifications, test plan).

**What's new in v0.2 (November 12, 2026):** Android as the first platform (N-02); end-to-end encryption confirmed from v1 with recovery via key exchange between phones and recovery key (S-01, S-06); read-only offline app (N-03); built-in updates from v1 (N-10, F-19); recovery and new device (F-20); tech stack decided (D-06). Detailed technical decisions are in the Technical Considerations document.

**How to read statement statuses.** Every decision is marked as follows:

- **\[Decided\]**: confirmed by the project sponsor.
- **\[Assumption\]**: reasonable proposal emerged from the discovery phase, not yet confirmed. Agents treat it as a working default and flag if they consider it problematic.
- **\[Open\]**: unresolved issue, listed in Chapter 14. Agents do not resolve it on their own: they raise it.

This document is self-contained: anyone reading it needs no other context.

---

## 1. Vision at a Glance

We are building **a private digital home for two people**: a mobile app where a couple, even long-distance, leaves small signs of their presence in each other's day. It is not a couple's task manager and it is not a chat app. Drawings, moods, countdowns, memories, and a small shared pet are not separate features: they leave visible traces in the same space, "our home," which grows with the relationship.

> A private, affectionate home for two people: mobile-first, no ads, no streaks, no coins, with a pet that remembers your story.

**\[Decided\]** The product is born first and foremost as an app that the sponsor will use with his partner. Opening the source code (open source) is a choice of values and sustainability, but it is not the main pitch of the project: the primary value is the experience.

## 2. Goals and Non-Goals

### Goals

1. Offer a rich, pleasant experience of everyday closeness that two people want to use spontaneously.
2. Ensure that the entire experience is free to self-host, with no ads, ad tracking, or paid affection features.
3. Make the app enjoyable for both partners, even when only one of them is technical.
4. Treat privacy and security as verifiable requirements, not reassuring marketing copy.
5. Follow a complete software development process (brief, design, architecture, plan, implementation, testing, release).

### Non-Goals (for now)

- Free-form chat, audio or video calls as core features.
- Expense management, complex shared calendars, synchronization with external calendars.
- Dating, matching between strangers, social features across multiple couples.
- Gamification, virtual currencies, levels, quests, leaderboards.
- Unlimited free hosting provided by the project.

## 3. Context and Problem

Existing couple apps almost all follow one of these patterns: intrusive ads, affection features behind a subscription, engagement mechanics (streaks, coins, rewards) that turn affection into a measurable chore. Open source alternatives exist, but none satisfy all of the sponsor's needs together.

Discovery examined three relevant projects. They are references, not targets to replicate:

| Project | What it does well | Why it falls short |
| :-- | :-- | :-- |
| **Kehai** (MIT) | Closest concept: shared pet that doesn't die, corkboard, doodle, mood, countdown, questions | Visuals not liked; desktop-first approach; declared a personal project, with no roadmap or support |
| **Togetherly** (GPL-3.0) | Broad feature base: time capsule, mood, widget, shared drawing, mascot | Coins, rewards, streaks, and ads: the exact engagement loop to avoid |
| **OnePair** (license unverified) | Accountless experience, drawing, letters, capsules | Focus on chat, calls, and peer-to-peer sync; limited asynchronous delivery; few features of interest |

**Conclusion.** The gap is not the features, which already exist, but the **quality of the experience**: a mobile-first, warm, and well-crafted home, open and free from the attention economy, that works on Android and iPhone and is simple for the non-technical partner.

## 4. Users

**Primary users:** couples (including long-distance) composed of two people. The app is always used by exactly two paired people.

**Persona A, "the configurator."** Has technical skills, is willing to install and maintain a server or choose a hosting provider. Decides where the data lives.

**Persona B, "the partner."** Does not want to know what a server is. Installs the app, accepts an invite, and must find it beautiful, simple, and reliable from the very first minute.

**Design constraint:** the success of the product is measured on Persona B. If only the configurator is happy, the product has failed.

**\[Assumption\]** Future secondary users: non-technical couples paying for managed hosting; people wishing to contribute to the code.

## 5. Product Principles

These are the criteria by which every feature and design choice is accepted or rejected. Agents cite them by ID.

- **P-01. Small gestures, not big commitments.** Every key interaction must be completable in a few seconds.
- **P-02. Affection without obligation.** No feature turns affection into something measurable or owed. Forbidden: streaks, compatibility scores, counts of who sends more, automatic nudges ("your partner has been waiting for two days"), insistent prompts to explain a mood. Not opening the app for days must feel normal.
- **P-03. Voluntary, non-punitive engagement.** Notifications exist for a real gesture from the other person, never to pull the user back into the app. The pet does not die and does not degrade. House items unlock as a natural consequence of activities, never as currency.
- **P-04. Home-first, not feature-first.** Features are not menu sections: every activity leaves a visible artifact in the home.
- **P-05. Mobile-first.** The primary experience is on the smartphone. Android and iOS are both first-class citizens.
- **P-06. Security as a precise promise.** "Open source," "self-hosted," and "private" are not synonyms: they are three distinct commitments (inspectable code, choice of who hosts the data, content protection) and must be described and verified separately.
- **P-07. No implicit surveillance.** Online presence, read receipts, and location are not present or, if introduced in the future, are optional and disabled by default.
- **P-08. Asynchronous by nature.** A gesture must arrive even if the other person is offline.
- **P-09. Simplicity for non-technical users.** Self-hosting is a choice for the configurator, not a daily complication for the user.
- **P-10. Everything is free if you host it yourself.** No affection feature is paywalled.

## 6. Product Concept: The Home

The central metaphor is **"our home"**: a small shared room that grows with the relationship. Artifacts produced by activities appear in it:

- a finished drawing becomes a framed picture on the corkboard;
- a photo of the day enters the album or timeline;
- a sealed letter becomes an object in the home until its opening date;
- an answer to a question can become a journal page or a memory;
- a countdown can become a calendar on the wall;
- the pet reacts to what you have done (a new cushion after an opened time capsule, a hung photo after a photo of the day, a drawing on the wall after a shared drawing).

The home is not a currency, it is not a chore, and it does not measure love.

**Main screen (example of intent).** The home screen should convey at a glance, for example: "We see each other in 12 days. Today I'm feeling a bit drained, but I'd love to hear from you. I left you a drawing."

## 7. Features

### 7.1 Tiers

| Tier | Features | Role |
| :-- | :-- | :-- |
| **Daily core** | Thinking of you, mood, turn-based drawing, countdown, photo of the day, questions | Small recurring moments |
| **Couple's memory** | Timeline, time capsule, corkboard, days together, widget | Affectionate archive |
| **Shared world** | Pet, virtual home, decorations, unlocked items | Continuity and reason to return |

### 7.2 Feature Catalog

IDs are stable and must be used in subsequent documents.

| ID | Feature | Description |
| :-- | :-- | :-- |
| **F-01** | Pairing | Invite via link or QR, without public accounts. Procedure understandable by both. Ability for either person to break the pairing unilaterally. |
| **F-02** | Home screen | Overview: active countdown, recent mood, latest drawing, next time capsule opening. |
| **F-03** | Thinking of you | One tap, with optional short phrase and discreet notification. |
| **F-04** | Mood of the day | Emoji or small status, optional note (including "today I could use..."), shared history. Always optional. |
| **F-05** | Turn-based drawing | One draws and sends; the other can draw on top of it; both can add messages. Asynchronous, no real-time canvas. Designed also for people who can't draw. |
| **F-06** | Countdown | Date, title, description, todo list, images, and comments. Next meetup, anniversary, or custom event. |
| **F-07** | Time capsule | Photo or letter sealed until a chosen date, which opens on the set day. |
| **F-08** | Corkboard | Free-form board to pin images and drawings. |
| **F-09** | Pet and room | Shared pet that reacts to recent activities, doesn't die, keeps a small history of what you've done. The home collects the artifacts. |
| **F-10** | Photo of the day | An optional daily photo that enters the album or timeline. |
| **F-11** | Timeline / memories | Chronology of what happened, with images. |
| **F-12** | Days together | Counter of days spent together. Never used as a measure of commitment. |
| **F-13** | Widget | Home screen widget for Android and iOS (e.g., shared photo, days together, countdown, mood). |
| **F-14** | Game of the day | Single module bringing together question of the day, this or that, would you rather, truth or dare, and tic-tac-toe, to avoid a "bundle of mini-games." |
| **F-15** | Contextual short messages | Phrases, reactions, and optional notes attached to drawings, photos, countdowns, questions. No free-form chat. |
| **F-16** | Notifications | Discreet, with generic content by default on the lock screen. Only for real gestures from the other person. |
| **F-17** | Export, deletion, and reactivation | Full data export; explicit rules for permanent deletion and fate of shared content; `[Assumption]` optional **consensual couple reactivation** after unilateral breakup (S-03), only with explicit confirmation from both partners before permanent deletion (S-04). |
| F-18 | Asset customization | The couple replaces home assets (pet, partner characters, items) with their own images: the app exports the current asset with a spec sheet and suggested prompts, the user takes them to their own AI assistant and re-uploads the result. The app neither offers nor integrates any AI service. Restoration always possible. |
| F-19 | App updates | Check and install APK updates from GitHub releases and download content packs from the server, always with user confirmation. The server can enforce a minimum client version. |
| F-20 | Recovery and new device | Recovery key generated at pairing, with confirmation that it was saved; reinstallation on a new phone via key re-sending from the other device or via the recovery key (S-06). |

### 7.3 Excluded or Deferred

- **Excluded:** free-form chat as a core feature, audio/video calls, streaks, coins, levels, quests, rewards, ads, compatibility scores.
- **Deferred for future evaluation:** expense management, shared calendars, online presence, location, music listening, wearable data, time zones. If introduced, they must comply with P-02 and P-07.

## 8. Release Phases and Scope

**\[Assumption\]** Proposed sequence, to be confirmed (see D-03 in Chapter 14):

| Phase | Content | Purpose |
| :-- | :-- | :-- |
| **0. Discovery and design** | Moodboard, home structure, clickable prototypes of home, turn-based drawing, mood, countdown, time capsule | Define feel and visual identity before code |
| **1. Core (dogfooding)** | F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-16, F-19, F-20 | Real-world use by two people for 2–3 weeks, without pet or corkboard |
| **2. Memory** | F-08, F-10, F-11, F-12, F-13, F-15, F-17 | Add what both feel is missing |
| **3. World** | F-09, F-18, and decorations | Give continuity and identity to the home |
| **4. Game of the day** | F-14 | Recurring content in a single module |
| **5. Opening** | License decision, code publication, hosting model | Public release |

Features are added only if both partners feel they are missing during real-world use.

## 9. Security and Privacy

Requirements expressed as verifiable commitments. The architecture document must state how each will be satisfied and verified.

- **S-01 \[Decided\]** The server operator cannot read intimate content: end-to-end encryption from the first version. Derived state (for example, pet reactions) is computed by one device, encrypted, and uploaded to the server for synchronization. If this were impossible for any content, it must be declared explicitly.
- **S-02 \[Assumption\]** Notifications show generic content by default, without exposing moods or messages on the lock screen.
- **S-03 \[Assumption\]** Either person can break the pairing without the other's consent; breaking the pairing immediately locks all devices and prevents a single partner from unilaterally reopening the couple (even using the shared recovery key S-06).
- **S-04 \[Assumption\]** Export, permanent deletion, fate of shared content, and any encrypted retention window for **consensual couple reactivation** have explicit, documented rules; any reactivation of a broken couple requires explicit, verified consent from both partners (never unilateral) before permanent deletion (F-17, D-15).
- **S-05 \[Assumption\]** No online presence, read receipts, or location enabled by default (P-07).
- **S-06 \[Decided\]** Data must always be recoverable if a phone is lost: the other phone can re-send keys to the new device and, in addition, at pairing a **recovery key** is generated which the user must confirm having saved. Recovery is guaranteed as long as the other phone or the saved key exists, and the user must know this clearly.
- **S-07 \[Decided\]** No advertising telemetry and no tracking for advertising purposes.

## 10. Non-Functional Requirements (Directions)

These are directions to be turned into measurable requirements in the architecture document.

- **N-01 Reliable asynchronous delivery:** a sent gesture arrives even when the recipient is offline, in compliance with S-01.
- **N-02 Compatibility:** Android first **\[Decided\]**; iOS in a later phase, with the implications regarding paid developer accounts and push relays to be revisited then. On Android the app is distributed as an APK (N-10).
- **N-03 Network tolerance:** acceptable use with intermittent connectivity and varying networks. When offline, the app is **read-only** **\[Decided\]**: scene and memories viewable, write actions disabled with a gentle message (P-02), no sync queue.
- **N-04 Simple self-hosting:** server installation and updates documented and reproducible, with minimal maintenance.
- **N-05 Data portability:** open, documented export formats, no mandatory dependency on a project-run service.
- **N-06 Third-party independence:** no mandatory external APIs; any optional services (e.g., push notifications) are replaceable and documented.
- **N-07 Accessibility and localization:** Italian and English as initial languages **\[Assumption\]**; baseline accessibility (contrast, text sizing, screen reader) in the design system.
- **N-08 Perceived performance:** opening the app and sending a gesture must feel immediate.
- **N-09 AI-generated and replaceable visual assets:** assets are PNG/JPG images produced with AI tools; the couple can replace them with their own images through an export and re-upload flow, without the app integrating any AI service (N-06). The system must validate format, dimensions, and transparency of uploaded images.
- **N-10 Built-in updates from the first version** **\[Decided\]**: the app includes two mechanisms. (1) Content packs (assets, scene manifest, texts) downloaded from the server and verified, without installation. (2) APK update downloaded from the project's GitHub releases, with a configurable source, and installed via the "Install unknown apps" permission with system confirmation. The server can enforce a minimum client and protocol version.

## 11. Experience and Visual Direction

- **\[Decided\]** Mobile-first, warm, not childish. Graphics are a core element of the product, not a finishing touch.
- Negative starting point, by contrast: Kehai's visuals were judged unappealing, and Togetherly's reward mechanics are stressful.
- The pet and the home must convey tenderness without looking childish or like a points-based game.
- Copy tone is affectionate and never pressuring: "you can leave something," never "you must prove something."
- The design system must derive from a moodboard approved by the sponsor (D-04).

## 12. Open Source Model and Sustainability

**\[Assumption\]** Software is separated from service:

| Component | Proposal |
| :-- | :-- |
| Application and backend | Open source, with no feature locks |
| Self-hosting | Same features as the managed service |
| Managed hosting | Optional paid service for those who don't want to administer anything |
| Support and maintenance | Possible additional services |
| Community funding | Donations and sponsorships, with no influence on data |

People pay, if at all, for infrastructure convenience, never to send a gesture of affection. Unlimited free hosting is not promised before estimating costs and usage patterns. **\[Decided\]** The decision on whether and when to open the source code, and under what license, is made after dogfooding (D-05).

## 13. Validation and Success Metrics

**Guiding question (North Star metric):** *"When you thought of each other, did you open this app instead of doing nothing?"*

Success is not measured in downloads. Signals to observe during dogfooding, collected with both partners' consent and in compliance with P-02:

- both partners open the app spontaneously, not just the configurator;
- the app is chosen for a real gesture (a "thinking of you," a drawing) instead of a message elsewhere;
- partners spontaneously report what is missing;
- neither partner feels a sense of duty or guilt for not having used the app.

Metrics must never become user-facing features (no attention counters).

## 14. Open Decisions

Agents do not resolve them: they flag them and propose alternatives with pros and cons.

| ID | Issue | Notes |
| :-- | :-- | :-- |
| **D-01** | Final product name | **\[Decided\]** **Deep Sky**. |
| **D-02** | End-to-end encryption: scope and trade-offs | Decided: E2EE from v1 (S-01), state computed by a device, recovery with key exchange between phones and recovery key (S-06). Details in Technical Considerations. |
| **D-03** | MVP scope | Discovery produced both a nine-element MVP (including pet and corkboard) and a sequence that defers them until after dogfooding. The boundary must be chosen. |
| **D-04** | Visual direction | Needs an approved moodboard (style, palette, pet style). |
| **D-05** | License and timing of opening the code | Decision after dogfooding. |
| **D-06** | Tech stack and architecture | Decided: Flutter for the app; Java with Spring Boot and PostgreSQL for the backend; all in Docker Compose, with ARM and AMD images. The architecture document details its use. |
| **D-07** | Launch platforms | Decided: Android first, distributed as APK from GitHub releases, without Play Store or App Store for now. iOS deferred. |
| **D-08** | Push notifications | **[Decided]** FCM with Firebase credentials provided at runtime by the self-hoster's server, without relay and without `google-services.json` in the APK. Validated with prototype SP-01 on real hardware (app open, in background, swiped away from task switcher, after reboot, in Doze; ADR-0006). Force Stop from Settings suspends delivery until the app is reopened. UnifiedPush remains a future option (Plan B, not activated). |
| **D-09** | Independent verification of alternatives | A hands-on test of Kehai and OnePair with two real devices has not yet been carried out. The sponsor has already evaluated the projects; decide whether more is needed. |
| **D-10** | Managed hosting model | Whether and when to offer it, at what cost, and with what guarantees. |
| D-11 | AI asset generation tool and license | The tool's terms of use must allow redistribution of assets in an open source project. The asset license may differ from the code license. |
| D-12 | Granularity and visibility of customization (F-18) | Replace entire pose sets or add overlaid accessories? Are customizations visible to both partners or only to the creator? How to treat them with respect to S-01 (private content). |
| D-13 | Server network exposure | Public HTTPS behind a reverse proxy or private network (e.g., Tailscale). Impacts simplicity for the non-technical partner (P-09) and security. |
| D-14 | Android developer verification for official APK | The limited-distribution account covers up to 20 devices. An official public APK will require full verification when the requirement extends to Italy (expected from 2027). Package name and signing key must remain stable. |
| **D-15** | Couple dissolution, grace period, and consensual reactivation (`F-17`, `S-03`, `S-04`, `S-06`) | **\[Open\]** After unilateral breakup (`S-03`), today the server performs a soft close (`unpaired_at`) blocking auth, invites, and unilateral recovery (`S-06`). For `M5 Memoria` it must be decided: (a) whether to provide a temporary retention window for encrypted data (e.g., grace period) before permanent deletion or if permanent deletion should be immediate/on explicit request; (b) which cryptographic and UX mechanism guarantees **bilateral consensual reactivation** (e.g., challenge approved by both partners, preventing someone who alone holds the shared Recovery Key from reopening the couple); (c) what happens if only one partner requests export or permanent deletion during closure. |

## 15. Key Risks

| Risk | Impact | Mitigation |
| :-- | :-- | :-- |
| Scope too broad (home, pet, games, memory) | Product never polished | Phases, dogfooding, rejecting features that don't serve a daily core need |
| Complex E2EE with asynchronous delivery and key recovery | Delays or unmaintainable promises | Early decision (D-02), technical prototype, honest disclosures |
| Insufficient visual quality | Product fails to win over the non-technical partner | Moodboard and prototypes before code, testing with Persona B |
| Drift toward engagement farming | Betrayal of principles | P-02 and P-03 as acceptance criteria for every feature |
| iOS distribution and updates | Unequal experience between Android and iPhone | Explicit decision (D-07) |
| Project carried forward by a single person | Abandonment or slowdown | Realistic development plan, documentation, opening code after dogfooding |

## 16. Glossary

- **Home:** shared space that collects the artifacts created by the couple.
- **Artifact:** visible trace left by an activity (framed picture, photo, letter, object).
- **Gesture:** brief interaction communicating presence (e.g., "thinking of you").
- **Dogfooding:** real-world use of the product by the two sponsors before opening it to others.
- **Configurator / Partner:** the two personas described in Chapter 4.
- **E2EE:** end-to-end encryption, whereby only the two partners can read the content.

## 17. Subsequent Documents

| Document | Depends on this brief for | Produces |
| :-- | :-- | :-- |
| **Design system** | Chapters 5 (principles), 6, 11 | Moodboard, typography, colors, components, copy tone |
| **Architecture document** | Chapters 9 and 10, D-02, D-06, D-07, D-08 | Stack, data model, security model, deployment |
| **Functional specifications** | Chapter 7 (F-xx IDs) | Flows, edge cases, acceptance criteria per feature |
| **Development plan** | Chapters 8 and 15 | Milestones, work order, dependencies |
| **Test plan** | Chapters 9, 10, and 13 | Testing strategy, security, usability with Persona B |
| **Openness and sustainability plan** | Chapter 12, D-05, D-10 | License, governance, managed hosting |

**Rule for agents.** Every feature, requirement, or decision in subsequent documents must cite the ID from this brief (P-xx, F-xx, S-xx, N-xx, D-xx) from which it derives. If a document conflicts with a P-xx principle, the principle wins and the conflict must be flagged to the sponsor.
