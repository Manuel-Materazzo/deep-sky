-- CA-03: Explicit server-side approval state for joined/enrolled devices.
ALTER TABLE devices ADD COLUMN approved_at TIMESTAMPTZ NULL;

UPDATE devices
SET approved_at = created_at
WHERE enrolled_via IN ('INVITE_INIT', 'RECOVERY_KEY')
   OR EXISTS (
       SELECT 1
       FROM key_deliveries k
       WHERE k.to_device_id = devices.id
   );
