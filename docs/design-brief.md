# Design Brief: Deep Sky

**Version:** 0.2 (draft for review) · **Date:** November 12, 2026 · **Depends on:** Project Brief v0.2

**Audience:** designer agent. Knows nothing about the project: this document, together with the Project Brief, is everything they need.

**Conventions.** The statuses **\[Decided\]**, **\[Assumption\]**, **\[Open\]** have the same meaning as in the Project Brief. The IDs in this document are **V-xx** (visual and experience requirements), **A-xx** (asset requirements), **DD-xx** (open design decisions). The IDs P-xx, F-xx, S-xx, N-xx refer back to the Project Brief and must be cited in deliverables.

**What's new in v0.2 (November 12, 2026), for those who have already started working:** (1) Android platform first; (2) new screens to design: app update, recovery key and new device, read-only offline mode (Chapter 7); (3) animation: starting from level 1, with multiple stacked layers per slot, leaving the path open toward skeletal or part-based animation (Chapter 11, DD-11). The rest of the document is unchanged.

---

## 1. Mission

The designer defines **identity, visual language, asset system, and design system** for a mobile app for couples. They do not decide the tech stack, architecture, or data model: if a technical constraint limits the design, they flag it as a question to the sponsor.

## 2. The Product in Brief

It is a **private digital home for two people**, even long-distance. It is not a chat or a task manager: it is a space where every small gesture (a "thinking of you," a turn-based drawing, a mood, a countdown, a time capsule, a photo of the day) leaves a visible trace in the shared room. A shared pet, which never dies, reacts to what the couple does. Mobile-first, no ads, no streaks, no coins, open source.

Principles the design must embody: **P-01** small gestures, **P-02** affection without obligation, **P-03** voluntary and non-punitive engagement, **P-04** home-first, **P-05** mobile-first, **P-09** simplicity for non-technical users.

## 3. Emotional Intent

| Whoever opens the home must feel | Must never feel |
| :-- | :-- |
| Tenderness, calm, intimacy | Duty, guilt, pressure to "prove" something |
| That the other person is there, even at a distance | Mutual control or surveillance |
| Curiosity to discover what has been left | Notification anxiety, "unread" anxiety, urgency |
| That an absence of days is normal | That the home "turns off" or punishes inactivity |
| Affectionate play | A kids' app or a points-based game |

## 4. Identity

### 4.1 Name

**\[Decided\] DD-01.** The final product name is **Deep Sky** (D-01). The emotional direction remains "the light left on": the gesture of letting someone know you're there without writing. Naming of internal interface concepts remains open.

### 4.2 Concept: The Light

**\[Assumption\]** Light is the recurring motif of the identity and interface language: when the other person leaves a gesture, something lights up in the home (a window, a lamp, a small light). Iron rule (P-02, P-03): **the home never turns off and never goes dark due to inactivity**. Light rewards the arrival of a gesture, never punishes its absence.

Logo and icon: simple, recognizable at 48 px, effective in monochrome, legible on both light and dark backgrounds. No text in the icon.

## 5. Visual Direction

- **V-01** Warm, not childish: a tender world for adults who love each other, not a game for children.
- **V-02** Mobile-first: designed for one hand and a thumb. Desktop is not a target.
- **V-03** Home-first: the home screen is the house/room, not a feature menu.
- **V-04** One single consistent illustrative style for pet, avatars, objects, and backgrounds.
- **V-05** Style **producible with AI**: must be chosen so it can be reproduced consistently by image generators. Avoid styles that require technical precision (complex perspectives, detailed hands, text in images).
- **V-06** Light and dark theme. Evening is a prime usage time, and dark theme is a first-class citizen, not a color inversion.
- **V-07** Accessibility: AA contrast, adequate touch targets, scalable text, meaning never conveyed by color alone, respect for "reduce motion."
- **V-08** No visual dark patterns: no urgent red badges, anxiety-inducing counters, or aggressive "unread" indicators. New items are signaled gently.
- **V-09** The home must work even when **sparse**: in the first phase (core) there are no pet or corkboard, and it must later grow without rebuilding the composition.

**Anti-references.** Desktop-first and ambient aesthetic of the Kehai project (visuals not liked by the sponsor); coin, reward, and streak visual language of Togetherly. Do not copy visuals from existing projects.

**Positive references.** **\[Open\] DD-02**: to be defined together with the sponsor via moodboard (see phases, Chapter 11).

## 6. The Home

### 6.1 Composition

**\[Assumption\]** A 2D illustrated cutaway scene, front view, composed of **objects in fixed slots** over a background. Each object corresponds to a feature and tapping it opens it:

- window: the light, time of day, received gestures (F-03);
- wall calendar or board: countdown (F-06);
- sealed box or shelf: time capsule (F-07);
- corkboard: pinned drawings and images (F-08);
- frame or album: photo of the day and timeline (F-10, F-11);
- book or journal: questions and "game of the day" (F-14);
- the pet (F-09) and the two partner characters.

The scene cannot be the only form of navigation: minimal, accessible navigation to features is needed (**DD-04**).

### 6.2 Artifact Rules

- Every activity leaves a visible artifact in the home (P-04).
- The home never becomes saturated: when a space (e.g., the corkboard) fills up, older items move to the timeline without being lost.
- Items unlock as a natural consequence of activities, never as currency or reward (P-03).

## 7. Screen and Moment Inventory

| Screen or moment | Features | Design notes |
| :-- | :-- | :-- |
| Onboarding and pairing | F-01 | Invite via link or QR; understandable by non-technical users; no server jargon |
| Home / house | F-02 | Conveys at a glance: next meetup, recent mood, latest drawing |
| Send a "thinking of you" gesture | F-03 | A few seconds, optional phrase |
| Mood of the day | F-04 | Always optional; "today I could use..." |
| Turn-based drawing | F-05 | Canvas, simple tools, received drawing, over-drawing, message; designed also for people who can't draw |
| Countdown | F-06 | List and detail with description, todo, images, comments |
| Time capsule | F-07 | Creation, sealing, waiting, **opening ceremony** |
| Corkboard | F-08 | Free-form arrangement of images and drawings |
| Pet and room | F-09 | Poses, reactions, activity history |
| Album, timeline, days together | F-10, F-11, F-12 | Days together are never a measure of commitment |
| Game of the day | F-14 | One coherent module, not a bundle of mini-games |
| Notifications and widget | F-13, F-16 | Generic content by default on the lock screen (S-02) |
| Settings and privacy | F-17, S-03, S-04 | Export, permanent deletion, breaking pairing, and optional consensual couple reactivation with dignified, non-blaming tone |
| Customization | F-18 | See Chapter 8 |
| Empty states, errors, offline, loading | all | Affectionate tone, never alarming |
| App update | F-19 | Check, confirmation, and progress; the "Install unknown apps" permission must be explained simply; "update required" screen when the server enforces a minimum version, with non-alarming tone |
| Recovery key and new device | F-20, S-06 | Key generation at pairing with confirmation that it was saved; restore on a new phone; reassuring tone, never blaming |
| Offline mode | N-03 | Read-only: scene and memories visible, write actions disabled with a gentle message (P-02) |

**Moments to design with care:** first gesture received; returning after days of absence (welcoming, never scolding); opening a time capsule; arrival of the pet in the home.

## 8. Characters and Customization

### 8.1 The Pet

**\[Assumption\]** Default pet: a **dog**, replaceable by the couple with another animal. Does not die, does not degrade, has no needs to satisfy. Reacts to what the couple does (a new cushion after a time capsule, a hung photo after a photo of the day).

The pet expresses itself with a **finite set of poses**. **\[Assumption\]** An initial set of about 8 poses: resting, attentive, happy, curious, sleeping, welcoming, participating in an activity, celebrating. **No poses of sadness, boredom, or hunger tied to absence.** The number of poses determines the cost for anyone wanting to replace the character, so it must be kept low (see A-05).

### 8.2 The Two Partners

Each partner has a customizable character, with no assumptions about gender or couple composition. Default appearance is neutral and pleasant.

### 8.3 Customization (F-18 Proposal)

**\[Assumption\]** The couple can replace home assets with their own images, created with an AI assistant of their choice. Examples: adding a detail to the dog, changing the animal, redesigning the partner characters. **The app neither offers nor integrates any AI service** (N-06): it provides a kit, receives an image.

Four-step flow, to be designed as a guided experience understandable by non-technical users:

1. **Download the kit** for the chosen slot: current image, spec sheet, suggested prompts, style references.
2. **Use your AI assistant** with the kit and your details (prompts have placeholders to fill in).
3. **Upload** the resulting image.
4. **Preview in the home** and confirm; restoring the original is always possible.

The app verifies that the image complies with format, dimensions, and transparency, with plain-language messages. The designer also designs what happens if the image is non-compliant (**DD-08**).

## 9. AI-Generated Asset System

All visual assets (pet, avatars, objects, backgrounds) will be **generated with AI tools**, not hand-drawn or vector. The designer does not deliver source files from a graphics program: they deliver **PNG/JPG images and instructions to reproduce them**.

- **A-01 Formats.** PNG with transparency for objects, characters, and accessories. JPG allowed only for backgrounds and opaque photographs.
- **A-02 Masters and derivatives.** The designer delivers high-resolution master images and resizing specifications. Derivatives for different screen densities are produced by developers via a pipeline (**DD-10** for resolutions and file size budgets).
- **A-03 Style Bible.** Document that makes the style reproducible: reference images, palette, linework, lighting, base prompts, negative prompts, and which tool produced the masters. Independent of a specific model.
- **A-04 Clean transparency.** Edges without halos, crop with defined margin, verified on light and dark backgrounds. If the tool does not produce true transparency, the workflow uses a uniform background and background removal, and the acceptance criterion remains the same.
- **A-05 Consistency.** Variants of the same character (pet poses) must look like the same subject. Requires a reference *character sheet* and a side-by-side acceptance test.
- **A-06 No text or trademarks.** No embedded text, logos, trademarks, or copyrighted characters in assets (text is localized by the app).
- **A-07 Catalog.** Each asset has: ID, name, type, slot, master dimensions, format, full prompt, references used, version, approval status.
- **A-08 License.** The generation tool's terms of use must allow redistribution of assets in an open source project. The designer records tool and terms; **\[Open\] DD-06**.
- **A-09 Slots.** Every replaceable object occupies a *slot*. The designer delivers the **slot table** with: slot ID, description, anchor in the scene, dimensions, required transparency, layering order, whether it is replaceable.

## 10. Voice and Microcopy

- **V-10** First person plural ("our home"), affectionate tone, brief, never pressuring.
- **V-11** Never a sense of duty: "you can leave something," never "you must prove something" (P-02).
- **V-12** Italian and English each crafted on their own merits, not mechanically translated; strings must accommodate different lengths.

| Yes | No |
| :-- | :-- |
| "I left you a drawing." | "You haven't replied in two days!" |
| "You have a thought arriving." (generic notification) | Intimate content on the lock screen |
| "So good to see you again, the home was waiting for you." | "You lost your streak of days." |
| "If you feel like it, share how it went." | "Explain why you feel this way." |

## 11. Motion, Sound, Haptics

**\[Assumption\]** Brief, gentle movements; light turning on as a recurring gesture; light haptics; sounds off by default (**DD-09**). No animation that insists on grabbing attention. Respect for "reduce motion."

**Animation.** **\[Decided\]** Starting at **level 1**: transforms, opacity, and fades on image layers, including multiple stacked layers per slot (e.g., shadows, light reflections, particles, accessories). The scene manifest describes per-slot animations (type, duration, curve, loop). Assets the designer plans to animate must be delivered in **separate parts** when needed (e.g., head and tail). **Final goal: level 3**, 2D skeletal or part-based animation, with tool and format yet to be chosen (**DD-11**). The design must not make the transition from level 1 to level 3 difficult.

## 12. Constraints

- **Stack-independent** deliverables (D-06 is not decided): design tokens in JSON, PNG/JPG images, text documents.
- Android and iOS both first-class citizens; light and dark theme; widgets in small sizes (F-13).
- **Open-licensed fonts** (e.g., OFL) bundled in the app: no dependency on external services for fonts or images (N-06).
- No space for ads or tracking elements (S-07).
- Notifications with generic content by default (S-02).
- User-uploaded images are private content and must be treated as such (S-01).

## 13. Phases and Deliverables

Each phase ends with sponsor approval before proceeding.

| Phase | Deliverables | Gate |
| :-- | :-- | :-- |
| **DS-1 Visual discovery** | Analysis of anti-references, **3 moodboard directions**, logo and visual identity proposals | Sponsor chooses a direction |
| **DS-2 Pilot** | Style Bible, **pilot kit** (a few pet poses, two objects, one avatar) and full test of **replacement with an external AI assistant** | Pilot demonstrates stylistic consistency and feasibility of the customization flow |
| **DS-3 Design system** | Tokens (light/dark colors, typography, spacing, radii, shadows, motion), iconography, components, microcopy guidelines | System approval |
| **DS-4 Screens** | Key screens and states: first the core (F-01 – F-07), then the rest | Approval by feature groups |
| **DS-5 Asset catalog** | Complete catalog, slot table, customization guide | Catalog approval |
| **DS-6 Handoff** | Developer documentation, visual QA checklist | Delivery |

**Rule:** do not produce all assets before gate DS-2.

## 14. Acceptance Criteria

- Every design choice cites the principles or features from which it derives.
- No element violates P-02, P-03, or V-08.
- Assets in a family pass the consistency test (A-05) and the transparency test on light and dark backgrounds (A-04).
- An asset can be **regenerated and replaced** by another person following only the Style Bible and the catalog.
- A non-technical partner completes pairing and sends a "thinking of you" without instructions.
- Screens work in light and dark themes, in Italian and English, with enlarged text.

## 15. Open Decisions

The designer does not resolve them: they flag them, proposing alternatives with pros and cons.

| ID | Issue |
| :-- | :-- |
| **DD-01** | Naming of internal concepts (final name decided: **Deep Sky**) |
| **DD-02** | Illustrative style and reference moodboard |
| **DD-03** | Default pet species and final pose set |
| **DD-04** | Home as a single scene or multiple rooms; accessible navigation beyond the scene |
| **DD-05** | Customization granularity: replace the entire pose set or add accessories as overlaid layers with anchor points |
| **DD-06** | Generation tool and license terms for assets in an open source project |
| **DD-07** | Are customizations visible to both partners or only to the creator? |
| **DD-08** | Handling a non-compliant uploaded image: rejection with explanation, automatic adaptation, other |
| **DD-09** | Presence and role of sounds |
| **DD-10** | Master resolutions and file size budgets per asset and per app |
| DD-11 | Tool and format for level 3 animation (2D skeletal or part-based): must be producible by agents, not only by a manual editor, and remain compatible with AI-generated assets |

## 16. Traceability

Every designer deliverable cites the IDs from this brief (V-xx, A-xx, DD-xx) and from the Project Brief (P-xx, F-xx, S-xx, N-xx) from which it derives. In case of conflict with a P-xx principle, the principle wins and the conflict is flagged to the sponsor.
