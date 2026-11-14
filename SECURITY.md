# Security Policy

## Security & Privacy Commitment

In Deep Sky, privacy and security are verifiable requirements (`P-06`, `S-01`–`S-07`), not marketing claims:

- **End-to-end encryption (`S-01`):** Sensitive couple content is encrypted on client devices; the backend stores only encrypted payloads/blobs and minimal operational metadata.
- **No ad telemetry (`S-07`):** No advertising SDKs or behavioral tracking.
- **Offline key custody (`PD-10`, `AD-08`):** Release APK and manifest signing keys never enter GitHub, CI runners, or chat logs.

## What Must Never Enter This Repository

- APK release signing keystores (`*.jks`, `*.keystore`, `*.p12`) and passphrases
- Ed25519 private keys for manifest/content-pack signing
- Firebase service account JSON files or API keys bound to private quotas
- Server admin secrets, database credentials, or `.env` files
- Real user data, tokens, or unredacted device logs

## Supported Versions

Deep Sky is currently in pre-release foundation milestones (`M0`/`M1`). Security fixes are applied directly to `master`. Do **not** use Deep Sky for real personal data until `M2` (`G-2`, `PD-05`) and independent review (`G-5`) are completed according to the [Development Plan](docs/development-plan.md).

## Reporting a Vulnerability

If you discover a security vulnerability in Deep Sky (cryptography, authentication, update verification, backend isolation, or secret exposure):

1. **Do not open a public GitHub issue.**
2. Report it privately using GitHub **Private Vulnerability Reporting** (Security tab -> *Report a vulnerability*) on `Manuel-Materazzo/deep-sky`, or contact the maintainer directly via the email listed in commit metadata.
3. Include:
   - Affected component (`app`, `server`, `scripts`, `deploy`, or `content`)
   - Clear reproduction steps or proof-of-concept
   - Impact assessment (e.g., confidentiality, integrity, update chain, availability)

We aim to acknowledge reports within 72 hours and coordinate a fix before public disclosure.
