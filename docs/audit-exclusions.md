# Audit Exclusions

This document records audit findings and recommendations that have been intentionally excluded or accepted by the project maintainer, so future audits and contributors do not re-introduce unwanted changes.

---

## Excluded Items

| Audit ID | Scope | Excluded Recommendation | Rationale / Policy | Recorded |
| :-- | :-- | :-- | :-- | :-- |
| `AU-25` (a) | `.github/workflows/ci.yml` | Trigger CI workflows on the `development` branch (`push` / `pull_request`). | CI intentionally runs only on `master` (push and pull requests targeting `master`). Do not add `development` branch triggers to `.github/workflows/ci.yml`. | 2026-11-21 |
| `AU-25` (d) | `deploy/.env.example` | Pin a specific version tag or digest as the default `DEEPSKY_SERVER_IMAGE`. | `deploy/.env.example` intentionally keeps `ghcr.io/manuel-materazzo/deep-sky-server:latest` as its default value; operators who want pinned versions may override it in their own `.env`. | 2026-11-21 |
