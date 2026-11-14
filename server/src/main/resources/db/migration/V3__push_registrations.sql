CREATE TABLE push_registrations (
    id UUID PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL UNIQUE,
    couple_id VARCHAR(64),
    fcm_token TEXT NOT NULL,
    platform VARCHAR(16) NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL,
    last_wakeup_at TIMESTAMPTZ
);

CREATE INDEX idx_push_registrations_couple_id
    ON push_registrations (couple_id);
