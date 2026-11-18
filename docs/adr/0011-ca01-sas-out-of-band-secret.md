# ADR-0011: Out-of-Band Link/QR Secret in Pairing SAS Derivation (`CA-01`)

- **Status:** Accepted by promoter (`PD-11`, 2026-11-16); supersedes the SAS derivation paragraph of [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md)
- **Date:** 2026-11-16
- **Reference IDs:** `S-01`, `S-06`, `F-01`, `G5-01`, `G5-03`, `S1-SEC-01`, `CA-01`

## Context

Under [ADR-0005](0005-sp02-e2ee-pairing-and-recovery.md), `DeepSkyCrypto.computeSasCode` derived a 6-digit SAS code (~20 bits) from the X25519 `sharedSecret`, `coupleId`, and the sorted pair of KEM public keys returned by the server. Because each phone received the peer's `kemPublicKey` from the server with no commitment step or secret unknown to the server, a malicious server operator (`S-01`) acting as man-in-the-middle could generate two substituted X25519 keypairs (`M1`, `M2`) via a birthday search (~2^10–2^20 operations) so that `SAS(A, M1) == SAS(B, M2)`, breaking SAS verification.

## Decision

When creating an initial pairing invite or a cross-device enrollment invite, the inviter client generates a fresh 128-bit (16-byte) random `sasSecret` locally using `Random.secure()`.

1. **Out-of-band transport only:** `sasSecret` is stored locally in `SecureKeyStore` (`deep_sky.pending_invite.v1`) and encoded inside the shareable invite URI fragment (`#token=<inviteToken>&sas=<sasSecretB64>` or `#server=...&token=<inviteToken>&sas=<sasSecretB64>`) and the manual compact pairing code (`<inviteToken>.<sasSecretB64>`).
2. **Never sent to the server:** `sasSecret` is **never** sent in `POST /api/v1/pairing/invites`, `POST /api/v1/pairing/invites/accept`, `POST /api/v1/pairing/invites/status`, or `POST /api/v1/pairing/enrollment-invites`. The static `/join` landing page keeps it strictly inside the browser `#fragment` and forwards it to `deepsky://pair#...` client-side.
3. **HKDF binding (`deep-sky:pairing-sas:v2`):** `DeepSkyCrypto.computeSasCode` mixes `sasSecret` directly into the HKDF-SHA256 input keying material (`IKM = sharedSecret || sasSecret`) with salt `coupleId` and domain-separated info `deep-sky:pairing-sas:v2|<orderedKemA>|<orderedKemB>`.
4. **Strict enforcement:** Joining clients reject invite inputs that omit `sasSecret` rather than silently falling back to a server-visible SAS.

## Alternatives Considered

- **Two-round KEM key commitment (ZRTP style):** Adds another server round-trip and state machine step during invite acceptance. Rejected in favor of the single-round out-of-band fragment secret, which requires zero new server endpoints while blocking server-side key substitution.
- **Longer SAS comparison alone (e.g. 40+ bits):** Increases friction for non-technical users (`P-09`) and still leaves an offline search open if no commitment/secret is bound.

## Consequences

- A malicious server substituting `M1` and `M2` does not know `sasSecret` and cannot compute or collide `SAS(A, M1, sasSecret)` with `SAS(B, M2, sasSecret)` (probability of accidental collision 10^-6).
- Manual code entry requires entering `<inviteToken>.<sasSecretB64>` or the full link/QR so `sasSecret` is always present.
- Tested by simulated malicious-server MITM failure in `test/domain/deep_sky_crypto_test.dart` and `test/data/pairing_and_sync_repository_test.dart`.
