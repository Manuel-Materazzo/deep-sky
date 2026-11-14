# ADR-0001: Use Architecture Decision Records

- **Status:** Accepted
- **Date:** 2026-11-14
- **Reference IDs:** `REP-03`, `PD-11`

## Context

Deep Sky is developed collaboratively by the promoter and AI agents across multiple tracks (client, backend, native Android, content, infrastructure). Decisions on contracts, cryptography, runtime versions, and M1 verification prototypes (`SP-01`–`SP-05`) need durable, reviewable records inside the repository so future contributors and agents do not accidentally reverse or forget why a choice was made.

## Decision

We store Architecture Decision Records as Markdown files in `docs/adr/` using sequentially numbered files (`NNNN-short-kebab-title.md`) based on [0000-template.md](0000-template.md).

- Every ADR must cite the document IDs from which it descends (`P-xx`, `TC-xx`, `PD-xx`, etc.).
- ADRs are proposed and reviewed via pull requests and require promoter approval (`PD-11`).
- Once accepted, an ADR is not rewritten when things change; instead, a new ADR is added marking the previous one as `Superseded by ADR-XXXX`.

## Alternatives Considered

- **Keep decisions only in PR descriptions or issues:** Pros: less ceremony. Cons: hard to browse offline, easy to miss across branches, scattered context.
- **Single monolithic architecture document only:** Pros: single file. Cons: merge conflicts and harder to track historical changes over time.

## Consequences

- Clear audit trail for M0 foundational choices and M1 prototype findings.
- Slight overhead when introducing new dependencies, SDK version bumps, or protocol changes, offset by faster onboarding and safer reviews.
