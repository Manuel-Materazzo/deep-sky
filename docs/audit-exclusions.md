# Audit Exclusions

This document records audit findings and recommendations that have been intentionally excluded or accepted by the project maintainer, so future audits and contributors do not re-introduce unwanted changes.

---

## Excluded Items

| Audit ID | Scope | Excluded Recommendation | Rationale / Policy | Recorded |
| :-- | :-- | :-- | :-- | :-- |
| `AU-25` (a) | `.github/workflows/ci.yml` | Trigger CI workflows on the `development` branch (`push` / `pull_request`). | CI intentionally runs only on `master` (push and pull requests targeting `master`). Do not add `development` branch triggers to `.github/workflows/ci.yml`. | 2026-11-21 |
| `AU-25` (d) | `deploy/.env.example` | Pin a specific version tag or digest as the default `DEEPSKY_SERVER_IMAGE`. | `deploy/.env.example` intentionally keeps `ghcr.io/manuel-materazzo/deep-sky-server:latest` as its default value; operators who want pinned versions may override it in their own `.env`. | 2026-11-21 |
| `IR-04` (a) | `ContentPackStore`, `deploy/.env.example` | Make server-side Ed25519 verification of content packs mandatory (fail closed, or pre-fill `DEEPSKY_CONTENT_TRUSTED_KEY_V1`) when `DEEPSKY_CONTENT_PACKS_DIR` is set. | Accepted by the maintainer: server-side verification stays optional, and without keys the server only logs a `WARN` at startup. The client is the cryptographic trust anchor (`G5-07`) and always verifies the signature, so this only affects catching publishing mistakes. Source: `docs/s3-2-independent-review-2026-11-22.md`. | 2026-11-22 |
