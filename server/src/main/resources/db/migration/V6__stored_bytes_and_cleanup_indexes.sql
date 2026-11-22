-- AU-21: atomic per-couple stored_bytes counter for O(1) concurrency-safe quota enforcement.
-- §7 / AU-20: cleanup indexes for nonces, invites, and unpaired couples retention.

ALTER TABLE couples
    ADD COLUMN stored_bytes BIGINT NOT NULL DEFAULT 0;

UPDATE couples c
SET stored_bytes = COALESCE((
    SELECT SUM(OCTET_LENGTH(e.ciphertext) + OCTET_LENGTH(e.nonce))
    FROM encrypted_envelopes e
    WHERE e.couple_id = c.id
), 0);

CREATE INDEX idx_request_nonces_expires_at ON request_nonces(expires_at);
CREATE INDEX idx_pairing_invites_expires_at ON pairing_invites(expires_at);
CREATE INDEX idx_couples_unpaired_at ON couples(unpaired_at) WHERE unpaired_at IS NOT NULL;
