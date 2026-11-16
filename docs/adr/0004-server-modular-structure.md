# ADR-0004: Backend Modular Monolith Package Boundaries

- **Status:** Accepted
- **Date:** 2026-11-14
- **Reference IDs:** `SRV-01`, `TC-02`, `TC-05`, `TC-13`

## Context

The Deep Sky server is deployed as a single Spring Boot container alongside PostgreSQL (`TC-02`, `TC-03`). Even as a single deployable unit, keeping strict domain boundaries prevents coupling between pairing/auth, encrypted event sync, encrypted blob storage, push delivery (`PushProvider`), and content pack distribution.

## Decision

Under `com.vectevo.deep_sky_server`, code is organized into explicit top-level modules:

- `config` — Startup configuration properties (`DeepSkyProperties`), validation, Spring Security baseline
- `shared` — Cross-cutting value objects and error representations (no business state)
- `pairing` — Invites, couples, device enrollment/revocation
- `sync` — Encrypted event log and optimistic-concurrency encrypted snapshots
- `blob` — Encrypted binary blob storage and quotas
- `push` — `PushProvider` abstraction and runtime Firebase configuration delivery (`TC-13`)
- `content` — Versioned content pack distribution endpoints

Module boundaries are enforced automatically in CI via ArchUnit (`ArchitectureTest`) with three rules: top-level modules must be free of dependency cycles; `pairing`, `sync`, `blob`, `push`, `content` and `shared` must not depend on `config`; `shared` must not depend on any domain module. Direct access between sibling domain modules is not yet forbidden by a rule (only cycles are); a stricter sibling-isolation rule is a follow-up.

## Alternatives Considered

- **Unstructured layer-only packages (`controller`, `service`, `repository`):** Pros: simple at 5 classes. Cons: encourages cross-domain spaghetti as `M2`–`M5` slices are added.
- **Separate microservices:** Rejected — unnecessary operational overhead for self-hosters (`N-04`, `TC-02`).

## Consequences

- Clean vertical-slice ownership across `M1`–`M3`.
- ArchUnit runs on every `./mvnw test` build, catching accidental cross-module coupling immediately.
