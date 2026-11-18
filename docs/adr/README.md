# Architecture Decision Records (ADRs)

Reference: `REP-03`, [Piano di sviluppo](development-plan.md) section 2.2.

Significant architectural choices, version pins, contract changes, and M1 prototype outcomes (`SP-01`–`SP-05`) are recorded here. ADRs are immutable once accepted; later changes supersede previous ADRs rather than rewriting history.

## Index

| ID | Title | Status | Related IDs |
| :-- | :-- | :-- | :-- |
| [ADR-0000](0000-template.md) | ADR Template | Template | `REP-03` |
| [ADR-0001](0001-use-adrs.md) | Use Architecture Decision Records | Accepted | `REP-03`, `PD-11` |
| [ADR-0002](0002-java-spring-boot-versions.md) | Java and Spring Boot Baseline Versions | Accepted | `SRV-01`, `TC-02`, `TC-03` |
| [ADR-0003](0003-android-sdk-versions.md) | Android Minimum and Target SDK Versions | Accepted | `APP-01`, `TC-04`, `N-02`, `D-14` |
| [ADR-0004](0004-server-modular-structure.md) | Backend Modular Monolith Package Boundaries | Accepted | `SRV-01`, `TC-02`, `TC-05`, `TC-13` |
| [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md) | E2EE Pairing, Recovery, Cross-Device Enrollment, and Revocation (`SP-02`) | Accepted (hw verified; `PD-05` / `G-5`) | `S-01`, `S-03`, `S-06`, `F-01`, `F-02`, `AD-01..AD-03`, `SP-02` |
| [ADR-0006](0006-sp01-runtime-fcm-push.md) | Runtime-Configured FCM Push Notifications (`SP-01`) | Accepted | `S-02`, `TC-13`, `AD-04`, `AR-10`, `SP-01` |
| [ADR-0007](0007-sp04-hybrid-home-scene.md) | Hybrid Home Scene Composition, Animations, and Asset Overrides (`SP-04`) | Accepted | `AR-07`, `AR-08`, `TC-08`, `TC-09`, `A-09`, `V-07..V-10`, `SP-04` |
| [ADR-0008](0008-sp03-apk-self-updater.md) | Signed-Manifest Self-Update & PackageInstaller Flow (`SP-03`) | Accepted | `F-19`, `TC-10`, `SEC-04`, `D-14`, `SP-03` |
| [ADR-0009](0009-sp05-backend-footprint.md) | Backend Memory Limits and Self-Hosting Footprint (`SP-05`) | Accepted | `TC-02`, `TC-17`, `SRV-02`, `SP-05` |
| [ADR-0010](0010-g5-09-cryptography-timing-evaluation.md) | Cryptography Library Evaluation: `cryptography` vs `cryptography_flutter` (`G5-09`) | Proposed (`G-5` review) | `G5-09`, `S-01`, `S-06`, `N-06`, `AD-01`, `AD-06` |
| [ADR-0011](0011-ca01-sas-out-of-band-secret.md) | Out-of-Band Link/QR Secret in Pairing SAS Derivation (`CA-01`) | Accepted (`PD-11`) | `S-01`, `S-06`, `F-01`, `G5-01`, `G5-03`, `S1-SEC-01`, `CA-01` |
| [ADR-0012](0012-ca02-epoch-key-rotation-on-revocation.md) | Independent Epoch Key Rotation and Recovery Key Rotation on Revocation (`CA-02`) | Accepted (`PD-11`) | `S-01`, `S-06`, `AD-01`, `PD-19`, `G5-05`, `S1-SEC-02`, `CA-02` |
