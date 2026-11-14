-- SP-02 verification prototype schema: pairing, devices, key deliveries, recovery, and opaque envelopes.

CREATE TABLE couples (
    id UUID PRIMARY KEY,
    recovery_auth_public_key BYTEA NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unpaired_at TIMESTAMPTZ NULL
);

CREATE TABLE devices (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    label VARCHAR(64) NOT NULL,
    auth_public_key BYTEA NOT NULL,
    kem_public_key BYTEA NOT NULL,
    enrolled_via VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_devices_couple_id ON devices(couple_id);

CREATE TABLE pairing_invites (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    creator_device_id UUID NOT NULL REFERENCES devices(id),
    token_hash BYTEA NOT NULL UNIQUE,
    invite_kind VARCHAR(32) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ NULL,
    accepted_device_id UUID NULL REFERENCES devices(id)
);

CREATE TABLE key_deliveries (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    from_device_id UUID NOT NULL REFERENCES devices(id),
    to_device_id UUID NOT NULL REFERENCES devices(id),
    nonce BYTEA NOT NULL,
    ciphertext BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_key_deliveries_to_device ON key_deliveries(to_device_id);

CREATE TABLE recovery_challenges (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    nonce BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL
);

CREATE TABLE request_nonces (
    device_id UUID NOT NULL,
    nonce VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (device_id, nonce)
);

CREATE TABLE encrypted_envelopes (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    sender_device_id UUID NOT NULL REFERENCES devices(id),
    seq BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    channel VARCHAR(16) NOT NULL,
    key_epoch INTEGER NOT NULL,
    nonce BYTEA NOT NULL,
    ciphertext BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_envelopes_couple_seq ON encrypted_envelopes(couple_id, seq);
