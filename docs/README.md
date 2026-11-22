# Deep Sky Documentation Index

This directory contains the project documentation, operational plans, technical reference guides, and Architecture Decision Records (`docs/adr/`).

> **Looking for guides to install, configure, or use the app and server without developing?**
> Go to the **[User & Server Operator Wiki (`docs/wiki/`)](wiki/README.md)** (includes **Getting Started**, content pack publishing, backup, and recovery).

## Core Project Documents

| Document | Version | ID Prefixes | Description |
| :-- | :-- | :-- | :-- |
| [Project Brief](project-brief.md) | 0.2 | `P-xx`, `F-xx`, `S-xx`, `N-xx`, `D-xx` | Product vision, principles, features, security and non-functional requirements |
| [Design Brief](design-brief.md) | 0.2 | `V-xx`, `A-xx`, `DD-xx` | Emotional intent, visual direction, house metaphor, AI asset system, design phases |
| [Technical Considerations](technical-considerations.md) | 0.1 | `TC-xx`, `SP-xx`, `AD-xx` | Stack decisions, push proposal, scene architecture, E2EE model, updates, open architecture questions |
| [Architecture Document](architecture.md) | 0.2 | `AR-01`..`AR-11`, `AD-01`..`AD-10`, `G5-01`..`G5-09` | Exported post-M1 architecture v0.2 (`REP-05`), `AR-xx` outcomes, component boundaries, and `G-5` security review points |
| [Development Plan](development-plan.md) | 0.1 | `PD-xx`, `M-x`, `SL-xx`, `G-x` | Roles, engagement rules, milestones M0–M8, vertical slice model, gates |
| [M0 and M1 Operative Plan](m0-m1-operative-plan.md) | 0.1 | `REP-xx`, `SEC-xx`, `INF-xx`, `SRV-xx`, `APP-xx`, `CNT-xx`, `CI-xx`, `NAME-xx`, `SPxx-xx` | Detailed checklists for M0 Foundations and M1 Verification Prototypes (`G-1` closed) |
| [M2 Operative Plan](m2-operative-plan.md) | 0.1 | `PR-M2-xx`, `F-01`, `F-03`, `F-19`, `F-20`, `G-2` | Detailed M2 execution plan, carry-over hardware checks from M1, and prototype-to-PR promotion inventory |

## Technical & Operational Guides

| Document | Related Tasks | Description |
| :-- | :-- | :-- |
| [Architecture Decision Records](adr/README.md) | `REP-03`, `SRV-01`, `APP-01` | Index and template for ADRs (`docs/adr/`) |
| [Key Custody & Offline Signing Procedure](key-custody.md) | `SEC-03`, `SEC-04`, `PD-10`, `AD-08` | Offline generation, encrypted backup, restore verification, and public fingerprint registry |
| [Server Configuration Reference](server-configuration.md) | `SRV-03`, `INF-04` | Environment variables, defaults, validation rules, and self-hosting notes |
| [Firebase Setup Guide](firebase-setup.md) | `TC-04`, `S-02`, `AD-04`, `SP-01` | Step-by-step guide to creating a Firebase project, extracting runtime options, and mounting the service account key |
| [Real-Device Testing Procedure](device-testing.md) | `APP-01`, `APP-03` | How to build, install, and verify debug/signed APKs on physical Android devices |
| [Release Signing & Publishing Workflow](release-signing-workflow.md) | `CI-02`, `SEC-04`, `PD-10` | End-to-end flow: CI unsigned build, offline signing, GitHub Release publishing |
| [Backup and Restore Procedure](backup-restore.md) | `INF-05`, `TC-11` | OCI VM backup scope and restore verification checklist |
| [AI Asset Tools Terms & License Evaluation](ai-asset-tools-terms.md) | `CNT-02`, `D-11`, `A-08` | Candidate AI image generation tools, ToS comparison, and asset license recommendation |
| [Dependency Licenses Inventory](dependencies-licenses.md) | `SEC-02` | Snapshot of client and server dependency licenses verified for MIT compatibility |
| [Code Audit 2026-11-16](code-audit-2026-11-16.md) | `S1-SEC-01`, `S1-SEC-02`, `G-3a`, `G5-xx` | Open findings (`CA-xx`) from a manual code review, with fixes and acceptance criteria, and the areas still to be reviewed |
