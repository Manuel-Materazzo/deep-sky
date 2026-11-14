# Architecture Decision Records (ADRs)

Reference: `REP-03`, [Piano di sviluppo](development-plan.md) section 2.2.

Significant architectural choices, version pins, contract changes, and M1 prototype outcomes (`SP-01`–`SP-05`) are recorded here. ADRs are immutable once accepted; later changes supersede previous ADRs rather than rewriting history.

## Index

| ID | Title | Status | Related IDs |
| :-- | :-- | :-- | :-- |
| [ADR-0000](0000-template.md) | ADR Template | Template | `REP-03` |
| [ADR-0001](0001-use-adrs.md) | Use Architecture Decision Records | Accepted | `REP-03`, `PD-11` |
| [ADR-0002](0002-java-spring-boot-versions.md) | Java and Spring Boot Baseline Versions | Accepted | `SRV-01`, `TC-02` |
| [ADR-0003](0003-android-sdk-versions.md) | Android Minimum and Target SDK Versions | Accepted | `APP-01`, `TC-04`, `D-14` |
| [ADR-0004](0004-server-modular-structure.md) | Backend Modular Monolith Package Boundaries | Accepted | `SRV-01`, `TC-02` |
| [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md) | E2EE Pairing, Recovery, Cross-Device Enrollment, and Revocation (`SP-02`) | Proposed | `S-01..S-06`, `AD-01..AD-03`, `SP-02` |
| [ADR-0006](0006-sp01-runtime-fcm-push.md) | Runtime-Configured FCM Push Notifications (`SP-01`) | Proposed | `S-02`, `TC-04`, `AD-04`, `SP-01` |
| [ADR-0007](0007-sp04-hybrid-home-scene.md) | Hybrid Home Scene Composition, Animations, and Asset Overrides (`SP-04`) | Proposed | `AR-07`, `AR-08`, `TC-08`, `TC-09`, `SP-04` |
| [ADR-0008](0008-sp03-apk-self-updater.md) | Signed-Manifest Self-Update & PackageInstaller Flow (`SP-03`) | Proposed | `F-19`, `TC-10`, `SEC-04`, `SP-03` |
| [ADR-0009](0009-sp05-backend-footprint.md) | Backend Memory Limits and Self-Hosting Footprint (`SP-05`) | Proposed | `TC-02`, `TC-17`, `SRV-02`, `SP-05` |
