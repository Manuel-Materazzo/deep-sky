CREATE TABLE sp05_events (
    id UUID PRIMARY KEY,
    couple_id VARCHAR(64) NOT NULL,
    channel VARCHAR(32) NOT NULL,
    ciphertext_bytes INTEGER NOT NULL,
    payload BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_sp05_events_couple ON sp05_events (couple_id, created_at DESC);
