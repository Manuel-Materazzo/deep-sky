-- Initial schema baseline for Deep Sky Server (SRV-01, TC-02).
-- Feature-specific tables (pairing, encrypted events, snapshots, blobs)
-- will be added after M1 verification prototypes (SP-02).

CREATE TABLE IF NOT EXISTS instance_metadata (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    schema_initialized_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    protocol_version INTEGER NOT NULL DEFAULT 1
);

INSERT INTO instance_metadata (id, protocol_version)
VALUES (1, 1)
ON CONFLICT (id) DO NOTHING;
