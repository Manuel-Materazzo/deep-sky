-- CA-02 / ADR-0012: Epoch key rotation & recovery keyring support on device revocation.

ALTER TABLE couples
    ADD COLUMN current_key_epoch INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN recovery_keyring_nonce BYTEA NULL,
    ADD COLUMN recovery_keyring_ciphertext BYTEA NULL;

ALTER TABLE key_deliveries
    ADD COLUMN delivery_kind VARCHAR(32) NOT NULL DEFAULT 'PAIRING_SEED',
    ADD COLUMN key_epoch INTEGER NOT NULL DEFAULT 1;

CREATE INDEX idx_key_deliveries_to_device_kind_epoch
    ON key_deliveries (to_device_id, delivery_kind, key_epoch, created_at);
